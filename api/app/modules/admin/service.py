"""Admin: dashboard figures, the user list, view-as sessions and the audit log.

View-as ("impersonation"): an admin starts an `admin_sessions` row and gets a token for the target
user that names the admin and the session (see `auth.tokens.create_impersonation_token`).
`auth.deps.get_actor` turns it into `Actor(user=target, admin_id=admin, read_only=...)`, reading
the mode from the row on every request, so a mode switch or an ended session applies at once.

Rules: sessions default to read-only; switching to edit is its own audited action. Admins can't
view as themselves or another admin (that would hide an admin's actions behind another admin),
and placeholders can't be viewed as (they can't log in, so there is no view to see). Starting a
session ends the admin's other open sessions, so each admin has at most one. Session starts,
mode switches and ends go to audit_logs only: they are not group activity and not synced.
"""

import uuid
from collections import defaultdict
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import Select, distinct, func, or_, select, text, union_all
from sqlalchemy.orm import Session

from app import __version__
from app.core.config import get_settings
from app.core.errors import ApiError, not_found
from app.core.money import format_minor
from app.modules.admin.models import AdminSession, AuditLog
from app.modules.admin.schemas import (
    AdminDashboardOut,
    AdminSessionIn,
    AdminSessionOut,
    AdminSessionsPageOut,
    AdminSessionStartOut,
    AdminSessionUpdate,
    AdminUserOut,
    AdminUsersPageOut,
    AuditEntryOut,
    AuditPageOut,
    GroupRef,
    MoneyTotal,
    SystemOut,
)
from app.modules.auth.deps import Actor
from app.modules.auth.tokens import create_impersonation_token
from app.modules.balances import repository as ledger
from app.modules.balances.engine import positions
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups.models import ActivityEvent, Group, GroupMember
from app.modules.import_tricount.models import ImportBatch
from app.modules.personal.models import PersonalTransaction
from app.modules.settlements.models import Settlement
from app.modules.users import repository as users
from app.modules.users.models import User
from app.modules.users.schemas import UserOut, brief

RECENT = 8
MODE_WORDS = {"read_only": "read-only", "edit": "edit mode"}


def _count(session: Session, query: Select) -> int:
    return session.scalar(select(func.count()).select_from(query.subquery())) or 0


def _money(session: Session, model) -> list[MoneyTotal]:
    rows = session.execute(
        select(model.currency, func.sum(model.amount_minor))
        .where(model.deleted_at.is_(None))
        .group_by(model.currency)
        .order_by(model.currency)
    )
    return [MoneyTotal(currency=c, amount_minor=int(total)) for c, total in rows]


# ---- dashboard ----


def dashboard(session: Session) -> AdminDashboardOut:
    now = datetime.now(UTC)
    live_expenses = select(Expense.id).where(Expense.deleted_at.is_(None))
    live_settlements = select(Settlement.id).where(Settlement.deleted_at.is_(None))
    live_personal = select(PersonalTransaction.id).where(PersonalTransaction.deleted_at.is_(None))
    last_import = session.execute(
        select(ImportBatch.created_at, ImportBatch.source)
        .order_by(ImportBatch.created_at.desc())
        .limit(1)
    ).first()
    version = session.scalar(text("SHOW server_version")) or ""
    return AdminDashboardOut(
        users=_count(session, select(User.id).where(User.email.is_not(None))),
        admins=_count(session, select(User.id).where(User.role == "admin")),
        placeholders=_count(session, select(User.id).where(User.email.is_(None))),
        groups=_count(session, select(Group.id).where(Group.archived_at.is_(None))),
        groups_active_week=_count(
            session,
            select(distinct(ActivityEvent.group_id)).where(
                ActivityEvent.at >= now - timedelta(days=7), ActivityEvent.group_id.is_not(None)
            ),
        ),
        expenses=_count(session, live_expenses),
        expenses_imported=_count(
            session, live_expenses.where(Expense.import_batch_id.is_not(None))
        ),
        expense_volume=_money(session, Expense),
        settlements=_count(session, live_settlements),
        settlement_volume=_money(session, Settlement),
        personal_transactions=_count(session, live_personal),
        personal_users=_count(
            session,
            select(distinct(PersonalTransaction.user_id)).where(
                PersonalTransaction.deleted_at.is_(None)
            ),
        ),
        open_sessions=_count(session, select(AdminSession.id).where(_open(now))),
        recent=audit(session, limit=RECENT).items,
        system=SystemOut(
            api_version=__version__,
            database=f"PostgreSQL {version.split()[0]}" if version else "PostgreSQL",
            database_bytes=session.scalar(text("SELECT pg_database_size(current_database())")),
            last_import_at=last_import[0] if last_import else None,
            last_import_source=last_import[1] if last_import else None,
        ),
    )


