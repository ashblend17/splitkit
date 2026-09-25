import uuid
from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Query

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.personal import service
from app.modules.personal.schemas import (
    PersonalListOut,
    PersonalSummaryOut,
    PersonalTxnIn,
    PersonalTxnOut,
)

router = APIRouter(prefix="/personal", tags=["personal"])


@router.get("/transactions", response_model=PersonalListOut)
def list_personal(
    actor: CurrentActor,
    session: DbSession,
    start: date | None = None,
    end: date | None = None,
    type: Literal["income", "expense"] | None = None,
    category: Annotated[list[str] | None, Query(description="Category keys, repeatable")] = None,
    deleted: bool = False,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    """Your own income and spending (only you see these), newest first, with totals."""
    return service.list_transactions(
        session,
        actor,
        start=start,
        end=end,
        type=type,
        category_keys=category,
        deleted=deleted,
        limit=limit,
        offset=offset,
    )


@router.get("/summary", response_model=PersonalSummaryOut)
def personal_summary(actor: CurrentActor, session: DbSession, month: date | None = None):
    """One month at a glance. `month` is any date inside it (default: this month)."""
    return service.summary(session, actor, month or date.today())


@router.post("/transactions", response_model=PersonalTxnOut, status_code=201)
def create_personal(body: PersonalTxnIn, actor: CurrentActor, session: DbSession):
    return service.create_transaction(session, actor, body)


@router.get("/transactions/{txn_id}", response_model=PersonalTxnOut)
def get_personal(txn_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.get_transaction(session, actor, txn_id)


@router.put("/transactions/{txn_id}", response_model=PersonalTxnOut)
def update_personal(
    txn_id: uuid.UUID, body: PersonalTxnIn, actor: CurrentActor, session: DbSession
):
    return service.update_transaction(session, actor, txn_id, body)


@router.delete("/transactions/{txn_id}", response_model=PersonalTxnOut)
def delete_personal(
    txn_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, txn_id, deleted=True, version=version)


@router.post("/transactions/{txn_id}/restore", response_model=PersonalTxnOut)
def restore_personal(
    txn_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, txn_id, deleted=False, version=version)
