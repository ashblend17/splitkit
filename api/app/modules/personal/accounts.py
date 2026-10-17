"""Your accounts: where your money is (cash, a bank account, an investment account) or what you
owe on (a credit card, a loan). Only you see them.

The server keeps them and checks who owns what; it never computes a balance. The app derives
balances from each account's opening balance and the entries in it (app/lib/core/finance/).

An account can carry the label bank SMS entries have ("HDFC ··4821"). Making one, or giving it
a label, moves in your entries with that label that have no account yet: an account made after
the app has been reading SMS starts with what the bank already told it.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import exists, select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.personal import allocation_rules
from app.modules.personal.models import (
    PersonalAccount,
    PersonalGoal,
    PersonalHolding,
    PersonalTransaction,
)
from app.modules.personal.schemas import PersonalAccountIn, PersonalAccountOut

ENTITY = "personal_account"


def _text(value: str | None) -> str | None:
    """Trimmed, and blank as none."""
    return (value or "").strip() or None


def _state(a: PersonalAccount) -> dict:
    return {
        "name": a.name,
        "type": a.type,
        "opening_balance_minor": a.opening_balance_minor,
        "sms_label": a.sms_label,
        "status": a.status,
    }


def list_accounts(
    session: Session, actor: Actor, deleted: bool = False
) -> list[PersonalAccountOut]:
    """Active and closed ones, oldest first; with `deleted`, only the deleted ones."""
    gone = PersonalAccount.deleted_at.isnot(None)
    rows = session.scalars(
        select(PersonalAccount)
        .where(PersonalAccount.user_id == actor.user_id, gone if deleted else ~gone)
        .order_by(PersonalAccount.created_at, PersonalAccount.id)
    )
    return [PersonalAccountOut.model_validate(a) for a in rows]


def load(session: Session, actor: Actor, account_id: uuid.UUID) -> PersonalAccount:
    a = session.get(PersonalAccount, account_id)
    if a is None or a.user_id != actor.user_id:
        raise not_found("Account")
    return a


def get_account(session: Session, actor: Actor, account_id: uuid.UUID) -> PersonalAccountOut:
    return PersonalAccountOut.model_validate(load(session, actor, account_id))


def for_label(
    session: Session, user_id: uuid.UUID, label: str, currency: str
) -> PersonalAccount | None:
    """Your live, active account with this SMS label in this currency, if there is one: where
    an entry from an older app (which knows the label, not the account) goes."""
    return session.scalar(
        select(PersonalAccount).where(
            PersonalAccount.user_id == user_id,
            PersonalAccount.sms_label == label,
            PersonalAccount.currency == currency,
            PersonalAccount.status == "active",
            PersonalAccount.deleted_at.is_(None),
        )
    )


def _check_label(
    session: Session, actor: Actor, label: str | None, account: PersonalAccount | None
) -> None:
    """One account per label, ever: the unique index counts deleted accounts too."""
    if label is None:
        return
    q = select(PersonalAccount).where(
        PersonalAccount.user_id == actor.user_id, PersonalAccount.sms_label == label
    )
    if account is not None:
        q = q.where(PersonalAccount.id != account.id)
    holder = session.scalar(q)
    if holder is None:
        return
    message = (
        "A deleted account has that label. Restore it instead"
        if holder.deleted_at
        else f"{holder.name} already has that label"
    )
    raise ApiError(409, "label_taken", message, account_id=str(holder.id))


def _claim(session: Session, actor: Actor, a: PersonalAccount) -> None:
    """Moves your entries with the account's label, in its currency and with no account yet,
    into it (deleted ones too). Each is recorded, so devices see the change. Only into an active
    account: a closed one takes no new entries."""
    if a.sms_label is None or a.status != "active":
        return
    rows = session.scalars(
        select(PersonalTransaction).where(
            PersonalTransaction.user_id == a.user_id,
            PersonalTransaction.account_id.is_(None),
            PersonalTransaction.account == a.sms_label,
            PersonalTransaction.currency == a.currency,
        )
    ).all()
    for t in rows:
        t.account_id, t.acting_admin_id = a.id, actor.admin_id
        diff = {"account_id": {"from": None, "to": str(a.id)}}
        record(session, actor, "personal.update", "personal_transaction", t.id, diff=diff, obj=t)


def create(session: Session, actor: Actor, body: PersonalAccountIn) -> PersonalAccount:
    """The account for `body`, recorded but not committed: the one a repeated create already
    made (deleted or not, unchanged), or a new one in your currency."""
    replay = replayed_create(
        session, PersonalAccount, body.id, lambda a: a.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    label = _text(body.sms_label)
    _check_label(session, actor, label, None)
    a = PersonalAccount(
        **client_id(body.id),
        user_id=actor.user_id,
        name=body.name,
        type=body.type,
        currency=actor.user.currency,
        opening_balance_minor=body.opening_balance_minor,
        sms_label=label,
        status=body.status or "active",
        acting_admin_id=actor.admin_id,
    )
    session.add(a)
    session.flush()
    record(session, actor, f"{ENTITY}.create", ENTITY, a.id, diff=_state(a), obj=a)
    _claim(session, actor, a)
    return a


def update(
    session: Session, actor: Actor, account_id: uuid.UUID, body: PersonalAccountIn
) -> PersonalAccount:
    """Name and type always; the opening balance and the label when the body has them; the
    status when it isn't null. Recorded but not committed."""
    a = load(session, actor, account_id)
    if a.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this account before editing it")
    check_version(a, body.version)
    before = _state(a)
    if a.type == "investment" and body.type != "investment" and _holds(session, a):
        raise ApiError(
            409, "account_in_use", "This account has holdings, so it stays an investment account"
        )
    a.name, a.type = body.name, body.type
    if "opening_balance_minor" in body.model_fields_set:
        a.opening_balance_minor = body.opening_balance_minor
    if "sms_label" in body.model_fields_set:
        label = _text(body.sms_label)
        if label != a.sms_label:
            _check_label(session, actor, label, a)
            a.sms_label = label
    if body.status == "closed" and a.status != "closed":
        allocation_rules.refuse_if_pointed_at(session, "account", account_id=a.id)
    if body.status is not None:
        a.status = body.status
    after = _state(a)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff:
        return a
    a.updated_at, a.acting_admin_id = datetime.now(UTC), actor.admin_id
    action = "update"
    if "status" in diff:
        action = "close" if a.status == "closed" else "reopen"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, a.id, diff=diff, obj=a)
    if "sms_label" in diff or "status" in diff:
        _claim(session, actor, a)
    return a


