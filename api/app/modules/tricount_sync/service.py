import re
import uuid
from datetime import UTC, date, datetime

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.money import format_minor
from app.modules.auth.deps import Actor
from app.modules.groups import repository as groups_repo
from app.modules.groups.models import Group, GroupMember
from app.modules.groups.service import require_member
from app.modules.import_tricount.matching import Candidate, match_people
from app.modules.tricount_sync import mapping, reconcile, wire
from app.modules.tricount_sync.client import Client, TricountError
from app.modules.tricount_sync.models import (
    TricountConflict,
    TricountEntry,
    TricountLink,
    TricountMember,
)
from app.modules.tricount_sync.schemas import (
    ConflictSideOut,
    TricountConflictOut,
    TricountLinkIn,
    TricountLinkOut,
    TricountLinkPreviewOut,
    TricountPersonOut,
    TricountStatusOut,
)
from app.modules.users.models import User
from app.modules.users.schemas import brief

SHARE_BASE = "https://tricount.com/"
_TOKEN = re.compile(r"(?:^|/)(t[A-Za-z0-9]{4,})/?(?:[?#].*)?$")


def parse_token(link: str) -> str:
    """https://tricount.com/tABC123, tricount.com/en/tABC123 or tABC123 -> tABC123."""
    found = _TOKEN.search(link.strip())
    if not found:
        raise ApiError(
            422, "not_a_tricount_link", "That doesn't look like a Tricount link (tricount.com/t…)"
        )
    return found.group(1)


def _tricount_call(fn):
    """Runs a call to Tricount and turns its failures into human API errors."""
    try:
        return fn()
    except TricountError as e:
        if e.gone:
            raise ApiError(404, "tricount_not_found", "No tricount has that link") from None
        raise ApiError(502, "tricount_failed", reconcile.human_error(e)) from None
    except (httpx.HTTPError, wire.WireError) as e:
        raise ApiError(502, "tricount_unreachable", reconcile.human_error(e)) from None


def _problem(group: Group, registry: wire.Registry) -> str | None:
    if registry.currency != group.currency:
        return (
            f"The tricount is in {registry.currency} and this group in {group.currency}. "
            "Splitkit can't convert between currencies."
        )
    return None


def _counts(registry: wire.Registry) -> tuple[int, int, int]:
    expenses = payments = unsupported = 0
    for e in registry.entries:
        c = mapping.remote_canon(e)
        if isinstance(c, mapping.Unsupported):
            unsupported += 1
        elif c["kind"] == "expense":
            expenses += 1
        else:
            payments += 1
    return expenses, payments, unsupported


# ---- linking ----


def preview(session: Session, actor: Actor, group_id: uuid.UUID, link: str):
    group = require_member(session, group_id, actor.user_id)
    token = parse_token(link)
    with Client.for_device(session) as client:
        registry = _tricount_call(lambda: client.peek(token))
    session.commit()  # the device's session
    members = groups_repo.active_members(session, group_id)
    candidates = [
        Candidate(u.id, u.name, m.placeholder_name, u.id == actor.user_id) for m, u in members
    ]
    people = registry.active_members()
    matches = match_people([p.name for p in people], candidates)
    by_id = {u.id: u for _, u in members}
    expenses, payments, unsupported = _counts(registry)
    return TricountLinkPreviewOut(
        title=registry.title,
        currency=registry.currency,
        expenses=expenses,
        payments=payments,
        unsupported=unsupported,
        people=[
            TricountPersonOut(
                member_uuid=p.uuid,
                name=p.name,
                suggested=brief(by_id[matches[p.name].candidate.id])
                if matches[p.name].candidate
                else None,
                state=matches[p.name].state,
            )
            for p in people
        ],
        problem=_problem(group, registry),
    )


