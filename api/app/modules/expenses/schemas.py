import uuid
from datetime import date, datetime
from typing import Any, Literal

from pydantic import Field

from app.core.schemas import DecimalStr, Schema
from app.modules.categories.schemas import CategoryOut
from app.modules.splits.schemas import SplitIn
from app.modules.users.schemas import UserBrief


class ExpenseIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    description: str = Field(min_length=1, max_length=200)
    amount_minor: int = Field(gt=0)
    payer_id: uuid.UUID
    date: date
    category_id: uuid.UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)
    split: SplitIn


class SplitOut(Schema):
    user: UserBrief
    share_minor: int
    input_value: DecimalStr | None
    status: Literal["paid", "owes", "settled"]
    """paid: the payer. owes: still owes the payer in this group. settled: square with the
    payer in this group (by payments or other expenses)."""


class ExpenseOut(Schema):
    id: uuid.UUID
    group_id: uuid.UUID
    description: str
    amount_minor: int
    currency: str
    payer: UserBrief
    date: date
    category: CategoryOut | None
    notes: str | None
    split_method: str
    splits: list[SplitOut]
    my_share_minor: int
    my_net_minor: int
    """What this expense did to your balance. Positive: others owe you. Negative: you owe."""
    created_by: UserBrief
    acting_admin_id: uuid.UUID | None
    """Set when the last write was made by an admin acting as a user; show the Admin badge."""
    import_batch_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class HistoryEntry(Schema):
    action: str
    """expense.create, expense.update, expense.delete or expense.restore."""
    person: UserBrief | None
    """Who it was done as. None for the Tricount importer."""
    admin: UserBrief | None
    """Set when an admin made the change while viewing as `person`."""
    at: datetime
    diff: dict[str, Any]
