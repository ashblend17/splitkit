import uuid
from datetime import date, datetime
from typing import Literal

from app.core.schemas import Schema
from app.modules.categories.schemas import CategoryOut
from app.modules.users.schemas import UserBrief


class PersonBalance(Schema):
    user: UserBrief
    net_minor: int
    """Positive: they owe you (or, in `members`, they are owed overall). Negative: the reverse."""


class SuggestedPayment(Schema):
    from_user: UserBrief
    to_user: UserBrief
    amount_minor: int


class GroupBalancesOut(Schema):
    group_id: uuid.UUID
    currency: str
    net_minor: int
    you_owe_minor: int
    you_are_owed_minor: int
    people: list[PersonBalance]
    """Your pairwise balance with each other member: "You owe Rahul ₹500"."""
    members: list[PersonBalance]
    """Everyone's overall position in the group. Sums to zero."""
    suggested: list[SuggestedPayment]
    """Fewest payments that would settle the whole group (debts simplified)."""


class CurrencyTotals(Schema):
    currency: str
    net_minor: int
    you_owe_minor: int
    you_are_owed_minor: int


class FriendBalance(Schema):
    user: UserBrief
    currency: str
    net_minor: int
    """Summed across every group you share. Positive: they owe you."""


class GroupNet(Schema):
    group_id: uuid.UUID
    name: str
    currency: str
    net_minor: int


class OverallBalancesOut(Schema):
    totals: list[CurrencyTotals]
    friends: list[FriendBalance]
    groups: list[GroupNet]


class FeedItem(Schema):
    kind: Literal["expense", "settlement"]
    id: uuid.UUID
    group_id: uuid.UUID
    group_name: str
    title: str | None
    """Expense description. None for settlements: the client writes "You paid Rahul"."""
    date: date
    created_at: datetime
    amount_minor: int
    currency: str
    category: CategoryOut | None
    payer: UserBrief
    """Expense payer, or the person who paid in a settlement."""
    to_user: UserBrief | None
    """Settlements only: who received the money."""
    method: str
    """Split method for expenses; payment method (upi, cash…) for settlements."""
    participant_count: int
    my_share_minor: int
    my_net_minor: int
    """Effect on your balance. Positive: you are owed more / owe less."""
    settled: bool
    """Expenses you didn't pay for: you are square with the payer in this group now."""
    by_admin: bool
    deleted_at: datetime | None
