import uuid
from datetime import date
from typing import Literal

from fastapi import APIRouter

from app.modules.analytics import service
from app.modules.analytics.periods import Period
from app.modules.analytics.schemas import DashboardOut, LayoutIn, LayoutOut
from app.modules.auth.deps import CurrentActor, DbSession

router = APIRouter(prefix="/analytics", tags=["analytics"])

Scope = Literal["personal", "group"]


@router.get("/personal", response_model=DashboardOut)
def personal_dashboard(
    actor: CurrentActor, session: DbSession, period: Period = "month", on: date | None = None
):
    """One card per row of your analytics layout. `on` is today in your time zone."""
    return service.personal_dashboard(session, actor, period, on or date.today())


@router.get("/groups/{group_id}", response_model=DashboardOut)
def group_dashboard(
    group_id: uuid.UUID, actor: CurrentActor, session: DbSession, on: date | None = None
):
    return service.group_dashboard(session, actor, group_id, on or date.today())


@router.get("/layout/{scope}", response_model=LayoutOut)
def get_layout(scope: Scope, actor: CurrentActor, session: DbSession):
    return service.get_layout(session, actor, scope)


@router.put("/layout/{scope}", response_model=LayoutOut)
def save_layout(scope: Scope, body: LayoutIn, actor: CurrentActor, session: DbSession):
    """Replace your layout for this scope (order = list order)."""
    actor.require_write()
    return service.save_layout(session, actor, scope, body)


@router.delete("/layout/{scope}", response_model=LayoutOut)
def reset_layout(scope: Scope, actor: CurrentActor, session: DbSession):
    """Go back to the default layout."""
    actor.require_write()
    return service.reset_layout(session, actor, scope)
