"""Goal contributions: money you put towards a goal, optionally with the entry that moved it (a
transfer to savings, an investment).

Nothing is counted twice (spec §4.4): an entry counts towards one goal at most, and an entry
that moves an account some goal follows by balance can't also be a contribution. Deleting or
restoring an entry or a goal takes its contributions with it; a cascade stamps them with the
same `deleted_at`, so a restore brings back exactly those, not ones you deleted yourself.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.money import format_minor
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.personal.models import (
    PersonalGoal,
    PersonalGoalContribution,
    PersonalTransaction,
)
from app.modules.personal.schemas import (
    PersonalGoalContributionIn,
    PersonalGoalContributionOut,
)

ENTITY = "personal_goal_contribution"

# A live contribution, to a goal that counts contributions, from an entry that (itself or the
# other leg of its transfer) moves an account a goal follows by balance. Archived and deleted
# goals count nothing. validate.py runs the same over everyone.
COUNTED_TWICE = text("""
    SELECT c.id, cg.name AS contribution_goal, lg.name AS balance_goal, a.name AS account
    FROM personal_goal_contributions c
    JOIN personal_goals cg ON cg.id = c.goal_id AND cg.deleted_at IS NULL
         AND cg.status <> 'archived' AND cg.tracking_mode = 'contribution'
    JOIN personal_transactions t ON t.id = c.transaction_id
    JOIN personal_transactions m ON m.user_id = t.user_id AND m.deleted_at IS NULL
         AND (m.id = t.id OR m.transfer_group_id = t.transfer_group_id)
    JOIN personal_goals lg ON lg.user_id = c.user_id AND lg.tracking_mode = 'linked_balance'
         AND lg.linked_account_id = m.account_id AND lg.deleted_at IS NULL
         AND lg.status <> 'archived'
    JOIN personal_accounts a ON a.id = m.account_id
    WHERE c.user_id = :user AND c.deleted_at IS NULL
    LIMIT 1
""")


# Two goals that count, following one account: its balance would count towards both.
SHARED_ACCOUNT = text("""
    SELECT a.name AS account, g.name AS goal
    FROM personal_goals g
    JOIN personal_goals o ON o.linked_account_id = g.linked_account_id AND o.id <> g.id
         AND o.deleted_at IS NULL AND o.status <> 'archived'
    JOIN personal_accounts a ON a.id = g.linked_account_id
    WHERE g.user_id = :user AND g.deleted_at IS NULL AND g.status <> 'archived'
    ORDER BY g.created_at, g.id
    LIMIT 1
