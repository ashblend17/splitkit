from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.events import record
from app.core.security import hash_password, verify_password
from app.modules.auth.deps import Actor
from app.modules.auth.schemas import LoginIn, RegisterIn, TokenOut
from app.modules.auth.tokens import create_access_token
from app.modules.users import repository as users
from app.modules.users.models import User
from app.modules.users.schemas import UserOut


def _token_for(user: User) -> TokenOut:
    token, expires_in = create_access_token(user.id)
    return TokenOut(access_token=token, expires_in=expires_in, user=UserOut.model_validate(user))


def register(session: Session, body: RegisterIn) -> TokenOut:
    email = body.email.lower()
    if users.get_by_email(session, email):
        raise ApiError(409, "email_taken", "An account with this email already exists")
    user = User(
        name=body.name.strip(),
        email=email,
        password_hash=hash_password(body.password),
        currency=body.currency,
    )
    session.add(user)
    session.flush()
    record(session, Actor(user=user), "user.register", "user", user.id, obj=user)
    session.commit()
    return _token_for(user)


def login(session: Session, body: LoginIn) -> TokenOut:
    user = users.get_by_email(session, body.email)
    if (
        user is None
        or not user.password_hash
        or not verify_password(user.password_hash, body.password)
    ):
        raise ApiError(401, "bad_credentials", "That email and password don't match")
    return _token_for(user)
