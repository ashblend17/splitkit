import uuid

from fastapi import APIRouter, BackgroundTasks, Response

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.tricount_sync import service
from app.modules.tricount_sync.schemas import (
    ResolveConflictIn,
    TricountConflictOut,
    TricountLinkIn,
    TricountLinkPreviewIn,
    TricountLinkPreviewOut,
    TricountStatusOut,
)

router = APIRouter(tags=["tricount"])


@router.get("/groups/{group_id}/tricount", response_model=TricountStatusOut)
def get_tricount_link(group_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Whether the group is kept in sync with a tricount, how the last pass went, and the
    conflicts waiting for someone to pick a side."""
    return service.status(session, actor, group_id)


@router.post("/groups/{group_id}/tricount/preview", response_model=TricountLinkPreviewOut)
def preview_tricount_link(
    group_id: uuid.UUID, body: TricountLinkPreviewIn, actor: CurrentActor, session: DbSession
):
    """Read a tricount by its share link (without joining it) and suggest who its people are
    in this group. Changes nothing."""
    return service.preview(session, actor, group_id, body.link)


@router.post("/groups/{group_id}/tricount", response_model=TricountStatusOut, status_code=201)
def link_tricount(
    group_id: uuid.UUID,
    body: TricountLinkIn,
    actor: CurrentActor,
    session: DbSession,
    background: BackgroundTasks,
):
    """Keep this group in sync with a tricount: an existing one (`link`) or a new one made
    from the group (`create`). The first pass runs right after; the status says "syncing"
    until it's done."""
    out = service.link(session, actor, group_id, body)
    background.add_task(service.run_in_background, group_id)
    return out


@router.post("/groups/{group_id}/tricount/sync", response_model=TricountStatusOut)
def sync_tricount(group_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Sync now instead of waiting for the next pass."""
    return service.sync_now(session, actor, group_id)


@router.delete("/groups/{group_id}/tricount", status_code=204)
def unlink_tricount(group_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Stop syncing. Nothing is deleted on either side."""
    service.unlink(session, actor, group_id)
    return Response(status_code=204)


@router.get("/tricount/conflicts", response_model=list[TricountConflictOut])
def list_tricount_conflicts(actor: CurrentActor, session: DbSession):
    """Entries changed in both apps since they last agreed, in your groups."""
    return service.conflicts(session, actor)


@router.post("/tricount/conflicts/{conflict_id}/resolve", response_model=TricountStatusOut)
def resolve_tricount_conflict(
    conflict_id: uuid.UUID, body: ResolveConflictIn, actor: CurrentActor, session: DbSession
):
    """Keep the app's or Tricount's version. The other app is updated before this returns
    (unless Tricount can't be reached; then the worker retries)."""
    return service.resolve(session, actor, conflict_id, body.keep)[1]
