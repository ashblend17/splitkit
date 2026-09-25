import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import Field

from app.core.schemas import Schema
from app.modules.users.schemas import UserBrief

Method = Literal["upi", "cash", "bank", "other"]


class SettlementIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    from_user: uuid.UUID
    """Who paid."""
    to_user: uuid.UUID
    """Who received the money."""
    amount_minor: int = Field(gt=0)
    date: date
    method: Method = "upi"
    note: str | None = Field(default=None, max_length=500)


class SettlementOut(Schema):
    id: uuid.UUID
    group_id: uuid.UUID
    from_user: UserBrief
    to_user: UserBrief
    amount_minor: int
    currency: str
    date: date
    method: Method
    note: str | None
    created_by: UserBrief
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    deleted_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class FriendGroupBalance(Schema):
    group_id: uuid.UUID
    name: str
    net_minor: int
    """Positive: they owe you in this group. Negative: you owe them."""


class SettleUpPlanOut(Schema):
    friend: UserBrief
    currency: str
    net_minor: int
    """Across every group you share. Positive: they owe you."""
    groups: list[FriendGroupBalance]
    """Groups with a balance, in the order a part payment pays them down (oldest first)."""


class SettleUpIn(Schema):
    amount_minor: int | None = Field(default=None, gt=0)
    """Omit to settle everything. Otherwise a part payment in the direction of the net."""
    date: date
    method: Method = "upi"
    note: str | None = Field(default=None, max_length=500)
    currency: str | None = Field(default=None, pattern="^[A-Z]{3}$")
    """Defaults to your own currency; only groups in this currency are settled."""


class SettleUpOut(Schema):
    settlements: list[SettlementOut]
    """One per group touched."""
    remaining_net_minor: int
