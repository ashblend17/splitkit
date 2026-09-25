from fastapi import APIRouter

from app.core.events import record
from app.core.versioning import check_version
from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.users.schemas import UserOut, UserUpdate

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserOut)
def get_me(actor: CurrentActor):
    return actor.user


@router.patch("/me", response_model=UserOut)
def update_me(body: UserUpdate, actor: CurrentActor, session: DbSession):
    actor.require_write()
    user = actor.user
    check_version(user, body.version)
    changes = body.model_dump(exclude_unset=True, exclude={"version"})
    diff = {
        k: {"from": getattr(user, k), "to": v} for k, v in changes.items() if getattr(user, k) != v
    }
    for key, value in changes.items():
        setattr(user, key, value)
    if diff:
        record(session, actor, "user.update", "user", user.id, diff=diff, obj=user)
    session.commit()
    return user
