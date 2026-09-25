import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import Field

from app.core.schemas import Schema
from app.modules.categories.schemas import CategoryOut

TxnType = Literal["income", "expense"]


class PersonalTxnIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    type: TxnType
    amount_minor: int = Field(gt=0)
    description: str = Field(min_length=1, max_length=200)
    date: date
    category_id: uuid.UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)


class PersonalTxnOut(Schema):
    id: uuid.UUID
    type: TxnType
    amount_minor: int
    currency: str
    description: str
    date: date
    category: CategoryOut | None
    notes: str | None
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    deleted_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class PersonalListOut(Schema):
    items: list[PersonalTxnOut]
    """Newest first."""
    spent_minor: int
    """Sum of expenses in the filtered set."""
    income_minor: int
    count: int


class CategoryTotal(Schema):
    category: CategoryOut | None
    label: str
    amount_minor: int


class PersonalSummaryOut(Schema):
    month: str
    """YYYY-MM"""
    month_label: str
    """"September", or "September 2025" outside the current year."""
    currency: str
    spent_minor: int
    income_minor: int
    left_over_minor: int
    """Income minus spending. Negative when you spent more than came in."""
    group_share_minor: int
    """Your share of group expenses dated in this month."""
    by_category: list[CategoryTotal]
    """Spending by category, largest first."""
