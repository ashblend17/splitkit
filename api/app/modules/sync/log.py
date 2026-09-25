"""The sync change log: every write appends the full state of what it changed to one or more
streams, in the same transaction as the write.

`record()` in app/core/events.py calls `track()` with the changed object. Entries are built at
commit time, after the final flush, so they carry the new `version` and the final state. The
commit hook then bumps each stream's `head_seq` (in sorted stream order, so two transactions that
touch the same streams can't deadlock) and inserts one change_log row per entry.

Streams:
- `group:<id>`: the group, its members (with their names), expenses with splits, settlements.
- `user:<id>`: profile, personal transactions, own categories, layouts, and memberships (which
  group streams this user should follow).
- `global`: system categories and default layouts. Written by migrations and the seed only, so
  clients get it from a snapshot.
"""

import uuid
from collections import defaultdict
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Any

from sqlalchemy import event, inspect, select, text
from sqlalchemy.orm import Session

if TYPE_CHECKING:
    from app.modules.auth.deps import Actor

GLOBAL = "global"
_PENDING = "sync_pending"


def group_stream(group_id: uuid.UUID) -> str:
    return f"group:{group_id}"


def user_stream(user_id: uuid.UUID) -> str:
    return f"user:{user_id}"


@dataclass(frozen=True)
class Entry:
    stream: str
    entity: str
    entity_id: uuid.UUID
    op: str  # upsert | delete
    data: dict[str, Any] | None
    version: int | None = None


# ---- serialising entities ----


def _json(value: Any) -> Any:
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, datetime | date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return f"{value.normalize():f}"
    return value


def _columns(obj: Any, exclude: Iterable[str] = ()) -> dict[str, Any]:
    skip = set(exclude)
    return {
        a.key: _json(getattr(obj, a.key))
        for a in inspect(obj).mapper.column_attrs
        if a.key not in skip
    }


def _person(user: Any) -> dict[str, Any]:
    return {
        "id": str(user.id),
        "name": user.name,
        "avatar_url": user.avatar_url,
        "is_placeholder": user.email is None,
    }


def _category(session: Session, category_id: uuid.UUID | None) -> dict[str, Any] | None:
    """Embedded in expenses so every member sees the label, even of a category someone else
    owns (user categories are otherwise private to their owner)."""
    from app.modules.categories.models import Category

    if category_id is None:
        return None
    c = session.get(Category, category_id)
    return {"id": str(c.id), "key": c.key, "label": c.label, "icon": c.icon} if c else None


def _member_entries(session: Session, m: Any) -> list[Entry]:
    from app.modules.users.models import User

    user = session.get(User, m.user_id)
    return [
        Entry(
            group_stream(m.group_id),
            "member",
            m.user_id,
            "upsert",
            {**_columns(m), "user": _person(user)},
        ),
        # Tells the member's devices to start (or stop) following the group stream.
        Entry(
            user_stream(m.user_id),
            "membership",
            m.group_id,
            "upsert",
            {"group_id": str(m.group_id), "active": m.left_at is None},
        ),
    ]


def entries_for(session: Session, obj: Any) -> list[Entry]:
    """Full-state entries for one changed object. Also used to build snapshots."""
    from app.modules.analytics.models import AnalyticsConfiguration
    from app.modules.categories.models import Category
    from app.modules.expenses.models import Expense
    from app.modules.groups.models import Group, GroupMember
    from app.modules.personal.models import PersonalTransaction
    from app.modules.settlements.models import Settlement
    from app.modules.users.models import User

    match obj:
        case Expense():
            data = {
                **_columns(obj),
                "splits": [
                    {
                        "user_id": str(s.user_id),
                        "share_minor": s.share_minor,
                        "input_value": _json(s.input_value),
                    }
                    for s in obj.splits
                ],
                "category": _category(session, obj.category_id),
            }
            return [
                Entry(group_stream(obj.group_id), "expense", obj.id, "upsert", data, obj.version)
            ]
        case Settlement():
            return [
                Entry(
                    group_stream(obj.group_id),
                    "settlement",
                    obj.id,
                    "upsert",
                    _columns(obj),
                    obj.version,
                )
            ]
        case Group():
            return [
                Entry(group_stream(obj.id), "group", obj.id, "upsert", _columns(obj), obj.version)
            ]
        case GroupMember():
            return _member_entries(session, obj)
        case PersonalTransaction():
            return [
                Entry(
                    user_stream(obj.user_id),
                    "personal_transaction",
                    obj.id,
                    "upsert",
                    _columns(obj),
                    obj.version,
                )
            ]
        case Category():
            stream = GLOBAL if obj.owner_id is None else user_stream(obj.owner_id)
            return [Entry(stream, "category", obj.id, "upsert", _columns(obj))]
        case User():
            profile = Entry(
                user_stream(obj.id),
                "profile",
                obj.id,
                "upsert",
                _columns(obj, exclude={"password_hash"}),
                obj.version,
            )
            # Re-send their member entry everywhere, so other members see the new name.
            memberships = session.scalars(select(GroupMember).where(GroupMember.user_id == obj.id))
            members = [e for m in memberships for e in _member_entries(session, m)]
            return [profile, *(e for e in members if e.entity == "member")]
        case AnalyticsConfiguration():
            raise TypeError("Layouts are tracked with track_layout()")
    raise TypeError(f"No sync serializer for {type(obj).__name__}")


