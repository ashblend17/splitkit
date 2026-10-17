"""Reminder schedules: a monthly reminder for a recurring investment (a SIP) into a goal or a
holding. Only you see them.

A schedule only reminds: nothing ever records an entry for it (spec §4.7), and the next due date
is worked out on the device. It follows its goal or holding: deleted with it (the same
`deleted_at`) and back when it's restored.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.personal.models import PersonalGoal, PersonalHolding, PersonalReminderSchedule
from app.modules.personal.schemas import PersonalReminderScheduleIn, PersonalReminderScheduleOut

ENTITY = "personal_reminder_schedule"
# Kept as they are when a PUT leaves them out (the target is resolved apart).
KEPT = ("amount_minor", "active")


def _state(s: PersonalReminderSchedule) -> dict:
    return {
        "goal_id": str(s.goal_id) if s.goal_id else None,
        "holding_id": str(s.holding_id) if s.holding_id else None,
        "day_of_month": s.day_of_month,
        "amount_minor": s.amount_minor,
        "active": s.active,
    }


def list_schedules(
    session: Session,
    actor: Actor,
    *,
    goal_id: uuid.UUID | None = None,
    holding_id: uuid.UUID | None = None,
    deleted: bool = False,
) -> list[PersonalReminderScheduleOut]:
    """By day of the month, then oldest first; with `deleted`, only the deleted ones."""
    gone = PersonalReminderSchedule.deleted_at.isnot(None)
    q = select(PersonalReminderSchedule).where(
        PersonalReminderSchedule.user_id == actor.user_id, gone if deleted else ~gone
    )
    if goal_id is not None:
        q = q.where(PersonalReminderSchedule.goal_id == goal_id)
    if holding_id is not None:
        q = q.where(PersonalReminderSchedule.holding_id == holding_id)
    q = q.order_by(
        PersonalReminderSchedule.day_of_month,
        PersonalReminderSchedule.created_at,
        PersonalReminderSchedule.id,
    )
    return [PersonalReminderScheduleOut.model_validate(s) for s in session.scalars(q)]


def _load(session: Session, actor: Actor, schedule_id: uuid.UUID) -> PersonalReminderSchedule:
    s = session.get(PersonalReminderSchedule, schedule_id)
    if s is None or s.user_id != actor.user_id:
        raise not_found("Reminder")
    return s


def get_schedule(
    session: Session, actor: Actor, schedule_id: uuid.UUID
) -> PersonalReminderScheduleOut:
    return PersonalReminderScheduleOut.model_validate(_load(session, actor, schedule_id))


def _target(
    body: PersonalReminderScheduleIn, s: PersonalReminderSchedule | None
) -> tuple[uuid.UUID | None, uuid.UUID | None]:
    """Exactly one of a goal and a holding. On an update, giving one replaces the other."""
    given = body.model_fields_set if s is not None else set(type(body).model_fields)
    goal = body.goal_id if "goal_id" in given else s.goal_id
    holding = body.holding_id if "holding_id" in given else s.holding_id
    if goal is not None and holding is not None:
        if "goal_id" in given and "holding_id" not in given:
            holding = None
        elif "holding_id" in given and "goal_id" not in given:
            goal = None
        else:
            raise ApiError(422, "target_invalid", "A reminder is for a goal or a holding, not both")
    if goal is None and holding is None:
        raise ApiError(422, "target_required", "Pick the goal or holding it reminds you about")
    return goal, holding


def _check_target(
    session: Session, actor: Actor, goal_id: uuid.UUID | None, holding_id: uuid.UUID | None
) -> None:
    if goal_id is not None:
        g = session.get(PersonalGoal, goal_id)
        if g is None or g.user_id != actor.user_id or g.deleted_at is not None:
            raise ApiError(422, "unknown_goal", "That goal isn't available")
        if g.status == "archived":
            raise ApiError(422, "goal_archived", f"{g.name} is archived")
        return
    h = session.get(PersonalHolding, holding_id)
    if h is None or h.user_id != actor.user_id or h.deleted_at is not None:
        raise ApiError(422, "unknown_holding", "That holding isn't available")


def create(
    session: Session,
    actor: Actor,
    body: PersonalReminderScheduleIn,
    schedule_id: uuid.UUID | None = None,
) -> PersonalReminderSchedule:
    """Recorded but not committed: the one a repeated create already made (deleted or not,
    unchanged), or a new one in your currency."""
    schedule_id = schedule_id or body.id
    replay = replayed_create(
        session, PersonalReminderSchedule, schedule_id, lambda s: s.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    goal, holding = _target(body, None)
    _check_target(session, actor, goal, holding)
    s = PersonalReminderSchedule(
        **client_id(schedule_id),
        user_id=actor.user_id,
        goal_id=goal,
        holding_id=holding,
        day_of_month=body.day_of_month,
        amount_minor=body.amount_minor,
        currency=actor.user.currency,
        active=body.active,
        acting_admin_id=actor.admin_id,
    )
    session.add(s)
    session.flush()
    record(session, actor, f"{ENTITY}.create", ENTITY, s.id, diff=_state(s), obj=s)
    return s


def update(
    session: Session, actor: Actor, schedule_id: uuid.UUID, body: PersonalReminderScheduleIn
) -> PersonalReminderSchedule:
    """The day always; anything else when the body has it. Recorded but not committed."""
    s = _load(session, actor, schedule_id)
    if s.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this reminder before editing it")
    check_version(s, body.version)
    goal, holding = _target(body, s)
    if (goal, holding) != (s.goal_id, s.holding_id):
        _check_target(session, actor, goal, holding)
    before = _state(s)
    s.goal_id, s.holding_id, s.day_of_month = goal, holding, body.day_of_month
    for key in KEPT:
        if key in body.model_fields_set:
            setattr(s, key, getattr(body, key))
    after = _state(s)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff:
        return s
    s.updated_at, s.acting_admin_id = datetime.now(UTC), actor.admin_id
    record(session, actor, f"{ENTITY}.update", ENTITY, s.id, diff=diff, obj=s)
    return s


def change_deleted(
    session: Session, actor: Actor, schedule_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalReminderSchedule:
    """Restoring needs its goal or holding. Recorded but not committed."""
    s = _load(session, actor, schedule_id)
    if (s.deleted_at is not None) == deleted:
        return s
    check_version(s, version)
    if not deleted:
        target = (
            session.get(PersonalGoal, s.goal_id)
            if s.goal_id
            else session.get(PersonalHolding, s.holding_id)
        )
        if target.deleted_at is not None:
            what = "goal" if s.goal_id else "holding"
            raise ApiError(
                422,
                f"unknown_{what}",
                f"This reminder's {what} was deleted. Restore it first",
            )
    now = datetime.now(UTC)
    s.deleted_at = now if deleted else None
    s.updated_at, s.acting_admin_id = now, actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, s.id, obj=s)
    return s


def follow(
    session: Session, actor: Actor, kind: str, target_id: uuid.UUID, deleted: bool, at: datetime
) -> None:
    """The goal or holding (`kind`) was just deleted at `at`, or is being restored from a
    delete at `at`: its live schedules go with it, or the ones that went with it come back."""
    column = (
        PersonalReminderSchedule.goal_id if kind == "goal" else PersonalReminderSchedule.holding_id
    )
    q = select(PersonalReminderSchedule).where(column == target_id)
    q = q.where(
        PersonalReminderSchedule.deleted_at.is_(None)
        if deleted
        else PersonalReminderSchedule.deleted_at == at
    )
    for s in session.scalars(q).all():
        s.deleted_at = at if deleted else None
        s.updated_at, s.acting_admin_id = datetime.now(UTC), actor.admin_id
        action = "delete" if deleted else "restore"
        record(session, actor, f"{ENTITY}.{action}", ENTITY, s.id, obj=s)


def create_schedule(
    session: Session, actor: Actor, body: PersonalReminderScheduleIn
) -> PersonalReminderScheduleOut:
    actor.require_write()
    s = create(session, actor, body)
    session.commit()
    return PersonalReminderScheduleOut.model_validate(s)


def update_schedule(
    session: Session, actor: Actor, schedule_id: uuid.UUID, body: PersonalReminderScheduleIn
) -> PersonalReminderScheduleOut:
    actor.require_write()
    s = update(session, actor, schedule_id, body)
    session.commit()
    return PersonalReminderScheduleOut.model_validate(s)


def set_deleted(
    session: Session,
    actor: Actor,
    schedule_id: uuid.UUID,
    deleted: bool,
    version: int | None = None,
) -> PersonalReminderScheduleOut:
    actor.require_write()
    s = change_deleted(session, actor, schedule_id, deleted, version)
    session.commit()
    return PersonalReminderScheduleOut.model_validate(s)
