import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.categories.models import Category
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups.models import GroupMember
from app.modules.personal.models import PersonalAccount, PersonalTransaction
from app.modules.settlements.models import Settlement


def query(
    session: Session,
    user_id: uuid.UUID,
    *,
    start: date | None = None,
    end: date | None = None,
    type: str | None = None,
    category_keys: list[str] | None = None,
    deleted: bool = False,
    account: str | None = None,
    account_id: uuid.UUID | None = None,
    channel: str | None = None,
    source: str | None = None,
    reviewed: bool | None = None,
) -> list[PersonalTransaction]:
    q = select(PersonalTransaction).where(PersonalTransaction.user_id == user_id)
    q = q.where(
        PersonalTransaction.deleted_at.isnot(None)
        if deleted
        else PersonalTransaction.deleted_at.is_(None)
    )
    if start:
        q = q.where(PersonalTransaction.date >= start)
    if end:
        q = q.where(PersonalTransaction.date <= end)
    if type:
        q = q.where(PersonalTransaction.type == type)
    if account:
        q = q.where(PersonalTransaction.account == account)
    if account_id:
        # With the accounts linked to it: their entries count in its balance.
        parts = select(PersonalAccount.id).where(
            PersonalAccount.user_id == user_id, PersonalAccount.linked_account_id == account_id
        )
        q = q.where(
            (PersonalTransaction.account_id == account_id)
            | PersonalTransaction.account_id.in_(parts)
        )
    if channel:
        q = q.where(PersonalTransaction.channel == channel)
    if source:
        q = q.where(PersonalTransaction.source == source)
    if reviewed is not None:
        q = q.where(PersonalTransaction.reviewed.is_(reviewed))
    if category_keys:
        q = q.join(Category, Category.id == PersonalTransaction.category_id).where(
            Category.key.in_(category_keys)
        )
    return list(
        session.scalars(
            q.order_by(
                PersonalTransaction.date.desc(),
                PersonalTransaction.created_at.desc(),
                PersonalTransaction.id.desc(),
            )
        )
    )


def current_groups(user_id: uuid.UUID):
    """The groups you're still in, as a subquery. A group you've left drops out of your group
    share, as it does from your device (ISS-039)."""
    return select(GroupMember.group_id).where(
        GroupMember.user_id == user_id, GroupMember.left_at.is_(None)
    )


def group_share(session: Session, user_id: uuid.UUID, start: date, end: date, currency: str) -> int:
    """Your shares of live expenses in `currency`, in groups you're still in, dated between
    start and end (inclusive)."""
    total = session.scalar(
        select(func.coalesce(func.sum(ExpenseSplit.share_minor), 0))
        .join(Expense, Expense.id == ExpenseSplit.expense_id)
        .where(
            ExpenseSplit.user_id == user_id,
            Expense.deleted_at.is_(None),
            Expense.currency == currency,
            Expense.group_id.in_(current_groups(user_id)),
            Expense.date >= start,
            Expense.date <= end,
        )
    )
    return int(total)


def covered_ids(session: Session, user_id: uuid.UUID) -> set[uuid.UUID]:
    """Your entries linked to a live expense or payment in a group you're still in, and refunds
    of those. They're listed but not counted: your share of the expense counts as group
    spending (a refund of it belongs to the group too), and a payment isn't spending. A group
    you've left drops out, as it does from your device."""
    groups = current_groups(user_id)
    via_expense = (
        select(PersonalTransaction.id)
        .join(Expense, Expense.id == PersonalTransaction.expense_id)
        .where(
            PersonalTransaction.user_id == user_id,
            Expense.deleted_at.is_(None),
            Expense.group_id.in_(groups),
        )
    )
    via_payment = (
        select(PersonalTransaction.id)
        .join(Settlement, Settlement.id == PersonalTransaction.settlement_id)
        .where(
            PersonalTransaction.user_id == user_id,
            Settlement.deleted_at.is_(None),
            Settlement.group_id.in_(groups),
        )
    )
    covered = set(session.scalars(via_expense.union(via_payment)))
    if covered:
        refunds = select(PersonalTransaction.id).where(
            PersonalTransaction.user_id == user_id, PersonalTransaction.refund_of_id.in_(covered)
        )
        covered |= set(session.scalars(refunds))
    return covered
