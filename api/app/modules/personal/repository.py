import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.categories.models import Category
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.personal.models import PersonalTransaction


def query(
    session: Session,
    user_id: uuid.UUID,
    *,
    start: date | None = None,
    end: date | None = None,
    type: str | None = None,
    category_keys: list[str] | None = None,
    deleted: bool = False,
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


def group_share(session: Session, user_id: uuid.UUID, start: date, end: date) -> int:
    """Your shares of live group expenses dated between start and end (inclusive)."""
    total = session.scalar(
        select(func.coalesce(func.sum(ExpenseSplit.share_minor), 0))
        .join(Expense, Expense.id == ExpenseSplit.expense_id)
        .where(
            ExpenseSplit.user_id == user_id,
            Expense.deleted_at.is_(None),
            Expense.date >= start,
            Expense.date <= end,
        )
    )
    return int(total)