""")


def check_counted_once(session: Session, user_id: uuid.UUID, changed: str) -> None:
    """Run after a write that could make money count twice. `changed` is "goal" when a goal
    was written, else "contribution" (a contribution or an entry)."""
    session.flush()
    if changed == "goal":
        shared = session.execute(SHARED_ACCOUNT, {"user": user_id}).first()
        if shared is not None:
            message = f"{shared.goal} already follows {shared.account}"
            raise ApiError(422, "account_followed", message)
    row = session.execute(COUNTED_TWICE, {"user": user_id}).first()
    if row is None:
        return
    if changed == "goal":
        message = f"An entry in {row.account} already counts toward {row.contribution_goal}"
        raise ApiError(422, "counted_by_contribution", message)
    message = f"{row.balance_goal} already counts that entry, through the balance of {row.account}"
    raise ApiError(422, "counted_by_balance", message)


def _load(session: Session, actor: Actor, contribution_id: uuid.UUID) -> PersonalGoalContribution:
    c = session.get(PersonalGoalContribution, contribution_id)
    if c is None or c.user_id != actor.user_id:
        raise not_found("Contribution")
    return c


def list_contributions(
    session: Session, actor: Actor, goal_id: uuid.UUID | None = None, deleted: bool = False
) -> list[PersonalGoalContributionOut]:
    """Newest first; with `deleted`, only the deleted ones."""
    gone = PersonalGoalContribution.deleted_at.isnot(None)
    q = select(PersonalGoalContribution).where(
        PersonalGoalContribution.user_id == actor.user_id, gone if deleted else ~gone
    )
    if goal_id is not None:
        q = q.where(PersonalGoalContribution.goal_id == goal_id)
    q = q.order_by(
        PersonalGoalContribution.date.desc(),
        PersonalGoalContribution.created_at.desc(),
        PersonalGoalContribution.id.desc(),
    )
    return [PersonalGoalContributionOut.model_validate(c) for c in session.scalars(q)]


def get_contribution(
    session: Session, actor: Actor, contribution_id: uuid.UUID
) -> PersonalGoalContributionOut:
    return PersonalGoalContributionOut.model_validate(_load(session, actor, contribution_id))


def _check_goal(session: Session, actor: Actor, goal_id: uuid.UUID) -> PersonalGoal:
    """A goal a contribution can go to now: yours, live, not archived, counting
    contributions."""
    g = session.get(PersonalGoal, goal_id)
    if g is None or g.user_id != actor.user_id or g.deleted_at is not None:
        raise ApiError(422, "unknown_goal", "That goal isn't available")
    if g.status == "archived":
        raise ApiError(422, "goal_archived", f"{g.name} is archived")
    if g.tracking_mode == "linked_balance":
        raise ApiError(
            422,
            "goal_tracks_balance",
            f"{g.name} follows an account's balance, so it takes no contributions",
        )
    if g.tracking_mode == "manual":
        raise ApiError(
            422, "goal_is_manual", f"{g.name} is tracked by hand, so it takes no contributions"
        )
    return g


def _other_contribution(
    session: Session, transaction_id: uuid.UUID, contribution_id: uuid.UUID | None
) -> PersonalGoalContribution | None:
    q = select(PersonalGoalContribution).where(
        PersonalGoalContribution.transaction_id == transaction_id,
        PersonalGoalContribution.deleted_at.is_(None),
    )
    if contribution_id is not None:
        q = q.where(PersonalGoalContribution.id != contribution_id)
    return session.scalar(q)


def _check_entry(
    session: Session,
    actor: Actor,
    transaction_id: uuid.UUID,
    amount_minor: int,
    currency: str,
    contribution_id: uuid.UUID | None,
) -> None:
    t = session.get(PersonalTransaction, transaction_id)
    if t is None or t.user_id != actor.user_id or t.deleted_at is not None:
        raise ApiError(422, "unknown_transaction", "That entry isn't available")
    if t.currency != currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That entry is in {t.currency}; this contribution is in {currency}",
        )
    if amount_minor > t.amount_minor:
        raise ApiError(422, "contribution_too_large", "A contribution can't be more than its entry")
    other = _other_contribution(session, transaction_id, contribution_id)
    if other is not None:
        goal = session.get(PersonalGoal, other.goal_id)
        raise ApiError(422, "already_contributed", f"That entry already counts toward {goal.name}")


def create(
    session: Session,
    actor: Actor,
    body: PersonalGoalContributionIn,
    contribution_id: uuid.UUID | None = None,
) -> PersonalGoalContribution:
    """Recorded but not committed: the one a repeated create already made (deleted or not,
    unchanged), or a new one in your currency."""
    contribution_id = contribution_id or body.id
    replay = replayed_create(
        session, PersonalGoalContribution, contribution_id, lambda c: c.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    goal = _check_goal(session, actor, body.goal_id)
    currency = actor.user.currency
    if goal.currency != currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That goal is in {goal.currency}; this contribution is in {currency}",
        )
    if body.transaction_id is not None:
        _check_entry(session, actor, body.transaction_id, body.amount_minor, currency, None)
    c = PersonalGoalContribution(
        **client_id(contribution_id),
        user_id=actor.user_id,
        goal_id=goal.id,
        transaction_id=body.transaction_id,
        amount_minor=body.amount_minor,
        currency=currency,
        date=body.date,
        note=(body.note or "").strip() or None,
        acting_admin_id=actor.admin_id,
    )
    session.add(c)
    session.flush()
    diff = {
        "goal_id": str(c.goal_id),
        "amount_minor": c.amount_minor,
        "transaction_id": str(c.transaction_id) if c.transaction_id else None,
    }
    record(session, actor, f"{ENTITY}.create", ENTITY, c.id, diff=diff, obj=c)
    return c


def update(
    session: Session, actor: Actor, contribution_id: uuid.UUID, body: PersonalGoalContributionIn
) -> PersonalGoalContribution:
    """The goal, amount and date always; the entry and note when the body has them. Recorded
    but not committed."""
    c = _load(session, actor, contribution_id)
    if c.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this contribution before editing it")
    check_version(c, body.version)
    given = body.model_fields_set
    transaction_id = body.transaction_id if "transaction_id" in given else c.transaction_id
    note = ((body.note or "").strip() or None) if "note" in given else c.note
    if body.goal_id != c.goal_id:
        goal = _check_goal(session, actor, body.goal_id)
        if goal.currency != c.currency:
            raise ApiError(
                422,
                "currency_mismatch",
                f"That goal is in {goal.currency}; this contribution is in {c.currency}",
            )
    if transaction_id is not None and transaction_id != c.transaction_id:
        _check_entry(session, actor, transaction_id, body.amount_minor, c.currency, c.id)
    elif transaction_id is not None and body.amount_minor != c.amount_minor:
        entry = session.get(PersonalTransaction, transaction_id)
        if body.amount_minor > entry.amount_minor:
            raise ApiError(
                422, "contribution_too_large", "A contribution can't be more than its entry"
            )

    def state() -> dict:
        return {
            "goal_id": str(c.goal_id),
            "transaction_id": str(c.transaction_id) if c.transaction_id else None,
            "amount_minor": c.amount_minor,
            "date": c.date.isoformat(),
            "note": c.note,
        }

    before = state()
    c.goal_id, c.transaction_id, c.amount_minor = body.goal_id, transaction_id, body.amount_minor
    c.date, c.note, c.acting_admin_id = body.date, note, actor.admin_id
    after = state()
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if diff:
        record(session, actor, f"{ENTITY}.update", ENTITY, c.id, diff=diff, obj=c)
    return c


def change_deleted(
    session: Session, actor: Actor, contribution_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalGoalContribution:
    """Restoring checks it as if it were made now. Recorded but not committed."""
    c = _load(session, actor, contribution_id)
    if (c.deleted_at is not None) == deleted:
        return c
    check_version(c, version)
    if not deleted:
        goal = session.get(PersonalGoal, c.goal_id)
        if goal.deleted_at is not None:
            raise ApiError(
                422, "unknown_goal", "This contribution's goal was deleted. Restore the goal first"
            )
        _check_goal(session, actor, c.goal_id)
        if c.transaction_id is not None:
            entry = session.get(PersonalTransaction, c.transaction_id)
            if entry.deleted_at is not None:
                raise ApiError(
                    422,
                    "unknown_transaction",
                    "This contribution's entry was deleted. Restore the entry first",
                )
            _check_entry(session, actor, c.transaction_id, c.amount_minor, c.currency, c.id)
    c.deleted_at = datetime.now(UTC) if deleted else None
    c.acting_admin_id = actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, c.id, obj=c)
    return c


def _cascade(session: Session, actor: Actor, rows: list[PersonalGoalContribution], at) -> None:
    for c in rows:
        c.deleted_at, c.acting_admin_id = at, actor.admin_id
        action = "delete" if at is not None else "restore"
        record(session, actor, f"{ENTITY}.{action}", ENTITY, c.id, obj=c)


def follow_entry(
    session: Session, actor: Actor, t: PersonalTransaction, deleted: bool, at: datetime
) -> None:
    """The entry was just deleted at `at`, or is being restored from a delete at `at`: its live
    contributions go with it, or the ones that went with it come back (if their goal is
    live)."""
    q = select(PersonalGoalContribution).where(PersonalGoalContribution.transaction_id == t.id)
    if deleted:
        rows = session.scalars(q.where(PersonalGoalContribution.deleted_at.is_(None))).all()
        _cascade(session, actor, list(rows), at)
        return
    rows = session.scalars(
        q.join(PersonalGoal, PersonalGoal.id == PersonalGoalContribution.goal_id).where(
            PersonalGoalContribution.deleted_at == at, PersonalGoal.deleted_at.is_(None)
        )
    ).all()
    _cascade(session, actor, list(rows), None)


def follow_goal(
    session: Session, actor: Actor, g: PersonalGoal, deleted: bool, at: datetime
) -> None:
    """The goal was just deleted at `at`, or is being restored from a delete at `at`: likewise
    for its contributions (those whose entry is live)."""
    q = select(PersonalGoalContribution).where(PersonalGoalContribution.goal_id == g.id)
    if deleted:
        rows = session.scalars(q.where(PersonalGoalContribution.deleted_at.is_(None))).all()
        _cascade(session, actor, list(rows), at)
        return
    rows = list(session.scalars(q.where(PersonalGoalContribution.deleted_at == at)))
    back = []
    for c in rows:
        if c.transaction_id is not None:
            entry = session.get(PersonalTransaction, c.transaction_id)
            if entry.deleted_at is not None:
                continue
            other = _other_contribution(session, c.transaction_id, c.id)
            if other is not None:
                goal = session.get(PersonalGoal, other.goal_id)
                raise ApiError(
                    422,
                    "already_contributed",
                    f"An entry this goal counted now counts toward {goal.name}",
                )
        back.append(c)
    _cascade(session, actor, back, None)


def check_entry_amount(session: Session, t: PersonalTransaction, amount_minor: int) -> None:
    """An entry can't shrink below what it contributes to a goal."""
    c = _other_contribution(session, t.id, None)
    if c is not None and c.amount_minor > amount_minor:
        goal = session.get(PersonalGoal, c.goal_id)
        raise ApiError(
            422,
            "contribution_too_large",
            f"{format_minor(c.amount_minor, c.currency)} of this entry counts toward {goal.name}. "
            "Lower that contribution first",
        )


def create_contribution(
    session: Session, actor: Actor, body: PersonalGoalContributionIn
) -> PersonalGoalContributionOut:
    actor.require_write()
    c = create(session, actor, body)
    check_counted_once(session, actor.user_id, "contribution")
    session.commit()
    return PersonalGoalContributionOut.model_validate(c)


def update_contribution(
    session: Session, actor: Actor, contribution_id: uuid.UUID, body: PersonalGoalContributionIn
) -> PersonalGoalContributionOut:
    actor.require_write()
    c = update(session, actor, contribution_id, body)
    check_counted_once(session, actor.user_id, "contribution")
    session.commit()
    return PersonalGoalContributionOut.model_validate(c)


def set_deleted(
    session: Session,
    actor: Actor,
    contribution_id: uuid.UUID,
    deleted: bool,
    version: int | None = None,
) -> PersonalGoalContributionOut:
    actor.require_write()
    c = change_deleted(session, actor, contribution_id, deleted, version)
    check_counted_once(session, actor.user_id, "contribution")
    session.commit()
    return PersonalGoalContributionOut.model_validate(c)
