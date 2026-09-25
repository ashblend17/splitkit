import uuid
from typing import Literal

from pydantic import Field

from app.core.schemas import Schema


class CategoryOut(Schema):
    id: uuid.UUID
    key: str
    label: str
    icon: str
    scope: str
    owner_id: uuid.UUID | None = None
    """None for built-in categories; yours when you added it."""


class CategoryIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    label: str = Field(min_length=1, max_length=40)
    icon: str = Field(default="other", min_length=1, max_length=40)
    scope: Literal["group", "personal", "all"] = "all"
