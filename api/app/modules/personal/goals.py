"""Goals: what you're saving towards. Only you see them.

The server keeps goals and checks them; it never computes progress, what's left, what's needed
per month or whether a goal is behind. The app derives those from the source `tracking_mode`
names: the goal's contributions, the balance of the account it follows, or the figure you
typed. Each mode's field is required in that mode and empty in the others; switching modes is
allowed (the app asks you to reconcile), and contributions left behind are kept.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.personal import allocation_rules, contributions, reminder_schedules
from app.modules.personal.models import PersonalAccount, PersonalGoal
from app.modules.personal.schemas import PersonalGoalIn, PersonalGoalOut

ENTITY = "personal_goal"
# Kept as they are when a PUT leaves them out.
KEPT = ("target_date", "expected_return_bp", "priority")


def _state(g: PersonalGoal) -> dict:
    return {
        "name": g.name,
        "target_minor": g.target_minor,
        "target_date": g.target_date.isoformat() if g.target_date else None,
        "tracking_mode": g.tracking_mode,
        "linked_account_id": str(g.linked_account_id) if g.linked_account_id else None,
        "manual_progress_minor": g.manual_progress_minor,
        "expected_return_bp": g.expected_return_bp,
        "priority": g.priority,
        "status": g.status,
    }


def list_goals(session: Session, actor: Actor, deleted: bool = False) -> list[PersonalGoalOut]:
    """By priority, then oldest first; with `deleted`, only the deleted ones."""
    gone = PersonalGoal.deleted_at.isnot(None)
    rows = session.scalars(
        select(PersonalGoal)
        .where(PersonalGoal.user_id == actor.user_id, gone if deleted else ~gone)
        .order_by(PersonalGoal.priority, PersonalGoal.created_at, PersonalGoal.id)
    )
    return [PersonalGoalOut.model_validate(g) for g in rows]


def load(session: Session, actor: Actor, goal_id: uuid.UUID) -> PersonalGoal:
    g = session.get(PersonalGoal, goal_id)
    if g is None or g.user_id != actor.user_id:
        raise not_found("Goal")
    return g


def get_goal(session: Session, actor: Actor, goal_id: uuid.UUID) -> PersonalGoalOut:
    return PersonalGoalOut.model_validate(load(session, actor, goal_id))


def _check_account(session: Session, actor: Actor, account_id: uuid.UUID, currency: str) -> None:
    a = session.get(PersonalAccount, account_id)
    if a is None or a.user_id != actor.user_id or a.deleted_at is not None:
        raise ApiError(422, "unknown_account", "That account isn't available")
    if a.currency != currency:
        raise ApiError(
            422, "currency_mismatch", f"That account is in {a.currency}; this goal is in {currency}"
        )


def _mode(body: PersonalGoalIn, g: PersonalGoal | None) -> tuple[str, uuid.UUID | None, int | None]:
    """The tracking mode with its account and typed progress, as the goal will be. A value kept
    from before (the body left it out) is dropped when the mode no longer uses it; one the body
    gives for a mode that doesn't use it is refused."""
    given = body.model_fields_set if g is not None else set(type(body).model_fields)

    def pick(key: str):
        return getattr(body, key) if key in given else getattr(g, key)

    mode, account, progress = (
        pick("tracking_mode"),
        pick("linked_account_id"),
        pick("manual_progress_minor"),
    )
    if mode == "linked_balance" and account is None:
        raise ApiError(422, "account_required", "Pick the account this goal follows")
    if mode != "linked_balance" and account is not None:
        if "linked_account_id" in given:
            raise ApiError(
                422,
                "account_not_used",
                "Only a goal that follows an account's balance has an account",
            )
        account = None
    if mode == "manual" and progress is None:
        raise ApiError(422, "progress_required", "Say how much is saved so far")
    if mode != "manual" and progress is not None:
        if "manual_progress_minor" in given:
            raise ApiError(
                422, "progress_not_used", "Only a goal you track by hand has progress you type"
            )
        progress = None
    return mode, account, progress