def layout_id(owner_id: uuid.UUID | None, scope: str) -> uuid.UUID:
    """A stable entity id for a user's (or the default) layout of one dashboard."""
    return uuid.uuid5(uuid.NAMESPACE_URL, f"splitkit:layout:{owner_id or 'default'}:{scope}")


def layout_entry(owner_id: uuid.UUID | None, scope: str, rows: list[Any]) -> Entry:
    stream = GLOBAL if owner_id is None else user_stream(owner_id)
    if not rows:
        return Entry(stream, "layout", layout_id(owner_id, scope), "delete", None)
    cards = [
        _columns(r, exclude={"id", "owner_id", "scope"})
        for r in sorted(rows, key=lambda r: r.position)
    ]
    data = {"scope": scope, "owner_id": _json(owner_id), "cards": cards}
    return Entry(stream, "layout", layout_id(owner_id, scope), "upsert", data)


# ---- queueing and writing ----


@dataclass
class _Pending:
    actor_id: uuid.UUID | None
    admin_id: uuid.UUID | None
    action: str
    resolve: Callable[[Session], list[Entry]]


def _queue(session: Session, actor: "Actor | None", action: str, resolve) -> None:
    session.info.setdefault(_PENDING, []).append(
        _Pending(
            actor.user_id if actor else None, actor.admin_id if actor else None, action, resolve
        )
    )


def track(session: Session, actor: "Actor | None", action: str, obj: Any, deleted: bool) -> None:
    """Queue change entries for `obj`. A hard delete is turned into tombstones right away,
    while the object is still readable; everything else is serialised at commit."""
    if deleted:
        tombstones = [
            Entry(e.stream, e.entity, e.entity_id, "delete", None)
            for e in entries_for(session, obj)
        ]
        _queue(session, actor, action, lambda _: tombstones)
    else:
        _queue(session, actor, action, lambda s: entries_for(s, obj))


def track_layout(
    session: Session, actor: "Actor", action: str, scope: str, rows: list[Any]
) -> None:
    entry = layout_entry(actor.user_id, scope, rows)
    _queue(session, actor, action, lambda _: [entry])


def bump(session: Session, stream: str, n: int) -> int:
    """Reserve `n` seqs on a stream and return the last one. The row stays locked until
    commit, so concurrent writers to one stream queue up and commit in seq order."""
    return session.execute(
        text(
            "INSERT INTO sync_streams (id, head_seq) VALUES (:id, :n) "
            "ON CONFLICT (id) DO UPDATE SET head_seq = sync_streams.head_seq + :n "
            "RETURNING head_seq"
        ),
        {"id": stream, "n": n},
    ).scalar_one()


@event.listens_for(Session, "before_commit")
def _write_changes(session: Session) -> None:
    pending: list[_Pending] = session.info.pop(_PENDING, None)
    if not pending:
        return
    from app.modules.sync.models import ChangeLog

    session.flush()  # final state and bumped versions
    by_stream: dict[str, list[tuple[_Pending, Entry]]] = defaultdict(list)
    for p in pending:
        for e in p.resolve(session):
            by_stream[e.stream].append((p, e))
    for stream in sorted(by_stream):
        items = by_stream[stream]
        head = bump(session, stream, len(items))
        for i, (p, e) in enumerate(items):
            session.add(
                ChangeLog(
                    stream_id=stream,
                    seq=head - len(items) + 1 + i,
                    action=p.action,
                    entity=e.entity,
                    entity_id=e.entity_id,
                    op=e.op,
                    version=e.version,
                    data=e.data,
                    actor_id=p.actor_id,
                    acting_admin_id=p.admin_id,
                )
            )


@event.listens_for(Session, "after_soft_rollback")
def _drop_pending(session: Session, _previous_transaction) -> None:
    session.info.pop(_PENDING, None)
