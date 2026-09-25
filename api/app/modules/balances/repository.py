import uuid
from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.balances.engine import Flow, expense_flows, settlement_flow
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.settlements.models import Settlement


def flows_by_group(
    session: Session, group_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[Flow[uuid.UUID]]]:
    """Every live (not deleted) expense split and settlement in these groups, as flows."""
    flows: dict[uuid.UUID, list[Flow[uuid.UUID]]] = defaultdict(list)
    if not group_ids:
        return flows
    splits = session.execute(
        select(
            Expense.id,
            Expense.group_id,
            Expense.payer_id,
            ExpenseSplit.user_id,
            ExpenseSplit.share_minor,
        )
        .join(ExpenseSplit, ExpenseSplit.expense_id == Expense.id)
        .where(Expense.group_id.in_(group_ids), Expense.deleted_at.is_(None))
        .order_by(Expense.id)
    )
    by_expense: dict[uuid.UUID, tuple[uuid.UUID, uuid.UUID, list]] = {}
    for expense_id, group_id, payer_id, user_id, share in splits:
        by_expense.setdefault(expense_id, (group_id, payer_id, []))[2].append((user_id, share))
    for group_id, payer_id, shares in by_expense.values():
        flows[group_id] += expense_flows(payer_id, shares)

    settlements = session.execute(
        select(
            Settlement.group_id, Settlement.from_user, Settlement.to_user, Settlement.amount_minor
        ).where(Settlement.group_id.in_(group_ids), Settlement.deleted_at.is_(None))
    )
    for group_id, from_user, to_user, amount in settlements:
        flows[group_id].append(settlement_flow(from_user, to_user, amount))
    return flows
