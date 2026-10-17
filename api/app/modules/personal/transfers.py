"""Transfers between your own accounts. A transfer is two entries, its legs: one out of an
account and one into another, of the same amount, sharing `transfer_group_id`. Neither leg is
income or spending.

Every write checks the groups it touched once its rows are flushed, so legs can be written in
any order inside one request. The deferred trigger from migration 0013 backs this up at commit.
Deleting or restoring a leg takes its partner with it.
"""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.modules.personal.models import PersonalTransaction

UNPAIRED_CREATE = "A transfer needs both halves in one request (POST /personal/batch)"
UNPAIRED_UPDATE = "Change both halves of a transfer together"


def _invalid(message: str, group: uuid.UUID) -> ApiError:
    return ApiError(422, "transfer_invalid", message, transfer_group_id=str(group))


def check_groups(session: Session, user_id: uuid.UUID, touched: dict[uuid.UUID, bool]) -> None:
    """Each touched group's live legs are none, or a whole pair. `touched` maps a group to
    whether a create touched it, which only changes the message for a lone leg."""
    session.flush()
    for group, created in touched.items():
        legs = list(
            session.scalars(
                select(PersonalTransaction).where(
                    PersonalTransaction.transfer_group_id == group,
                    PersonalTransaction.deleted_at.is_(None),
                )
            )
        )
        if not legs:
            continue
        if any(t.user_id != user_id for t in legs):
            raise _invalid("That transfer_group_id is already used", group)
        if len(legs) == 1:
            message = UNPAIRED_CREATE if created else UNPAIRED_UPDATE
            raise ApiError(422, "transfer_unpaired", message, transfer_group_id=str(group))
        if len(legs) > 2:
            raise _invalid("A transfer has two halves, not more", group)
        a, b = legs
        if a.amount_minor != b.amount_minor:
            raise _invalid("Both halves of a transfer must be the same amount", group)
        if a.currency != b.currency:
            raise _invalid("Both halves of a transfer must be in the same currency", group)
        if {a.direction, b.direction} != {"in", "out"}:
            raise _invalid("One half goes out and the other comes in", group)
        if a.account_id == b.account_id:
            raise _invalid("A transfer moves money between two different accounts", group)


def partners(session: Session, t: PersonalTransaction) -> list[PersonalTransaction]:
    """The other legs of `t`'s transfer that are in the state `t` is in (live or deleted)."""
    if t.transfer_group_id is None:
        return []
    deleted = PersonalTransaction.deleted_at.isnot(None)
    return list(
        session.scalars(
            select(PersonalTransaction).where(
                PersonalTransaction.user_id == t.user_id,
                PersonalTransaction.transfer_group_id == t.transfer_group_id,
                PersonalTransaction.id != t.id,
                deleted if t.deleted_at is not None else ~deleted,
            )
        )
    )