def _in_use(session: Session, a: PersonalAccount) -> bool:
    return bool(
        session.scalar(
            select(
                exists().where(
                    PersonalTransaction.account_id == a.id,
                    PersonalTransaction.deleted_at.is_(None),
                )
            )
        )
    )


def _holds(session: Session, a: PersonalAccount) -> bool:
    return bool(
        session.scalar(
            select(
                exists().where(
                    PersonalHolding.account_id == a.id, PersonalHolding.deleted_at.is_(None)
                )
            )
        )
    )


def _followed(session: Session, a: PersonalAccount) -> bool:
    return bool(
        session.scalar(
            select(
                exists().where(
                    PersonalGoal.linked_account_id == a.id, PersonalGoal.deleted_at.is_(None)
                )
            )
        )
    )


def create_account(session: Session, actor: Actor, body: PersonalAccountIn) -> PersonalAccountOut:
    actor.require_write()
    a = create(session, actor, body)
    session.commit()
    return PersonalAccountOut.model_validate(a)


def update_account(
    session: Session, actor: Actor, account_id: uuid.UUID, body: PersonalAccountIn
) -> PersonalAccountOut:
    actor.require_write()
    a = update(session, actor, account_id, body)
    session.commit()
    return PersonalAccountOut.model_validate(a)


def set_deleted(
    session: Session,
    actor: Actor,
    account_id: uuid.UUID,
    deleted: bool,
    version: int | None = None,
) -> PersonalAccountOut:
    """Soft delete, only while no live entry is in the account (close it instead). Its label
    stays taken, so restoring always works."""
    actor.require_write()
    a = load(session, actor, account_id)
    if (a.deleted_at is not None) != deleted:
        check_version(a, version)
        if deleted and _in_use(session, a):
            raise ApiError(
                409,
                "account_in_use",
                "This account has entries, so it can't be deleted. Close it instead",
            )
        if deleted:
            allocation_rules.refuse_if_pointed_at(session, "account", account_id=a.id)
            if _holds(session, a):
                raise ApiError(
                    409, "account_in_use", "This account has holdings, so it can't be deleted"
                )
        if deleted and _followed(session, a):
            raise ApiError(
                409,
                "account_in_use",
                "A goal follows this account's balance, so it can't be deleted",
            )
        now = datetime.now(UTC)
        a.deleted_at = now if deleted else None
        a.updated_at, a.acting_admin_id = now, actor.admin_id
        action = "delete" if deleted else "restore"
        record(session, actor, f"{ENTITY}.{action}", ENTITY, a.id, obj=a)
        session.commit()
    return PersonalAccountOut.model_validate(a)
