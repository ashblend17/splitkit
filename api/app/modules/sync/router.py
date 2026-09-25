from fastapi import APIRouter

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.sync import service
from app.modules.sync.schemas import SyncIn, SyncOut, SyncSnapshotOut

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("", response_model=SyncOut)
def sync(body: SyncIn, actor: CurrentActor, session: DbSession):
    """Changes after your cursors, for every stream you can see, in one call."""
    return service.sync(session, actor, body)


@router.get("/snapshot/{stream}", response_model=SyncSnapshotOut)
def snapshot(stream: str, actor: CurrentActor, session: DbSession):
    """The current state of one stream and the seq it is at. Replace your copy with it."""
    return service.snapshot(session, actor, stream)
