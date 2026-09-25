import uuid
from datetime import date

from fastapi import APIRouter, Query

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.balances import feed as feed_service
from app.modules.balances import service
from app.modules.balances.schemas import FeedItem, GroupBalancesOut, OverallBalancesOut

router = APIRouter(tags=["balances"])


@router.get("/balances", response_model=OverallBalancesOut)
def overall_balances(actor: CurrentActor, session: DbSession):
    """Home: totals, balance with each friend across groups, and your net in each group."""
    return service.overall_balances(session, actor)


@router.get("/groups/{group_id}/balances", response_model=GroupBalancesOut)
def group_balances(group_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.group_balances(session, actor, group_id)


@router.get("/feed", response_model=list[FeedItem])
def feed(
    actor: CurrentActor,
    session: DbSession,
    group_id: uuid.UUID | None = None,
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    deleted: bool = Query(False, description="Only deleted items, for a restore/trash view"),
    category: str | None = Query(None, description="Category key. Leaves payments out"),
    start: date | None = None,
    end: date | None = None,
    unsettled: bool = Query(
        False, description="Only expenses you are not square on yet. Leaves payments out"
    ),
    q: str | None = Query(
        None, max_length=100, description="Expense description or a person's name"
    ),
):
    """Expenses and payments, newest first, across your groups or within one group."""
    filters = feed_service.FeedFilters(
        category=category,
        start=start,
        end=end,
        open_only=unsettled,
        search=q.strip() if q and q.strip() else None,
    )
    return feed_service.feed(session, actor, group_id, limit, offset, deleted, filters)
