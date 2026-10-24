import uuid
from datetime import datetime
from typing import Literal

from pydantic import Field

from app.core.schemas import Schema, Text
from app.modules.users.schemas import UserBrief


class TricountLinkPreviewIn(Schema):
    link: Text(300)
    """A share link (https://tricount.com/tXXXX) or just its tXXXX part."""


class TricountPersonOut(Schema):
    member_uuid: str
    name: str
    suggested: UserBrief | None
    """The group member this probably is, or None to add them as a new person."""
    state: Literal["you", "matched", "suggested", "unmatched"]


class TricountLinkPreviewOut(Schema):
    title: str
    currency: str
    expenses: int
    payments: int
    unsupported: int
    """Entries the app can't hold (income, …). They stay in Tricount only."""
    people: list[TricountPersonOut]
    problem: str | None
    """Why this tricount can't be linked to the group (a different currency), or None."""


class TricountPersonIn(Schema):
    member_uuid: str = Field(min_length=1, max_length=64)
    user_id: uuid.UUID | None = None
    """A current member of the group, or None to add the Tricount person as a new one."""


class TricountLinkIn(Schema):
    link: Text(300) | None = None
    """The tricount to keep in sync with. Leave out with `create` to make a new one."""
    create: bool = False
    """Make a new tricount from this group (named after it, in its currency)."""
    people: list[TricountPersonIn] = Field(default_factory=list, max_length=200)
    """Who each Tricount member is. Anyone left out is matched by name, or added."""


class ConflictSideOut(Schema):
    title: str
    summary: str
    """"₹1,800 · paid by Rahul · 23 Sep", or "Deleted"."""
    deleted: bool


class TricountConflictOut(Schema):
    id: uuid.UUID
    group_id: uuid.UUID
    group_name: str
    entity: Literal["expense", "payment"]
    local: ConflictSideOut
    """This app's version."""
    tricount: ConflictSideOut
    created_at: datetime


class ResolveConflictIn(Schema):
    keep: Literal["local", "tricount"]
    """This app's version, or Tricount's."""


class TricountLinkOut(Schema):
    group_id: uuid.UUID
    share_link: str
    state: Literal["syncing", "ok", "error"]
    """syncing: the first pass hasn't finished. error: see `last_error`; it retries by itself."""
    last_error: str | None
    warnings: list[str]
    last_synced_at: datetime | None
    linked_at: datetime
    linked_by: UserBrief
    conflicts: list[TricountConflictOut]


class TricountStatusOut(Schema):
    linked: bool
    link: TricountLinkOut | None
