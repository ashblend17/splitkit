"""Who is making this request. Every route that needs a user depends on `CurrentActor`."""

import uuid
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.db import get_session
from app.core.errors import ApiError
from app.modules.auth.tokens import decode_access_token
from app.modules.users.models import User

_bearer = HTTPBearer(auto_error=False)

DbSession = Annotated[Session, Depends(get_session)]


@dataclass(frozen=True)
class Actor:
    """The effective user, plus the admin acting as them (admin impersonation, build step 8).

    Writes store `admin_id` as acting_admin_id. `read_only` blocks writes entirely.
    """

    user: User
    admin_id: uuid.UUID | None = None
    read_only: bool = False

    @property
    def user_id(self) -> uuid.UUID:
        return self.user.id

    def require_write(self) -> None:
        if self.read_only:
            raise ApiError(403, "read_only", "You are viewing as this user in read-only mode")


def get_actor(
    session: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> Actor:
    user_id = decode_access_token(credentials.credentials) if credentials else None
    user = session.get(User, user_id) if user_id else None
    if user is None or user.email is None:
        raise ApiError(401, "unauthenticated", "Please log in again")
    return Actor(user=user)


CurrentActor = Annotated[Actor, Depends(get_actor)]
