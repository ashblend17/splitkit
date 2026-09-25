import uuid

from fastapi import APIRouter, Response

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.groups import service
from app.modules.groups.schemas import AddMemberIn, GroupIn, GroupOut, GroupUpdate

router = APIRouter(prefix="/groups", tags=["groups"])


@router.get("", response_model=list[GroupOut])
def list_groups(actor: CurrentActor, session: DbSession, archived: bool = False):
    return service.list_groups(session, actor, archived)


@router.post("", response_model=GroupOut, status_code=201)
def create_group(body: GroupIn, actor: CurrentActor, session: DbSession):
    return service.create_group(session, actor, body)


@router.get("/{group_id}", response_model=GroupOut)
def get_group(group_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.get_group(session, actor, group_id)


@router.patch("/{group_id}", response_model=GroupOut)
def update_group(group_id: uuid.UUID, body: GroupUpdate, actor: CurrentActor, session: DbSession):
    return service.update_group(session, actor, group_id, body)


@router.post("/{group_id}/members", response_model=GroupOut, status_code=201)
def add_member(group_id: uuid.UUID, body: AddMemberIn, actor: CurrentActor, session: DbSession):
    return service.add_member(session, actor, group_id, body)


@router.delete("/{group_id}/members/{user_id}", status_code=204)
def remove_member(group_id: uuid.UUID, user_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    service.remove_member(session, actor, group_id, user_id)
    return Response(status_code=204)
