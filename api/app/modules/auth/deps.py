"""Who is making this request. Every route that needs a user depends on `CurrentActor`."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.db import get_session
from app.core.errors import ApiError
from app.modules.admin.models import AdminSession
from app.modules.auth.tokens import decode_claims
from app.modules.users.models import User

_bearer = HTTPBearer(auto_error=False)

DbSession = Annotated[Session, Depends(get_session)]

READ_METHODS = {"GET", "HEAD", "OPTIONS"}
READ_ONLY_POSTS = {"sync", "preview", "end_admin_session"}
"""Route names (operationIds) that use POST but change nothing a read-only admin must not
change: pulling the sync log, previewing a split, and leaving the view-as session."""


@dataclass(frozen=True)
class Actor:
    """The effective user, plus the admin acting as them (admin impersonation).

    Writes store `admin_id` as acting_admin_id. `read_only` blocks writes entirely.
    """

    user: User
    admin_id: uuid.UUID | None = None
    read_only: bool = False
    session_id: uuid.UUID | None = None
    """The admin session behind a view-as token."""

    @property
    def user_id(self) -> uuid.UUID:
        return self.user.id

    def require_write(self) -> None:
        if self.read_only:
            raise ApiError(403, "read_only", "You are viewing as this user in read-only mode")


def _unauthenticated() -> ApiError:
    return ApiError(401, "unauthenticated", "Please log in again")


def _impersonation(session: Session, claims: dict[str, Any], user: User) -> Actor:
    """Resolve a view-as token. Its session must still be open and match the token."""
    try:
        session_id, admin_id = uuid.UUID(claims["sid"]), uuid.UUID(claims["adm"])
    except (KeyError, ValueError, TypeError):
        raise _unauthenticated() from None
    row = session.get(AdminSession, session_id)
    if row is None or row.admin_id != admin_id or row.target_user_id != user.id:
        raise _unauthenticated()
    expired = row.expires_at is not None and row.expires_at <= datetime.now(UTC)
    admin = session.get(User, admin_id)
    if row.ended_at is not None or expired or admin is None or admin.role != "admin":
        raise ApiError(401, "admin_session_ended", "This view-as session has ended")
    return Actor(user=user, admin_id=admin_id, read_only=row.mode == "read_only", session_id=row.id)


def get_actor(
    request: Request,
    session: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> Actor:
    claims = decode_claims(credentials.credentials) if credentials else None
    user = session.get(User, uuid.UUID(claims["sub"])) if claims else None
    if user is None or user.email is None:
        raise _unauthenticated()
    if "sid" not in claims:
        return Actor(user=user)
    actor = _impersonation(session, claims, user)
    # Read-only is enforced here for every write route, before the body is validated, and again
    # by require_write() in the services and in record(). A new write route is covered without
    # anyone remembering to add a check.
    route_name = getattr(request.scope.get("route"), "name", None)
    if request.method not in READ_METHODS and route_name not in READ_ONLY_POSTS:
        actor.require_write()
    return actor


CurrentActor = Annotated[Actor, Depends(get_actor)]


def get_admin(actor: CurrentActor) -> Actor:
    """An admin signed in as themselves. A view-as token belongs to the target user, so it
    never reaches admin routes (except ending its own session, see the admin router)."""
    if actor.user.role != "admin" or actor.admin_id is not None:
        raise ApiError(403, "not_admin", "Only admins can open this")
    return actor


CurrentAdmin = Annotated[Actor, Depends(get_admin)]
