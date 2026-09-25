import uuid

from sqlalchemy import delete, select
from sqlalchemy.orm import Session, selectinload

from app.modules.admin.models import AuditLog
from app.modules.expenses.models import Expense, ExpenseSplit


def get(session: Session, expense_id: uuid.UUID) -> Expense | None:
    return session.scalar(
        select(Expense).where(Expense.id == expense_id).options(selectinload(Expense.splits))
    )


def replace_splits(session: Session, expense: Expense, splits: list[ExpenseSplit]) -> None:
    session.execute(delete(ExpenseSplit).where(ExpenseSplit.expense_id == expense.id))
    session.expire(expense, ["splits"])
    for s in splits:
        s.expense_id = expense.id
        session.add(s)


def history(session: Session, expense_id: uuid.UUID) -> list[AuditLog]:
    return list(
        session.scalars(
            select(AuditLog)
            .where(AuditLog.entity == "expense", AuditLog.entity_id == expense_id)
            .order_by(AuditLog.at)
        )
    )
