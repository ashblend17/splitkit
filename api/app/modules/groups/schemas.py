import uuid
from datetime import datetime
from typing import Literal

from pydantic import EmailStr, Field, model_validator

from app.core.schemas import Schema
from app.modules.users.schemas import UserBrief

Icon = Literal[
    "groups", "travel", "rent", "food", "home", "shopping", "entertainment", "education", "other"
]


class GroupIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    name: str = Field(min_length=1, max_length=80)
    icon: Icon = "groups"
    currency: Literal["INR", "USD", "EUR"] = "INR"


class GroupUpdate(Schema):
    version: int | None = None
    """The version you edited. If it changed since, the update gets a 409."""
    name: str | None = Field(default=None, min_length=1, max_length=80)
    icon: Icon | None = None
    archived: bool | None = None


class MemberOut(Schema):
    user: UserBrief
    role: str
    joined_at: datetime
    placeholder_name: str | None


class GroupOut(Schema):
    id: uuid.UUID
    name: str
    icon: str
    currency: str
    created_at: datetime
    archived_at: datetime | None
    members: list[MemberOut]
    """Current members, in the order they joined."""
    total_spent_minor: int
    my_net_minor: int
    """Your overall position in this group. Positive: you are owed. Negative: you owe."""
    last_activity_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class AddMemberIn(Schema):
    """Add an existing account by email, or a placeholder person by name (no account)."""

    email: EmailStr | None = None
    name: str | None = Field(default=None, min_length=1, max_length=80)

    @model_validator(mode="after")
    def _exactly_one(self):
        if (self.email is None) == (self.name is None):
            raise ValueError("Give either an email or a name")
        return self