def link(
    session: Session, actor: Actor, group_id: uuid.UUID, body: TricountLinkIn
) -> TricountStatusOut:
    actor.require_write()
    group = require_member(session, group_id, actor.user_id)
    if session.get(TricountLink, group_id) is not None:
        raise ApiError(409, "already_linked", "This group is already synced with a tricount")
    if body.create == (body.link is not None):
        raise ApiError(422, "invalid_input", "Paste a Tricount link, or choose to make a new one")

    people = [(p.member_uuid, p.user_id) for p in body.people]
    with Client.for_device(session) as client:
        if body.create:
            registry_id = _tricount_call(lambda: client.create_registry(group.name, group.currency))
            registry = _tricount_call(lambda: client.registry(registry_id))
            # A new tricount comes with one member, the device that made it: that's you.
            if registry.active_members():
                first = registry.active_members()[0]
                people.append((first.uuid, actor.user_id))
                _tricount_call(
                    lambda: client.update_registry(
                        registry_id,
                        {"memberships": [wire.membership(first.uuid, actor.user.name)]},
                    )
                )
        else:
            token = parse_token(body.link)
            registry = _tricount_call(lambda: client.join(token))
    problem = _problem(group, registry)
    if problem:
        session.commit()  # the device's session
        raise ApiError(422, "currency_mismatch", problem)
    taken = session.scalar(select(TricountLink).where(TricountLink.registry_id == registry.id))
    if taken is not None:
        raise ApiError(409, "tricount_taken", "That tricount is already synced with another group")

    session.add(
        TricountLink(
            group_id=group_id,
            public_token=registry.public_token,
            registry_id=registry.id,
            currency=registry.currency,
            title_base=group.name,  # so a different Tricount name is taken on the first pass
            created_by=actor.user_id,
        )
    )
    session.flush()
    _map_people(session, actor, group, registry, people)
    record(
        session,
        actor,
        "group.tricount_link",
        "group",
        group_id,
        group_id,
        {"registry_id": registry.id, "created": body.create},
    )
    session.commit()
    return status(session, actor, group_id)


def _map_people(
    session: Session,
    actor: Actor,
    group: Group,
    registry: wire.Registry,
    people: list[tuple[str, uuid.UUID | None]],
) -> None:
    remote = {m.uuid: m for m in registry.active_members()}
    current = {u.id for _, u in groups_repo.active_members(session, group.id)}
    seen_members: set[str] = set()
    seen_users: set[uuid.UUID] = set()
    for member_uuid, user_id in people:
        if member_uuid not in remote or member_uuid in seen_members:
            raise ApiError(422, "unknown_person", "Someone in the list isn't in that tricount")
        if user_id is None:
            user_id = _placeholder(session, actor, group.id, remote[member_uuid].name)
        elif user_id not in current or user_id in seen_users:
            raise ApiError(
                422, "person_taken", "Each Tricount person has to be a different group member"
            )
        seen_members.add(member_uuid)
        seen_users.add(user_id)
        session.add(TricountMember(group_id=group.id, membership_uuid=member_uuid, user_id=user_id))


def _placeholder(session: Session, actor: Actor, group_id: uuid.UUID, name: str) -> uuid.UUID:
    user = User(name=name[:80] or "Someone")
    session.add(user)
    session.flush()
    record(session, actor, "user.create_placeholder", "user", user.id, diff={"name": user.name})
    member = GroupMember(group_id=group_id, user_id=user.id, placeholder_name=user.name)
    session.add(member)
    record(
        session,
        actor,
        "member.add",
        "group",
        group_id,
        group_id,
        {"user_id": str(user.id), "via": "tricount"},
        obj=member,
    )
    return user.id


def unlink(session: Session, actor: Actor, group_id: uuid.UUID) -> None:
    actor.require_write()
    require_member(session, group_id, actor.user_id)
    row = session.get(TricountLink, group_id)
    if row is None:
        raise not_found("Tricount link")
    session.delete(row)
    record(session, actor, "group.tricount_unlink", "group", group_id, group_id, {})
    session.commit()


# ---- status ----


def status(session: Session, actor: Actor, group_id: uuid.UUID) -> TricountStatusOut:
    require_member(session, group_id, actor.user_id)
    row = session.get(TricountLink, group_id)
    if row is None:
        return TricountStatusOut(linked=False, link=None)
    row.last_active_at = datetime.now(UTC)
    session.commit()
    return TricountStatusOut(linked=True, link=_link_out(session, row))


def _link_out(session: Session, row: TricountLink) -> TricountLinkOut:
    return TricountLinkOut(
        group_id=row.group_id,
        share_link=SHARE_BASE + row.public_token,
        state=row.state,
        last_error=row.last_error,
        warnings=row.warnings or [],
        last_synced_at=row.last_synced_at,
        linked_at=row.created_at,
        linked_by=brief(session.get(User, row.created_by)),
        conflicts=_conflicts_out(session, [row.group_id]),
    )


