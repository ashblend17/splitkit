import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import Field

from app.core.schemas import AmountMinor, EntryDate, Schema, Text
from app.modules.categories.schemas import CategoryOut

TxnType = Literal["income", "expense"]
Channel = Literal["upi", "card", "bank", "atm", "cash", "other"]
"""How it was paid. `bank` is a transfer (NEFT, IMPS, net banking)."""
Source = Literal["manual", "sms"]

MAX_BALANCE_MINOR = 10**15


class PersonalTxnIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    type: TxnType
    amount_minor: AmountMinor
    description: Text(200)
    date: EntryDate
    category_id: uuid.UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)
    # Editable. On an update, a field you leave out keeps its value (older apps don't send them).
    channel: Channel | None = None
    merchant: str | None = Field(default=None, max_length=120)
    """Who was paid, or paid you, as the bank named them."""
    account: str | None = Field(default=None, max_length=60)
    """The account or card, as the app labels it ("HDFC ··4821")."""
    expense_id: uuid.UUID | None = None
    """The group expense this was split into: one you paid, in a group you're in. While it's
    live the entry isn't counted in your totals (your share is, as group spending)."""
    settlement_id: uuid.UUID | None = None
    """The payment to (for an expense) or from (for income) a friend this was. Not counted as
    spending or income while the payment is live. Not both links at once."""
    reviewed: bool = True
    """False for an entry the app added from a bank SMS that you haven't looked at yet."""
    # Create only: where the entry came from. Ignored on an update.
    source: Source = "manual"
    reference: str | None = Field(default=None, max_length=64)
    """The bank's reference (UPI ref, RRN)."""
    balance_minor: int | None = Field(default=None, ge=-MAX_BALANCE_MINOR, le=MAX_BALANCE_MINOR)
    """The account balance the bank reported after this."""
    sms_at: datetime | None = None
    """When the bank's SMS arrived."""


class PersonalBatchIn(Schema):
    items: list[PersonalTxnIn] = Field(min_length=1, max_length=100)
    """Made in order, all or none. Each may carry its own `id`."""


class PersonalTxnOut(Schema):
    id: uuid.UUID
    type: TxnType
    amount_minor: int
    currency: str
    description: str
    date: date
    category: CategoryOut | None
    notes: str | None
    channel: Channel | None
    merchant: str | None
    account: str | None
    source: Source
    reference: str | None
    balance_minor: int | None
    sms_at: datetime | None
    reviewed: bool
    expense_id: uuid.UUID | None
    settlement_id: uuid.UUID | None
    counted: bool
    """False while the entry is linked to a live group expense or payment in a group you're in:
    it's listed, but left out of every total."""
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    deleted_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class PersonalListOut(Schema):
    items: list[PersonalTxnOut]
    """Newest first."""
    spent_minor: int
    """Sum of expenses in the filtered set, in your currency (entries in another, and entries
    that aren't `counted`, are left out)."""
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
    """Your share of group expenses dated in this month, in groups that use your currency."""
    by_category: list[CategoryTotal]
    """Spending by category, largest first."""


class AccountOut(Schema):
    account: str
    """As the app labels it: "HDFC ··4821", "ICICI Credit card ··9012"."""
    currency: str
    balance_minor: int | None
    """The latest balance the bank reported, or null if it never did (cards report a limit)."""
    balance_at: datetime | None
    """When the bank reported it."""
    count: int
    """Entries through this account."""


class PersonalBatchOut(Schema):
    items: list[PersonalTxnOut]
    """In the order sent."""
