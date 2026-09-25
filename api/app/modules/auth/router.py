from fastapi import APIRouter

from app.modules.auth import service
from app.modules.auth.deps import DbSession
from app.modules.auth.schemas import LoginIn, RegisterIn, TokenOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, session: DbSession):
    return service.register(session, body)


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, session: DbSession):
    return service.login(session, body)
