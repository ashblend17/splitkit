import uuid

from fastapi import APIRouter

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.expenses import service
from app.modules.expenses.schemas import ExpenseIn, ExpenseOut, HistoryEntry

router = APIRouter(tags=["expenses"])


@router.post("/groups/{group_id}/expenses", response_model=ExpenseOut, status_code=201)
def create_expense(group_id: uuid.UUID, body: ExpenseIn, actor: CurrentActor, session: DbSession):
    return service.create_expense(session, actor, group_id, body)


@router.get("/expenses/{expense_id}", response_model=ExpenseOut)
def get_expense(expense_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.get_expense(session, actor, expense_id)


@router.put("/expenses/{expense_id}", response_model=ExpenseOut)
def update_expense(expense_id: uuid.UUID, body: ExpenseIn, actor: CurrentActor, session: DbSession):
    return service.update_expense(session, actor, expense_id, body)


@router.delete("/expenses/{expense_id}", response_model=ExpenseOut)
def delete_expense(
    expense_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    """Soft delete. The expense stops counting towards balances and can be restored."""
    return service.set_deleted(session, actor, expense_id, deleted=True, version=version)


@router.post("/expenses/{expense_id}/restore", response_model=ExpenseOut)
def restore_expense(
    expense_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, expense_id, deleted=False, version=version)


@router.get("/expenses/{expense_id}/history", response_model=list[HistoryEntry])
def expense_history(expense_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Who added and changed this expense, oldest first ("Edited by Rahul · ₹1,650 → ₹1,800")."""
    return service.expense_history(session, actor, expense_id)
