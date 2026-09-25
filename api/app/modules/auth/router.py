from fastapi import APIRouter

from app.core.errors import ApiError
from app.modules.auth import service
from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.auth.schemas import LoginIn, RegisterIn, TokenOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, session: DbSession):
    return service.register(session, body)


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, session: DbSession):
    return service.login(session, body)


@router.post("/refresh", response_model=TokenOut)
def refresh(actor: CurrentActor):
    """A fresh token for a signed-in user, so people who open the app at least once a week stay
    signed in. View-as tokens can't be refreshed: they end with their admin session."""
    if actor.admin_id is not None:
        raise ApiError(403, "cannot_refresh", "View-as sessions can't be extended")
    return service.token_for(actor.user)
