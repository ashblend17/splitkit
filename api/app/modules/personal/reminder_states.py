"""Reminder decisions: dismissed, snoozed until a time, or done, per reminder. Only you see
them.

Reminders themselves are worked out on each device, with a dedup key (`type:entity:window`, e.g.
"goal_behind:<goal id>:2026-10"); which ones are pending and which were shown stays on the
device. Only your decisions are stored, so every device honours them. There's one decision per
key, ever, and its id comes from the key (ledger_rules.reminder_state_id), so two devices
deciding about the same reminder write the same row: making a decision for a key that has one
replaces it (the newest wins unless you send the `version` you saw).
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version
from app.modules.auth.deps import Actor
from app.modules.personal.ledger_rules import reminder_state_id
from app.modules.personal.models import PersonalReminderState
from app.modules.personal.schemas import PersonalReminderStateIn, PersonalReminderStateOut

ENTITY = "personal_reminder_state"


def _state(r: PersonalReminderState) -> dict:
    return {
        "status": r.status,
        "snoozed_until": r.snoozed_until.isoformat() if r.snoozed_until else None,
    }


def list_states(
    session: Session, actor: Actor, deleted: bool = False
) -> list[PersonalReminderStateOut]:
    """Oldest first; with `deleted`, only the deleted ones (decisions taken back)."""
    gone = PersonalReminderState.deleted_at.isnot(None)
    rows = session.scalars(
        select(PersonalReminderState)
        .where(PersonalReminderState.user_id == actor.user_id, gone if deleted else ~gone)
        .order_by(PersonalReminderState.created_at, PersonalReminderState.id)
    )
    return [PersonalReminderStateOut.model_validate(r) for r in rows]


def _load(session: Session, actor: Actor, state_id: uuid.UUID) -> PersonalReminderState:
    r = session.get(PersonalReminderState, state_id)
    if r is None or r.user_id != actor.user_id:
        raise not_found("Reminder decision")
    return r


def get_state(session: Session, actor: Actor, state_id: uuid.UUID) -> PersonalReminderStateOut:
    return PersonalReminderStateOut.model_validate(_load(session, actor, state_id))


def _check(body: PersonalReminderStateIn) -> None:
    if body.status == "snoozed" and body.snoozed_until is None:
        raise ApiError(422, "snooze_until_required", "Say until when it's snoozed")
    if body.status != "snoozed" and body.snoozed_until is not None:
        raise ApiError(422, "snooze_until_not_used", "Only a snoozed reminder has an until time")


def _apply(
    session: Session, actor: Actor, r: PersonalReminderState, body: PersonalReminderStateIn
) -> None:
    before = _state(r)
    was_deleted = r.deleted_at is not None
    r.status, r.snoozed_until, r.deleted_at = body.status, body.snoozed_until, None
    after = _state(r)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff and not was_deleted:
        return
    r.updated_at, r.acting_admin_id = datetime.now(UTC), actor.admin_id
    action = "restore" if was_deleted and not diff else "update"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, r.id, diff=diff, obj=r)


def upsert(
    session: Session,
    actor: Actor,
    body: PersonalReminderStateIn,
    state_id: uuid.UUID | None = None,
) -> tuple[PersonalReminderState, bool]:
    """The decision for the body's key, made or replaced (a deleted one comes back with it).
    Returns it and whether it was made. Recorded but not committed."""
    if body.dedup_key is None:
        raise ApiError(422, "dedup_key_required", "Say which reminder this is")
    expected = reminder_state_id(actor.user_id, body.dedup_key)
    given = state_id or body.id
    if given is not None and given != expected:
        raise ApiError(
            422, "id_invalid", "A reminder decision's id comes from its key (reminder_state_id)"
        )
    _check(body)
    r = session.scalar(
        select(PersonalReminderState).where(
            PersonalReminderState.user_id == actor.user_id,
            PersonalReminderState.dedup_key == body.dedup_key,
        )
    )
    if r is not None:
        check_version(r, body.version)
        _apply(session, actor, r, body)
        return r, False
    r = PersonalReminderState(
        id=expected,
        user_id=actor.user_id,
        dedup_key=body.dedup_key,
        status=body.status,
        snoozed_until=body.snoozed_until,
        acting_admin_id=actor.admin_id,
    )
    session.add(r)
    session.flush()
    diff = {"dedup_key": r.dedup_key, **_state(r)}
    record(session, actor, f"{ENTITY}.create", ENTITY, r.id, diff=diff, obj=r)
    return r, True


def update(
    session: Session, actor: Actor, state_id: uuid.UUID, body: PersonalReminderStateIn
) -> PersonalReminderState:
    """A new decision for the same reminder. Recorded but not committed."""
    r = _load(session, actor, state_id)
    if r.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this decision before changing it")
    if body.dedup_key not in (None, r.dedup_key):
        raise ApiError(422, "dedup_key_fixed", "A decision stays with its reminder")
    check_version(r, body.version)
    _check(body)
    _apply(session, actor, r, body)
    return r


def change_deleted(
    session: Session, actor: Actor, state_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalReminderState:
    """Deleting takes the decision back: the reminder shows again. Recorded but not
    committed."""
    r = _load(session, actor, state_id)
    if (r.deleted_at is not None) == deleted:
        return r
    check_version(r, version)
    now = datetime.now(UTC)
    r.deleted_at = now if deleted else None
    r.updated_at, r.acting_admin_id = now, actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, r.id, obj=r)
    return r


def save_state(
    session: Session, actor: Actor, body: PersonalReminderStateIn
) -> tuple[PersonalReminderStateOut, bool]:
    actor.require_write()
    r, made = upsert(session, actor, body)
    session.commit()
    return PersonalReminderStateOut.model_validate(r), made


def update_state(
    session: Session, actor: Actor, state_id: uuid.UUID, body: PersonalReminderStateIn
) -> PersonalReminderStateOut:
    actor.require_write()
    r = update(session, actor, state_id, body)
    session.commit()
    return PersonalReminderStateOut.model_validate(r)


def set_deleted(
    session: Session, actor: Actor, state_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalReminderStateOut:
    actor.require_write()
    r = change_deleted(session, actor, state_id, deleted, version)
    session.commit()
    return PersonalReminderStateOut.model_validate(r)