def sync_now(session: Session, actor: Actor, group_id: uuid.UUID) -> TricountStatusOut:
    actor.require_write()
    require_member(session, group_id, actor.user_id)
    if session.get(TricountLink, group_id) is None:
        raise not_found("Tricount link")
    session.commit()
    try:
        reconcile.run(group_id)
    except reconcile.Busy:
        pass  # a pass is already running; its result shows up in the status
    except Exception:  # noqa: BLE001 (stored on the link and shown in the status)
        pass
    session.expire_all()
    return status(session, actor, group_id)


def run_in_background(group_id: uuid.UUID) -> None:
    """A pass whose failure is only recorded on the link (the worker retries)."""
    try:
        reconcile.run(group_id)
    except Exception:  # noqa: BLE001 (stored on the link; the worker retries)
        pass


# ---- conflicts ----


def _names(session: Session, group_ids: list[uuid.UUID]) -> dict[tuple[uuid.UUID, str], str]:
    rows = session.execute(
        select(TricountMember.group_id, TricountMember.membership_uuid, User.name)
        .join(User, User.id == TricountMember.user_id)
        .where(TricountMember.group_id.in_(group_ids))
    )
    return {(g, m): name.split()[0] if name else "Someone" for g, m, name in rows}


def _side(canon: dict | None, currency: str, names, group_id: uuid.UUID) -> ConflictSideOut:
    if canon is None:
        return ConflictSideOut(title="Deleted", summary="Deleted", deleted=True)
    who = lambda m: names.get((group_id, m), "Someone")  # noqa: E731
    money = format_minor(canon["amount"], currency)
    day = f"{date.fromisoformat(canon['date']):%-d %b}"
    if canon["kind"] == "expense":
        return ConflictSideOut(
            title=canon["description"],
            summary=(
                f"{money} · paid by {who(canon['payer'])} · "
                f"split {len(canon['shares'])} ways · {day}"
            ),
            deleted=False,
        )
    return ConflictSideOut(
        title=canon["note"] or "Payment",
        summary=f"{who(canon['from'])} paid {who(canon['to'])} {money} · {day}",
        deleted=False,
    )


def _conflicts_out(session: Session, group_ids: list[uuid.UUID]) -> list[TricountConflictOut]:
    if not group_ids:
        return []
    rows = session.execute(
        select(TricountConflict, TricountEntry, Group)
        .join(TricountEntry, TricountEntry.id == TricountConflict.entry_id)
        .join(Group, Group.id == TricountConflict.group_id)
        .where(TricountConflict.group_id.in_(group_ids), TricountConflict.resolved_at.is_(None))
        .order_by(TricountConflict.created_at)
    ).all()
    names = _names(session, group_ids)
    return [
        TricountConflictOut(
            id=c.id,
            group_id=c.group_id,
            group_name=g.name,
            entity="expense" if e.entity == "expense" else "payment",
            splitkit=_side(c.local, g.currency, names, g.id),
            tricount=_side(c.remote, g.currency, names, g.id),
            created_at=c.created_at,
        )
        for c, e, g in rows
    ]


def conflicts(session: Session, actor: Actor) -> list[TricountConflictOut]:
    mine = [g.id for g in groups_repo.groups_for_user(session, actor.user_id)]
    linked = (
        list(session.scalars(select(TricountLink.group_id).where(TricountLink.group_id.in_(mine))))
        if mine
        else []
    )
    return _conflicts_out(session, linked)


def resolve(
    session: Session, actor: Actor, conflict_id: uuid.UUID, keep: str
) -> tuple[uuid.UUID, TricountStatusOut]:
    """Pick a side: a pass right away sends Splitkit's version (keep="splitkit") or takes
    Tricount's (keep="tricount"), deletions included."""
    actor.require_write()
    c = session.get(TricountConflict, conflict_id)
    if c is None or c.resolved_at is not None:
        raise not_found("Conflict")
    require_member(session, c.group_id, actor.user_id)
    entry = session.get(TricountEntry, c.entry_id)
    entry.force = "push" if keep == "splitkit" else "pull"
    c.resolved_at, c.resolved_by, c.resolution = datetime.now(UTC), actor.user_id, keep
    record(
        session,
        actor,
        "group.tricount_resolve",
        "group",
        c.group_id,
        c.group_id,
        {"conflict_id": str(c.id), "keep": keep, "entity": entry.entity},
    )
    session.commit()
    # Run the pass now, so the app's next device sync already has the outcome.
    run_in_background(c.group_id)
    session.expire_all()
    return c.group_id, status(session, actor, c.group_id)
