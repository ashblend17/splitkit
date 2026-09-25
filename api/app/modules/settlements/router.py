import uuid

from fastapi import APIRouter

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.settlements import service
from app.modules.settlements.schemas import (
    SettlementIn,
    SettlementOut,
    SettleUpIn,
    SettleUpOut,
    SettleUpPlanOut,
)

router = APIRouter(tags=["settlements"])


@router.get("/groups/{group_id}/settlements", response_model=list[SettlementOut])
def list_settlements(group_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.list_settlements(session, actor, group_id)


@router.post("/groups/{group_id}/settlements", response_model=SettlementOut, status_code=201)
def create_settlement(
    group_id: uuid.UUID, body: SettlementIn, actor: CurrentActor, session: DbSession
):
    """Record a payment between two members. It never changes any expense."""
    return service.create_settlement(session, actor, group_id, body)


@router.get("/settlements/{settlement_id}", response_model=SettlementOut)
def get_settlement(settlement_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.get_settlement(session, actor, settlement_id)


@router.delete("/settlements/{settlement_id}", response_model=SettlementOut)
def delete_settlement(
    settlement_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, settlement_id, deleted=True, version=version)


@router.post("/settlements/{settlement_id}/restore", response_model=SettlementOut)
def restore_settlement(
    settlement_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, settlement_id, deleted=False, version=version)


@router.get("/friends/{user_id}/settle-up", response_model=SettleUpPlanOut)
def settle_up_plan(
    user_id: uuid.UUID, actor: CurrentActor, session: DbSession, currency: str | None = None
):
    """Your balance with a friend in each group you share, for the "Settle up" sheet."""
    return service.settle_up_plan(session, actor, user_id, currency)


@router.post("/friends/{user_id}/settle-up", response_model=SettleUpOut, status_code=201)
def settle_up(user_id: uuid.UUID, body: SettleUpIn, actor: CurrentActor, session: DbSession):
    """Settle with a friend across groups: one settlement per group, saved together.

    Without `amount_minor` every shared group ends at zero. With it, the payment pays down
    the groups owed in its direction, oldest first.
    """
    return service.settle_up(session, actor, user_id, body)
