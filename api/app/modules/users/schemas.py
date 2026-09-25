import uuid
from datetime import datetime

from pydantic import Field

from app.core.schemas import Schema


class UserOut(Schema):
    id: uuid.UUID
    name: str
    email: str | None
    avatar_url: str | None
    currency: str
    role: str
    created_at: datetime
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class UserBrief(Schema):
    """A person as shown inside groups, splits and balances."""

    id: uuid.UUID
    name: str
    avatar_url: str | None
    is_placeholder: bool = False


class UserUpdate(Schema):
    version: int | None = None
    """The version you edited. If it changed since, the update gets a 409."""
    name: str | None = Field(default=None, min_length=1, max_length=80)
    avatar_url: str | None = None
    currency: str | None = Field(default=None, pattern="^[A-Z]{3}$")


def brief(user) -> UserBrief:
    return UserBrief(
        id=user.id, name=user.name, avatar_url=user.avatar_url, is_placeholder=user.email is None
    )
