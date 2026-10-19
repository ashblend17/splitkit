"""Your accounts: where your money is (cash, a bank account, an investment account) or what you
owe on (a credit card, a loan). Only you see them.

The server keeps them and checks who owns what; it never computes a balance. The app derives
balances from each account's opening balance and the entries in it (app/lib/core/finance/).

An account can carry the label bank SMS entries have ("HDFC ··4821"). Making one, or giving it
a label, moves in your entries with that label that have no account yet: an account made after
the app has been reading SMS starts with what the bank already told it.

An account can also be linked to another (`linked_account_id`): the same account under a second
label, or a debit card on a bank account. Nothing moves; the app counts its entries in the
other account's balance. And it can carry its full number, which the app matches labels to.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import exists, select
from sqlalchemy.exc import IntegrityError
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
        "linked_account_id": str(a.linked_account_id) if a.linked_account_id else None,
        "account_number": a.account_number,
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


def _linked_here(session: Session, a: PersonalAccount) -> PersonalAccount | None:
    """The first live account linked to `a`, if any."""
    if a.id is None:
        return None
    return session.scalar(
        select(PersonalAccount)
        .where(PersonalAccount.linked_account_id == a.id, PersonalAccount.deleted_at.is_(None))
        .order_by(PersonalAccount.created_at, PersonalAccount.id)
        .limit(1)
    )


def _check_link(session: Session, actor: Actor, a: PersonalAccount, target_id: uuid.UUID) -> None:
    """For `a` about to be linked to account `target_id`: another open account of yours, in the
    same currency, that isn't linked itself. Neither may be an investment account, and `a` may
    have no accounts linked to it and no goal following it (its balance becomes the other's)."""
    if target_id == a.id:
        raise ApiError(422, "link_invalid", "An account can't be linked to itself")
    target = session.get(PersonalAccount, target_id)
    if target is None or target.user_id != actor.user_id or target.deleted_at is not None:
        raise ApiError(422, "unknown_account", "That account isn't available")
    if target.status == "closed":
        raise ApiError(422, "account_closed", "That account is closed")
    if target.linked_account_id is not None:
        root = session.get(PersonalAccount, target.linked_account_id)
        raise ApiError(
            422, "link_invalid", f"{target.name} is part of {root.name}. Link to that one instead"
        )
    if target.currency != a.currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That account is in {target.currency}; this one is in {a.currency}",
        )
    if "investment" in (a.type, target.type):
        raise ApiError(422, "link_invalid", "Investment accounts can't be linked")
    if (child := _linked_here(session, a)) is not None:
        raise ApiError(
            409, "account_in_use", f"{child.name} is linked to this account. Unlink it first"
        )
    if a.id is not None and _followed(session, a):
        raise ApiError(
            409,
            "account_in_use",
            "A goal follows this account's balance, so it can't be linked to another",
        )


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
        account_number=body.account_number,
        status=body.status or "active",
        acting_admin_id=actor.admin_id,
    )
    if body.linked_account_id is not None:
        _check_link(session, actor, a, body.linked_account_id)
        a.linked_account_id = body.linked_account_id
    try:
        with session.begin_nested():
            session.add(a)
            session.flush()
    except IntegrityError as e:
        # Another request made the same account, or took the label, since the checks above
        # (ISS-069): its row is committed by now.
        replay = replayed_create(
            session, PersonalAccount, body.id, lambda a: a.user_id == actor.user_id
        )
        if replay is not None:
            return replay
        if getattr(e.orig.diag, "constraint_name", None) == "uq_personal_accounts_user_sms_label":
            _check_label(session, actor, label, None)
        raise
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
    given = body.model_fields_set
    link = body.linked_account_id if "linked_account_id" in given else a.linked_account_id
    if body.type == "investment" and (link is not None or _linked_here(session, a)):
        raise ApiError(422, "link_invalid", "Investment accounts can't be linked")
    a.name, a.type = body.name, body.type
    if link != a.linked_account_id:
        if link is not None:
            _check_link(session, actor, a, link)
        a.linked_account_id = link
    if "account_number" in given:
        a.account_number = body.account_number
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
    """Soft delete, only while no live entry is in the account (close it instead), no live
    account is linked to it, and no live rule sends money there or filters on it. Its label
    stays taken, so restoring always works; one linked to an account deleted since comes back
    unlinked."""
    actor.require_write()
    a = load(session, actor, account_id)
    if (a.deleted_at is not None) != deleted:
        check_version(a, version)
        if deleted and (child := _linked_here(session, a)) is not None:
            raise ApiError(
                409, "account_in_use", f"{child.name} is linked to this account. Unlink it first"
            )
        if deleted and _in_use(session, a):
            raise ApiError(
                409,
                "account_in_use",
                "This account has entries, so it can't be deleted. Close it instead",
            )
        if deleted:
            allocation_rules.refuse_if_pointed_at(session, "account", account_id=a.id)
            allocation_rules.refuse_if_filtered_on(session, a.id)
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
        diff = None
        if not deleted and a.linked_account_id is not None:
            # Linked to an account deleted since: it comes back on its own.
            target = session.get(PersonalAccount, a.linked_account_id)
            if target is None or target.deleted_at is not None:
                diff = {"linked_account_id": {"from": str(a.linked_account_id), "to": None}}
                a.linked_account_id = None
        a.deleted_at = now if deleted else None
        a.updated_at, a.acting_admin_id = now, actor.admin_id
        action = "delete" if deleted else "restore"
        record(session, actor, f"{ENTITY}.{action}", ENTITY, a.id, diff=diff, obj=a)
        session.commit()
    return PersonalAccountOut.model_validate(a)