# ---- users ----


def _like(q: str) -> str:
    return "%" + q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"


def list_users(
    session: Session,
    q: str | None,
    role: str | None,
    include_placeholders: bool,
    limit: int,
    offset: int,
) -> AdminUsersPageOut:
    query = select(User)
    if q and q.strip():
        pattern = _like(q)
        query = query.where(or_(User.name.ilike(pattern), User.email.ilike(pattern)))
    if role:
        query = query.where(User.role == role)
    if not include_placeholders:
        query = query.where(User.email.is_not(None))
    total = _count(session, query)
    page = list(
        session.scalars(
            query.order_by((User.role != "admin"), User.created_at, User.name, User.id)
            .limit(limit)
            .offset(offset)
        )
    )
    items = _user_rows(session, page)
    return AdminUsersPageOut(items=items, total=total, has_more=offset + len(items) < total)


def _counts(session: Session, query: Select) -> dict[uuid.UUID, int]:
    return {uid: n for uid, n in session.execute(query)}


def _user_rows(session: Session, page: list[User]) -> list[AdminUserOut]:
    if not page:
        return []
    ids = [u.id for u in page]
    groups_n = _counts(
        session,
        select(GroupMember.user_id, func.count())
        .where(GroupMember.user_id.in_(ids), GroupMember.left_at.is_(None))
        .group_by(GroupMember.user_id),
    )
    # Expenses they paid for or have a share in, each counted once.
    involved = union_all(
        select(Expense.payer_id.label("uid"), Expense.id.label("eid")).where(
            Expense.payer_id.in_(ids), Expense.deleted_at.is_(None)
        ),
        select(ExpenseSplit.user_id, ExpenseSplit.expense_id)
        .join(Expense, Expense.id == ExpenseSplit.expense_id)
        .where(ExpenseSplit.user_id.in_(ids), Expense.deleted_at.is_(None)),
    ).subquery()
    expenses_n = _counts(
        session,
        select(involved.c.uid, func.count(distinct(involved.c.eid))).group_by(involved.c.uid),
    )
    parties = union_all(
        select(Settlement.from_user.label("uid"), Settlement.id.label("sid")).where(
            Settlement.from_user.in_(ids), Settlement.deleted_at.is_(None)
        ),
        select(Settlement.to_user, Settlement.id).where(
            Settlement.to_user.in_(ids), Settlement.deleted_at.is_(None)
        ),
    ).subquery()
    settlements_n = _counts(
        session,
        select(parties.c.uid, func.count(distinct(parties.c.sid))).group_by(parties.c.uid),
    )
    personal_n = _counts(
        session,
        select(PersonalTransaction.user_id, func.count())
        .where(PersonalTransaction.user_id.in_(ids), PersonalTransaction.deleted_at.is_(None))
        .group_by(PersonalTransaction.user_id),
    )
    last_active = dict(
        session.execute(
            select(AuditLog.actor_id, func.max(AuditLog.at))
            .where(AuditLog.actor_id.in_(ids), AuditLog.acting_as_id.is_(None))
            .group_by(AuditLog.actor_id)
        ).all()
    )

    # Overall net per currency, over every group they were ever in (as Home adds it up).
    memberships = session.execute(
        select(GroupMember.user_id, Group.id, Group.currency)
        .join(Group, Group.id == GroupMember.group_id)
        .where(GroupMember.user_id.in_(ids))
    ).all()
    flows = ledger.flows_by_group(session, list({g for _, g, _ in memberships}))
    pos = {g: positions(f) for g, f in flows.items()}
    nets: dict[uuid.UUID, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for user_id, group_id, currency in memberships:
        nets[user_id][currency] += pos.get(group_id, {}).get(user_id, 0)

    return [
        AdminUserOut(
            id=u.id,
            name=u.name,
            email=u.email,
            avatar_url=u.avatar_url,
            role=u.role,
            currency=u.currency,
            created_at=u.created_at,
            is_placeholder=u.email is None,
            group_count=groups_n.get(u.id, 0),
            expense_count=expenses_n.get(u.id, 0),
            settlement_count=settlements_n.get(u.id, 0),
            personal_count=personal_n.get(u.id, 0),
            balances=[
                MoneyTotal(currency=c, amount_minor=n) for c, n in sorted(nets[u.id].items()) if n
            ],
            last_active_at=last_active.get(u.id),
        )
        for u in page
    ]


# ---- view-as sessions ----


def _open(now: datetime):
    return AdminSession.ended_at.is_(None) & (
        AdminSession.expires_at.is_(None) | (AdminSession.expires_at > now)
    )


def _is_active(row: AdminSession, now: datetime) -> bool:
    return row.ended_at is None and (row.expires_at is None or row.expires_at > now)


def _session_out(row: AdminSession, people: dict[uuid.UUID, User]) -> AdminSessionOut:
    return AdminSessionOut(
        id=row.id,
        admin=brief(people[row.admin_id]),
        target=brief(people[row.target_user_id]),
        mode=row.mode,
        started_at=row.started_at,
        ended_at=row.ended_at,
        expires_at=row.expires_at,
        active=_is_active(row, datetime.now(UTC)),
    )


def _one_out(session: Session, row: AdminSession) -> AdminSessionOut:
    return _session_out(row, users.get_many(session, [row.admin_id, row.target_user_id]))


def _audit(
    session: Session, admin_id: uuid.UUID, row: AdminSession, action: str, diff: dict
) -> None:
    """Session events go to the audit log only (no activity, no sync). The target is
    `acting_as`, so they show up on the target's trail too."""
    session.add(
        AuditLog(
            actor_id=admin_id,
            acting_as_id=row.target_user_id,
            action=action,
            entity="admin_session",
            entity_id=row.id,
            diff_json=diff,
        )
    )


def _end(session: Session, admin_id: uuid.UUID, row: AdminSession, reason: str) -> None:
    row.ended_at = datetime.now(UTC)
    _audit(session, admin_id, row, "admin_session.end", {"reason": reason})


def start_session(session: Session, admin: Actor, body: AdminSessionIn) -> AdminSessionStartOut:
    target = session.get(User, body.target_user_id)
    if target is None:
        raise not_found("Person")
    if target.id == admin.user_id:
        raise ApiError(422, "cannot_view_as", "You're already signed in as yourself")
    if target.role == "admin":
        raise ApiError(422, "cannot_view_as", "You can't view the app as another admin")
    if target.email is None:
        raise ApiError(
            422,
            "cannot_view_as",
            f"{target.name} doesn't have an account yet, so there's nothing to view as them",
        )
    now = datetime.now(UTC)
    for other in session.scalars(
        select(AdminSession).where(AdminSession.admin_id == admin.user_id, _open(now))
    ):
        _end(session, admin.user_id, other, "replaced")

    lifetime = timedelta(minutes=get_settings().admin_session_ttl_minutes)
    row = AdminSession(
        admin_id=admin.user_id,
        target_user_id=target.id,
        mode=body.mode,
        started_at=now,
        expires_at=now + lifetime,
    )
    session.add(row)
    session.flush()
    _audit(session, admin.user_id, row, "admin_session.start", {"mode": body.mode})
    session.commit()
    token = create_impersonation_token(target.id, admin.user_id, row.id, row.mode, row.expires_at)
    return AdminSessionStartOut(
        session=_one_out(session, row),
        access_token=token,
        expires_in=int(lifetime.total_seconds()),
        user=UserOut.model_validate(target),
    )


def _load_session(session: Session, session_id: uuid.UUID) -> AdminSession:
    row = session.get(AdminSession, session_id)
    if row is None:
        raise not_found("Session")
    return row


def update_session(
    session: Session, admin: Actor, session_id: uuid.UUID, body: AdminSessionUpdate
) -> AdminSessionOut:
    """Switch between read-only and edit. Only the admin who started the session can."""
    row = _load_session(session, session_id)
    if row.admin_id != admin.user_id:
        raise not_found("Session")
    if not _is_active(row, datetime.now(UTC)):
        raise ApiError(409, "admin_session_ended", "This view-as session has ended")
    if row.mode != body.mode:
        _audit(
            session,
            admin.user_id,
            row,
            "admin_session.mode",
            {"mode": {"from": row.mode, "to": body.mode}},
        )
        row.mode = body.mode
        session.commit()
    return _one_out(session, row)


def end_session(session: Session, actor: Actor, session_id: uuid.UUID) -> AdminSessionOut:
    """Any admin (signed in as themselves) can end any session; a view-as token can end its own.
    Ending an ended session changes nothing."""
    is_admin = actor.user.role == "admin" and actor.admin_id is None
    if not is_admin and actor.session_id != session_id:
        raise ApiError(403, "not_admin", "Only admins can open this")
    row = _load_session(session, session_id)
    if row.ended_at is None:
        _end(session, actor.admin_id or actor.user_id, row, "ended")
        session.commit()
    return _one_out(session, row)


def list_sessions(
    session: Session,
    active: bool | None,
    admin_id: uuid.UUID | None,
    target_user_id: uuid.UUID | None,
    limit: int,
    offset: int,
) -> AdminSessionsPageOut:
    query = select(AdminSession)
    now = datetime.now(UTC)
    if active is not None:
        query = query.where(_open(now) if active else ~_open(now))
    if admin_id:
        query = query.where(AdminSession.admin_id == admin_id)
    if target_user_id:
        query = query.where(AdminSession.target_user_id == target_user_id)
    total = _count(session, query)
    rows = list(
        session.scalars(
            query.order_by(AdminSession.started_at.desc(), AdminSession.id)
            .limit(limit)
            .offset(offset)
        )
    )
    people = users.get_many(session, [u for r in rows for u in (r.admin_id, r.target_user_id)])
    items = [_session_out(r, people) for r in rows]
    return AdminSessionsPageOut(items=items, total=total, has_more=offset + len(items) < total)


# ---- audit log ----


def audit(
    session: Session,
    actor_id: uuid.UUID | None = None,
    target_user_id: uuid.UUID | None = None,
    entity: list[str] | None = None,
    admin_only: bool = False,
    start: date | None = None,
    end: date | None = None,
    limit: int = 50,
    offset: int = 0,
) -> AuditPageOut:
    """Newest first. `actor_id` is who really acted; `target_user_id` is who it was done as
    (the impersonated user, or the actor when nobody was impersonated). Dates are UTC days,
    both ends included."""
    query = select(AuditLog)
    if actor_id:
        query = query.where(AuditLog.actor_id == actor_id)
    if target_user_id:
        done_as = func.coalesce(AuditLog.acting_as_id, AuditLog.actor_id)
        query = query.where(done_as == target_user_id)
    if entity:
        query = query.where(AuditLog.entity.in_(entity))
    if admin_only:
        query = query.where(AuditLog.acting_as_id.is_not(None))
    if start:
        query = query.where(AuditLog.at >= datetime.combine(start, time.min, UTC))
    if end:
        query = query.where(AuditLog.at < datetime.combine(end + timedelta(days=1), time.min, UTC))
    total = _count(session, query)
    rows = list(
        session.scalars(query.order_by(AuditLog.at.desc(), AuditLog.id).limit(limit).offset(offset))
    )
    items = _entries(session, rows)
    return AuditPageOut(items=items, total=total, has_more=offset + len(items) < total)


def _ids(rows: list[AuditLog], entity: str) -> set[uuid.UUID]:
    return {r.entity_id for r in rows if r.entity == entity and r.entity_id}


def _entries(session: Session, rows: list[AuditLog]) -> list[AuditEntryOut]:
    def load(model, ids):
        if not ids:
            return {}
        return {o.id: o for o in session.scalars(select(model).where(model.id.in_(ids)))}

    expenses = load(Expense, _ids(rows, "expense"))
    settlements = load(Settlement, _ids(rows, "settlement"))
    batches = load(ImportBatch, _ids(rows, "import_batch"))
    group_ids = (
        _ids(rows, "group")
        | {e.group_id for e in expenses.values()}
        | {s.group_id for s in settlements.values()}
        | {b.group_id for b in batches.values() if b.group_id}
    )
    groups = load(Group, group_ids)
    people_ids = {u for r in rows for u in (r.actor_id, r.acting_as_id) if u}
    people_ids |= {u for s in settlements.values() for u in (s.from_user, s.to_user)}
    for r in rows:
        if r.entity == "group" and "user_id" in r.diff_json:
            people_ids.add(uuid.UUID(r.diff_json["user_id"]))
    people = users.get_many(session, people_ids)

    out = []
    for r in rows:
        group_id = {
            "group": r.entity_id,
            "expense": getattr(expenses.get(r.entity_id), "group_id", None),
            "settlement": getattr(settlements.get(r.entity_id), "group_id", None),
            "import_batch": getattr(batches.get(r.entity_id), "group_id", None),
        }.get(r.entity)
        group = groups.get(group_id) if group_id else None
        out.append(
            AuditEntryOut(
                id=r.id,
                at=r.at,
                action=r.action,
                entity=r.entity,
                entity_id=r.entity_id,
                actor=brief(people[r.actor_id]) if r.actor_id else None,
                acting_as=brief(people[r.acting_as_id]) if r.acting_as_id else None,
                done_as="system" if r.actor_id is None else "admin" if r.acting_as_id else "user",
                summary=_summary(r, expenses, settlements, people, group),
                group=GroupRef(id=group.id, name=group.name) if group else None,
                diff=r.diff_json,
            )
        )
    return out


def _summary(
    r: AuditLog,
    expenses: dict[uuid.UUID, Expense],
    settlements: dict[uuid.UUID, Settlement],
    people: dict[uuid.UUID, User],
    group: Group | None,
) -> str:
    """One line of human copy for the activity table."""
    verb, _, what = r.action.partition(".")
    diff = r.diff_json or {}
    past = {"create": "Added", "update": "Edited", "delete": "Deleted", "restore": "Restored"}

    def name(user_id) -> str:
        user = people.get(uuid.UUID(str(user_id))) if user_id else None
        return user.name.split()[0] if user else "someone"

    if r.entity == "expense":
        e = expenses.get(r.entity_id)
        title = f"“{e.description}”" if e else "an expense"
        if what == "create" and e:
            return f"Added {title} · {format_minor(e.amount_minor, e.currency)}"
        if what == "update" and set(diff) == {"category"}:
            return f"Changed the category of {title}"
        if what == "delete":
            return f"Deleted {title} · restorable"
        return f"{past.get(what, what.capitalize())} {title}"
    if r.entity == "settlement":
        s = settlements.get(r.entity_id)
        if s is None:
            return f"{past.get(what, what.capitalize())} a payment"
        amount = format_minor(s.amount_minor, s.currency)
        pair = f"{name(s.from_user)} paid {name(s.to_user)}"
        if what == "create":
            return f"Recorded a payment · {pair} {amount}"
        return f"{past.get(what, what.capitalize())} a payment · {pair} {amount}"
    if r.entity == "group":
        group_name = f"“{group.name}”" if group else "a group"
        member = name(diff.get("user_id"))
        return {
            "group.create": f"Created {group_name}",
            "group.update": f"Edited {group_name}",
            "member.add": f"Added {member} to the group",
            "member.remove": f"Removed {member} from the group",
            "member.leave": "Left the group",
            "member.join": "Joined via invite link"
            if diff.get("via") == "invite_link"
            else "Joined the group",
        }.get(r.action, r.action)
    if r.entity == "admin_session":
        who = name(r.acting_as_id)
        if what == "start":
            return f"Started viewing as {who} · {MODE_WORDS.get(diff.get('mode'), 'read-only')}"
        if what == "mode":
            to = (diff.get("mode") or {}).get("to")
            return f"Switched to {MODE_WORDS.get(to, to)} while viewing as {who}"
        return f"Stopped viewing as {who}"
    if r.entity == "import_batch":
        if what == "complete":
            n, flagged = diff.get("expenses"), diff.get("flagged")
            tail = f" · {n} expenses" if n is not None else ""
            tail += f", {flagged} to review" if flagged else ""
            return f"Import finished{tail}"
        return f"Import {what}"
    if r.entity == "personal_transaction":
        return f"{past.get(what, what.capitalize())} a personal transaction"
    if r.entity == "category":
        label = diff.get("label")
        return f"{past.get(what, what.capitalize())} category “{label}”" if label else r.action
    if r.entity == "user":
        if r.action == "user.create_placeholder":
            return f"Added {diff.get('name', 'someone')} without an account"
        return "Updated their profile"
    if r.entity == "layout":
        return "Reset an analytics layout" if what == "reset" else "Saved an analytics layout"
    return f"{verb.replace('_', ' ').capitalize()} {what}".strip()
