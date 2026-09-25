import uuid
from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Query

from app.modules.admin import service
from app.modules.admin.schemas import (
    AdminDashboardOut,
    AdminSessionIn,
    AdminSessionOut,
    AdminSessionsPageOut,
    AdminSessionStartOut,
    AdminSessionUpdate,
    AdminUsersPageOut,
    AuditPageOut,
)
from app.modules.auth.deps import CurrentActor, CurrentAdmin, DbSession

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/dashboard", response_model=AdminDashboardOut)
def admin_dashboard(_: CurrentAdmin, session: DbSession):
    """Totals, the latest audit entries and system facts for the admin home."""
    return service.dashboard(session)


@router.get("/users", response_model=AdminUsersPageOut)
def list_admin_users(
    _: CurrentAdmin,
    session: DbSession,
    q: str | None = Query(None, max_length=100, description="Name or email"),
    role: Literal["user", "admin"] | None = None,
    include_placeholders: bool = Query(False, description="Also people without an account"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    return service.list_users(session, q, role, include_placeholders, limit, offset)


@router.post("/sessions", response_model=AdminSessionStartOut, status_code=201)
def start_admin_session(body: AdminSessionIn, admin: CurrentAdmin, session: DbSession):
    """View the app as a user. Read-only unless `mode` is `edit`. Returns a token for that user;
    ends any other session you have open."""
    return service.start_session(session, admin, body)


@router.get("/sessions", response_model=AdminSessionsPageOut)
def list_admin_sessions(
    _: CurrentAdmin,
    session: DbSession,
    active: bool | None = None,
    admin_id: uuid.UUID | None = None,
    target_user_id: uuid.UUID | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    return service.list_sessions(session, active, admin_id, target_user_id, limit, offset)


@router.patch("/sessions/{session_id}", response_model=AdminSessionOut)
def update_admin_session(
    session_id: uuid.UUID, body: AdminSessionUpdate, admin: CurrentAdmin, session: DbSession
):
    """Switch a session you started between read-only and edit. Takes effect at once, on the
    same token."""
    return service.update_session(session, admin, session_id, body)


@router.post("/sessions/{session_id}/end", response_model=AdminSessionOut)
def end_admin_session(session_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Stop viewing as the user. Works with your admin token or with the view-as token itself;
    the view-as token stops working straight away."""
    return service.end_session(session, actor, session_id)


@router.get("/audit", response_model=AuditPageOut)
def list_audit_log(
    _: CurrentAdmin,
    session: DbSession,
    actor_id: Annotated[uuid.UUID | None, Query(description="Who really acted")] = None,
    target_user_id: Annotated[
        uuid.UUID | None,
        Query(description="Who it was done as: the impersonated user, or the actor"),
    ] = None,
    entity: Annotated[
        list[str] | None,
        Query(description="expense, settlement, group, user, admin_session, import_batch…"),
    ] = None,
    admin_only: bool = Query(False, description="Only things admins did as someone else"),
    start: Annotated[date | None, Query(description="UTC day, included")] = None,
    end: Annotated[date | None, Query(description="UTC day, included")] = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    return service.audit(
        session, actor_id, target_user_id, entity, admin_only, start, end, limit, offset
    )
