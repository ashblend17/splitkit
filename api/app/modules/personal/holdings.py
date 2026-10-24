"""Holdings: what you keep in an investment account (a fund, shares, a deposit, gold), with its
latest value as you typed it. Only you see them.

The server stores holdings and checks them; gains, whether a value is stale, and how net worth
counts an investment made since the last valuation are worked out on the device. A holding
lives in an investment account of yours. It can't be deleted while a live entry names it (those
are records of money); SIP reminders on it go with it, and come back when it's restored.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.personal import reminder_schedules
from app.modules.personal.models import PersonalAccount, PersonalHolding, PersonalTransaction
from app.modules.personal.schemas import PersonalHoldingIn, PersonalHoldingOut

ENTITY = "personal_holding"
# Kept as they are when a PUT leaves them out.
KEPT = ("account_id", "quantity", "cost_basis_minor")


def _state(h: PersonalHolding) -> dict:
    return {
        "account_id": str(h.account_id),
        "name": h.name,
        "asset_type": h.asset_type,
        "quantity": None if h.quantity is None else f"{h.quantity.normalize():f}",
        "cost_basis_minor": h.cost_basis_minor,
        "market_value_minor": h.market_value_minor,
        "valuation_at": h.valuation_at.isoformat(),
        "valuation_source": h.valuation_source,
    }


def list_holdings(
    session: Session, actor: Actor, account_id: uuid.UUID | None = None, deleted: bool = False
) -> list[PersonalHoldingOut]:
    """Oldest first; with `deleted`, only the deleted ones."""
    gone = PersonalHolding.deleted_at.isnot(None)
    q = select(PersonalHolding).where(
        PersonalHolding.user_id == actor.user_id, gone if deleted else ~gone
    )
    if account_id is not None:
        q = q.where(PersonalHolding.account_id == account_id)
    q = q.order_by(PersonalHolding.created_at, PersonalHolding.id)
    return [PersonalHoldingOut.model_validate(h) for h in session.scalars(q)]


def load(session: Session, actor: Actor, holding_id: uuid.UUID) -> PersonalHolding:
    h = session.get(PersonalHolding, holding_id)
    if h is None or h.user_id != actor.user_id:
        raise not_found("Holding")
    return h


def get_holding(session: Session, actor: Actor, holding_id: uuid.UUID) -> PersonalHoldingOut:
    return PersonalHoldingOut.model_validate(load(session, actor, holding_id))


def _check_account(session: Session, actor: Actor, account_id: uuid.UUID) -> PersonalAccount:
    a = session.get(PersonalAccount, account_id)
    if a is None or a.user_id != actor.user_id or a.deleted_at is not None:
        raise ApiError(422, "unknown_account", "That account isn't available")
    if a.type != "investment":
        raise ApiError(422, "not_investment_account", "Holdings go in an investment account")
    if a.status == "closed":
        raise ApiError(422, "account_closed", "That account is closed")
    if a.currency != actor.user.currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That account is in {a.currency}; your money is in {actor.user.currency}",
        )
    return a


def create(
    session: Session, actor: Actor, body: PersonalHoldingIn, holding_id: uuid.UUID | None = None
) -> PersonalHolding:
    """Recorded but not committed: the one a repeated create already made (deleted or not,
    unchanged), or a new one in its account's currency."""
    holding_id = holding_id or body.id
    replay = replayed_create(
        session, PersonalHolding, holding_id, lambda h: h.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    if body.account_id is None:
        raise ApiError(422, "account_required", "Pick the investment account it's in")
    account = _check_account(session, actor, body.account_id)
    h = PersonalHolding(
        **client_id(holding_id),
        user_id=actor.user_id,
        account_id=account.id,
        name=body.name,
        asset_type=body.asset_type,
        quantity=body.quantity,
        cost_basis_minor=body.cost_basis_minor,
        market_value_minor=body.market_value_minor,
        valuation_at=body.valuation_at,
        valuation_source=body.valuation_source,
        currency=account.currency,
        acting_admin_id=actor.admin_id,
    )
    session.add(h)
    session.flush()
    record(session, actor, f"{ENTITY}.create", ENTITY, h.id, diff=_state(h), obj=h)
    return h


def update(
    session: Session, actor: Actor, holding_id: uuid.UUID, body: PersonalHoldingIn
) -> PersonalHolding:
    """The name, type and valuation always; the account, quantity and cost basis when the body
    has them. Recorded but not committed."""
    h = load(session, actor, holding_id)
    if h.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this holding before editing it")
    check_version(h, body.version)
    given = body.model_fields_set
    if "account_id" in given and body.account_id != h.account_id:
        if body.account_id is None:
            raise ApiError(422, "account_required", "Pick the investment account it's in")
        _check_account(session, actor, body.account_id)
    before = _state(h)
    h.name, h.asset_type, h.market_value_minor = body.name, body.asset_type, body.market_value_minor
    h.valuation_at, h.valuation_source = body.valuation_at, body.valuation_source
    for key in KEPT:
        if key in given:
            setattr(h, key, getattr(body, key))
    after = _state(h)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff:
        return h
    h.updated_at, h.acting_admin_id = datetime.now(UTC), actor.admin_id
    record(session, actor, f"{ENTITY}.update", ENTITY, h.id, diff=diff, obj=h)
    return h


def change_deleted(
    session: Session, actor: Actor, holding_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalHolding:
    """Deleting is refused while a live entry names it; its reminders go with it. Restoring
    needs its account. Recorded but not committed."""
    h = load(session, actor, holding_id)
    if (h.deleted_at is not None) == deleted:
        return h
    check_version(h, version)
    now = datetime.now(UTC)
    if deleted:
        n = session.scalar(
            select(func.count()).where(
                PersonalTransaction.holding_id == h.id, PersonalTransaction.deleted_at.is_(None)
            )
        )
        if n:
            entries = "An entry names" if n == 1 else f"{n} entries name"
            raise ApiError(
                409,
                "holding_in_use",
                f"{entries} this holding. Change or delete them first",
            )
        h.deleted_at = now
        reminder_schedules.follow(session, actor, "holding", h.id, True, now)
    else:
        account = session.get(PersonalAccount, h.account_id)
        if account.deleted_at is not None:
            raise ApiError(
                422,
                "unknown_account",
                "This holding's account was deleted. Restore the account first",
            )
        previous, h.deleted_at = h.deleted_at, None
        reminder_schedules.follow(session, actor, "holding", h.id, False, previous)
    h.updated_at, h.acting_admin_id = now, actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, h.id, obj=h)
    return h


def create_holding(session: Session, actor: Actor, body: PersonalHoldingIn) -> PersonalHoldingOut:
    actor.require_write()
    h = create(session, actor, body)
    session.commit()
    return PersonalHoldingOut.model_validate(h)


def update_holding(
    session: Session, actor: Actor, holding_id: uuid.UUID, body: PersonalHoldingIn
) -> PersonalHoldingOut:
    actor.require_write()
    h = update(session, actor, holding_id, body)
    session.commit()
    return PersonalHoldingOut.model_validate(h)


def set_deleted(
    session: Session, actor: Actor, holding_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalHoldingOut:
    actor.require_write()
    h = change_deleted(session, actor, holding_id, deleted, version)
    session.commit()
    return PersonalHoldingOut.model_validate(h)