def create(
    session: Session, actor: Actor, body: PersonalGoalIn, goal_id: uuid.UUID | None = None
) -> PersonalGoal:
    """Recorded but not committed: the one a repeated create already made (deleted or not,
    unchanged), or a new one in your currency."""
    goal_id = goal_id or body.id
    replay = replayed_create(session, PersonalGoal, goal_id, lambda g: g.user_id == actor.user_id)
    if replay is not None:
        return replay
    mode, account, progress = _mode(body, None)
    currency = actor.user.currency
    if account is not None:
        _check_account(session, actor, account, currency)
    g = PersonalGoal(
        **client_id(goal_id),
        user_id=actor.user_id,
        name=body.name,
        target_minor=body.target_minor,
        currency=currency,
        target_date=body.target_date,
        tracking_mode=mode,
        linked_account_id=account,
        manual_progress_minor=progress,
        expected_return_bp=body.expected_return_bp,
        priority=body.priority,
        status=body.status or "active",
        acting_admin_id=actor.admin_id,
    )
    session.add(g)
    session.flush()
    record(session, actor, f"{ENTITY}.create", ENTITY, g.id, diff=_state(g), obj=g)
    return g


def update(
    session: Session, actor: Actor, goal_id: uuid.UUID, body: PersonalGoalIn
) -> PersonalGoal:
    """Name and target always; the status when it isn't null; anything else when the body has
    it. Recorded but not committed."""
    g = load(session, actor, goal_id)
    if g.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this goal before editing it")
    check_version(g, body.version)
    mode, account, progress = _mode(body, g)
    if account is not None and account != g.linked_account_id:
        _check_account(session, actor, account, g.currency)
    before = _state(g)
    g.name, g.target_minor = body.name, body.target_minor
    for key in KEPT:
        if key in body.model_fields_set:
            setattr(g, key, getattr(body, key))
    status = body.status or g.status
    takes_money = g.tracking_mode == "contribution" and g.status != "archived"
    if takes_money and (mode != "contribution" or status == "archived"):
        allocation_rules.refuse_if_pointed_at(session, "goal", goal_id=g.id)
    g.tracking_mode, g.linked_account_id, g.manual_progress_minor = mode, account, progress
    g.status = status
    after = _state(g)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff:
        return g
    g.updated_at, g.acting_admin_id = datetime.now(UTC), actor.admin_id
    record(session, actor, f"{ENTITY}.update", ENTITY, g.id, diff=diff, obj=g)
    return g


def change_deleted(
    session: Session, actor: Actor, goal_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalGoal:
    """Soft delete or restore, with the contributions that go with it. Restoring refuses a goal
    whose account was deleted. Recorded but not committed."""
    g = load(session, actor, goal_id)
    if (g.deleted_at is not None) == deleted:
        return g
    check_version(g, version)
    now = datetime.now(UTC)
    if deleted:
        allocation_rules.refuse_if_pointed_at(session, "goal", goal_id=g.id)
        g.deleted_at = now
        contributions.follow_goal(session, actor, g, True, now)
        reminder_schedules.follow(session, actor, "goal", g.id, True, now)
    else:
        if g.linked_account_id is not None:
            account = session.get(PersonalAccount, g.linked_account_id)
            if account.deleted_at is not None:
                raise ApiError(
                    422,
                    "unknown_account",
                    "This goal's account was deleted. Restore the account first",
                )
        previous, g.deleted_at = g.deleted_at, None
        contributions.follow_goal(session, actor, g, False, previous)
        reminder_schedules.follow(session, actor, "goal", g.id, False, previous)
    g.updated_at, g.acting_admin_id = now, actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, g.id, obj=g)
    return g


def create_goal(session: Session, actor: Actor, body: PersonalGoalIn) -> PersonalGoalOut:
    actor.require_write()
    g = create(session, actor, body)
    contributions.check_counted_once(session, actor.user_id, "goal")
    session.commit()
    return PersonalGoalOut.model_validate(g)


def update_goal(
    session: Session, actor: Actor, goal_id: uuid.UUID, body: PersonalGoalIn
) -> PersonalGoalOut:
    actor.require_write()
    g = update(session, actor, goal_id, body)
    contributions.check_counted_once(session, actor.user_id, "goal")
    session.commit()
    return PersonalGoalOut.model_validate(g)


def set_deleted(
    session: Session, actor: Actor, goal_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalGoalOut:
    actor.require_write()
    g = change_deleted(session, actor, goal_id, deleted, version)
    contributions.check_counted_once(session, actor.user_id, "goal")
    session.commit()
    return PersonalGoalOut.model_validate(g)
