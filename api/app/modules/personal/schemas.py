import re
import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Annotated, Literal, get_args

from pydantic import AfterValidator, Field, WithJsonSchema, model_validator

from app.core.schemas import AmountMinor, DecimalStr, EntryDate, Schema, Text
from app.modules.categories.schemas import CategoryOut

TxnType = Literal[
    "income",
    "expense",
    "transfer",
    "refund",
    "investment_contribution",
    "investment_withdrawal",
    "adjustment",
]
"""A transfer is one leg of a move between two of your accounts; an adjustment corrects an
account's balance. Neither is income or spending."""
Direction = Literal["in", "out"]
Channel = Literal["upi", "card", "bank", "atm", "cash", "other"]
"""How it was paid. `bank` is a transfer (NEFT, IMPS, net banking)."""
Source = Literal["manual", "sms"]
AccountType = Literal["cash", "bank", "credit_card", "loan", "investment", "other_asset"]
"""credit_card and loan are owed: their balance is what you owe."""
AccountStatus = Literal["active", "closed"]
GoalMode = Literal["contribution", "linked_balance", "manual"]
AllocationKind = Literal["percentage", "fixed"]
HoldingType = Literal["mutual_fund", "stock", "fd", "gold", "other"]
ReminderStatus = Literal["dismissed", "snoozed", "done"]
GoalStatus = Literal["active", "paused", "completed", "archived"]


def _goal_date(day: date) -> date:
    if not date(2000, 1, 1) <= day <= date(2100, 12, 31):
        raise ValueError("Pick a date between 2000 and 2100")
    return day


GoalDate = Annotated[date, AfterValidator(_goal_date)]
"""A goal's target date: in the past (it's overdue) or years ahead."""


def _valuation_date(day: date) -> date:
    if day < date(2000, 1, 1):
        raise ValueError("Pick a date from 2000 onwards")
    if day > date.today() + timedelta(days=1):  # a day of slack for time zones
        raise ValueError("A value can't be from the future")
    return day


ValuationDate = Annotated[date, AfterValidator(_valuation_date)]


def _account_number(value: str | None) -> str | None:
    if value is None:
        return None
    digits = re.sub(r"[\s-]", "", value)
    if not digits:
        return None
    if not re.fullmatch(r"[0-9]{4,20}", digits):
        raise ValueError("An account number is 4 to 20 digits")
    return digits


AccountNumber = Annotated[str | None, AfterValidator(_account_number)]
"""The full number of an account or card, digits only (spaces and dashes are dropped)."""

Quantity = Annotated[
    Decimal,
    # What the database keeps (numeric(18, 6)).
    Field(ge=0, max_digits=18, decimal_places=6),
    WithJsonSchema({"type": "string", "pattern": r"^\d+(\.\d+)?$", "examples": ["412.358"]}),
]
"""Units, shares or grams, sent as a string ("412.358") so nothing is lost to floats."""

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
    account_id: uuid.UUID | None = None
    """The account it moved (yours, not deleted; a closed one only if the entry was already in
    it). Left out by an older app, the account whose `sms_label` is `account` is used."""
    direction: Direction | None = None
    """Money in or out of the account. Required for a transfer leg or an adjustment; for the
    other types it follows from the type (and must match if sent). On an update of a transfer
    or adjustment, null keeps it."""
    transfer_group_id: uuid.UUID | None = None
    """A transfer's two legs (one out, one in, the same amount, two of your accounts) share
    this id and are made or changed together in one `POST /personal/batch`."""
    refund_of_id: uuid.UUID | None = None
    """For a refund: the spend it gives money back for (one of yours, at least as much)."""
    holding_id: uuid.UUID | None = None
    """For an investment or a withdrawal: the holding it bought into or sold from (yours)."""
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
    direction: Direction
    account_id: uuid.UUID | None
    transfer_group_id: uuid.UUID | None
    refund_of_id: uuid.UUID | None
    holding_id: uuid.UUID | None
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
    """Expenses minus refunds in the filtered set, in your currency (entries in another, and
    entries that aren't `counted`, are left out). Negative when refunds were larger."""
    income_minor: int
    refunds_minor: int
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
    """Expenses minus refunds (not your share of group spending, which is separate). Transfers,
    adjustments and investments aren't spending."""
    income_minor: int
    refunds_minor: int
    left_over_minor: int
    """Income minus spending. Negative when you spent more than came in."""
    group_share_minor: int
    """Your share of group expenses dated in this month, in groups that use your currency."""
    by_category: list[CategoryTotal]
    """Spending (expenses minus refunds) by category, largest first, without zeros."""


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


class PersonalAccountIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate. A
    bank SMS account uses the one every phone makes for its label (uuid5 of the user and the
    label), so another phone gets the same account."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    name: Text(60)
    type: AccountType
    opening_balance_minor: int = Field(default=0, ge=-MAX_BALANCE_MINOR, le=MAX_BALANCE_MINOR)
    """What was in it before its first entry (for a card or loan, what you owed). On an update,
    leaving it out keeps it."""
    sms_label: str | None = Field(default=None, max_length=60)
    """Bank SMS entries with this label ("HDFC ··4821") go in this account; one account per
    label, deleted ones included. Setting it moves in your entries with that label that have no
    account yet. On an update, leaving it out keeps it and null clears it."""
    status: AccountStatus | None = None
    """Leave it out to keep it (a new account is active). A closed account takes no new entries
    and still counts in net worth."""
    linked_account_id: uuid.UUID | None = None
    """Another open account of yours, in the same currency, that this one is part of: the same
    account under another bank SMS label, or a debit card on a bank account. Its entries then
    count in that account's balance, as that account's type, and its own opening balance
    doesn't. That account can't be linked itself, nor can an investment account, one a goal
    follows, or one other accounts are linked to. On an update, leaving it out keeps it and
    null unlinks."""
    account_number: AccountNumber = Field(default=None, max_length=30)
    """The full account or card number, 4 to 20 digits (spaces and dashes are dropped). Bank SMS
    show only its last digits; the app puts a message whose label's digits end it in this
    account. On an update, leaving it out keeps it and null or "" clears it."""


class PersonalAccountOut(Schema):
    """No balance: the app derives it from the opening balance and the entries in the account."""

    id: uuid.UUID
    name: str
    type: AccountType
    currency: str
    """Your currency when the account was made. Entries in it are in this currency."""
    opening_balance_minor: int
    sms_label: str | None
    status: AccountStatus
    linked_account_id: uuid.UUID | None
    """The account this one is part of: its entries count in that account's balance."""
    account_number: str | None
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class PersonalGoalIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    name: Text(60)
    target_minor: AmountMinor
    # On an update, a field you leave out keeps its value.
    target_date: GoalDate | None = None
    tracking_mode: GoalMode = "contribution"
    """contribution: progress is the sum of its contributions. linked_balance: the balance of
    `linked_account_id` (an account kept for this goal); it takes no contributions. manual: the
    `manual_progress_minor` you type (for savings outside the app)."""
    linked_account_id: uuid.UUID | None = None
    """Required for linked_balance, and only then: one of your accounts, in your currency."""
    manual_progress_minor: int | None = Field(default=None, ge=0, le=MAX_BALANCE_MINOR)
    """Required for manual, and only then."""
    expected_return_bp: int | None = Field(default=None, ge=0, le=10_000)
    """Expected monthly return in basis points (80 = 0.8%), for an optional estimate."""
    priority: int = Field(default=0, ge=0, le=1000)
    status: GoalStatus | None = None
    """Leave it out to keep it (a new goal is active). An archived goal takes no
    contributions."""


class PersonalGoalOut(Schema):
    """No progress: the app derives it, from the source `tracking_mode` names."""

    id: uuid.UUID
    name: str
    target_minor: int
    currency: str
    target_date: date | None
    tracking_mode: GoalMode
    linked_account_id: uuid.UUID | None
    manual_progress_minor: int | None
    expected_return_bp: int | None
    priority: int
    status: GoalStatus
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int


class PersonalGoalContributionIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    goal_id: uuid.UUID
    """A goal of yours that counts contributions (not archived)."""
    amount_minor: AmountMinor
    date: EntryDate
    # On an update, a field you leave out keeps its value.
    transaction_id: uuid.UUID | None = None
    """The entry that moved this money (a transfer leg, an investment), if any: yours, live, at
    least this amount. An entry counts towards one goal at most, and not when it moves an
    account a goal follows by balance."""
    note: str | None = Field(default=None, max_length=500)


class PersonalGoalContributionOut(Schema):
    id: uuid.UUID
    goal_id: uuid.UUID
    transaction_id: uuid.UUID | None
    amount_minor: int
    currency: str
    date: date
    note: str | None
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    deleted_at: datetime | None
    version: int
    """Send it back when editing or deleting, so a stale edit is refused instead of applied."""


class PersonalAllocationRuleIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    kind: AllocationKind
    percent_bp: int | None = Field(default=None, ge=1, le=100_000)
    """For percentage: basis points of each income (1000 is 10%). Over 100% is allowed: the app
    warns and never rescales."""
    amount_minor: AmountMinor | None = None
    """For fixed: the amount from each income."""
    # On an update, a field you leave out keeps its value.
    name: str | None = Field(default=None, max_length=60)
    trigger: Literal["income_recorded"] = "income_recorded"
    source_category_id: uuid.UUID | None = None
    """Only incomes in this category."""
    source_account_id: uuid.UUID | None = None
    """Only incomes into this account."""
    goal_id: uuid.UUID | None = None
    """Where the money goes: a goal that counts contributions (not archived), or `account_id`,
    an open account of yours. Exactly one; on an update, giving one replaces the other."""
    account_id: uuid.UUID | None = None
    active: bool = True
    """Inactive rules make no new plans."""
    priority: int = Field(default=0, ge=0, le=1000)


class PersonalAllocationRuleOut(Schema):
    id: uuid.UUID
    name: str | None
    trigger: Literal["income_recorded"]
    source_category_id: uuid.UUID | None
    source_account_id: uuid.UUID | None
    kind: AllocationKind
    percent_bp: int | None
    amount_minor: int | None
    currency: str
    goal_id: uuid.UUID | None
    account_id: uuid.UUID | None
    active: bool
    priority: int
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int


class PersonalAllocationPlanIn(Schema):
    id: uuid.UUID | None = None
    """Create only. Use ledger_rules.plan_id(income, rule): uuid5 of the plan namespace and
    "<income id>|<rule id>", so a replay gives back the same plan."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    # Set when the plan is made, never changed: required on a create, and on an update left out
    # or the same.
    source_transaction_id: uuid.UUID | None = None
    """A live income of yours, in your currency."""
    rule_id: uuid.UUID | None = None
    """One of your rules, not deleted. One plan per income and rule, ever."""
    goal_id: uuid.UUID | None = None
    """Exactly one of `goal_id` and `account_id`: where the rule sends money now."""
    account_id: uuid.UUID | None = None
    # The rule as calculated: written whole every time (an edited income recomputes them).
    snapshot_kind: AllocationKind
    snapshot_percent_bp: int | None = Field(default=None, ge=1, le=100_000)
    snapshot_amount_minor: AmountMinor | None = None
    planned_minor: AmountMinor
    """What the app worked out. The server stores it as given."""


class PersonalAllocationPlanOut(Schema):
    """No status: planned, partial, fulfilled or cancelled is the app's to work out."""

    id: uuid.UUID
    source_transaction_id: uuid.UUID
    rule_id: uuid.UUID
    snapshot_kind: AllocationKind
    snapshot_percent_bp: int | None
    snapshot_amount_minor: int | None
    planned_minor: int
    currency: str
    goal_id: uuid.UUID | None
    account_id: uuid.UUID | None
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int


class PersonalHoldingIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    name: Text(80)
    asset_type: HoldingType
    market_value_minor: int = Field(ge=0, le=MAX_BALANCE_MINOR)
    """What it was worth on `valuation_at`."""
    valuation_at: ValuationDate
    valuation_source: Literal["manual"] = "manual"
    # On an update, a field you leave out keeps its value.
    account_id: uuid.UUID | None = None
    """Required on a create: an investment account of yours, open, in your currency."""
    quantity: Quantity | None = None
    cost_basis_minor: int | None = Field(default=None, ge=0, le=MAX_BALANCE_MINOR)
    """What you paid in all, if you know it. The app shows a gain only when it's set."""


class PersonalHoldingOut(Schema):
    """No gain and no stale flag: the app works those out."""

    id: uuid.UUID
    account_id: uuid.UUID
    name: str
    asset_type: HoldingType
    quantity: DecimalStr | None
    cost_basis_minor: int | None
    market_value_minor: int
    valuation_at: date
    valuation_source: Literal["manual"]
    currency: str
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int


class PersonalReminderStateIn(Schema):
    id: uuid.UUID | None = None
    """If sent: ledger_rules.reminder_state_id(you, dedup_key), the id every device makes."""
    version: int | None = None
    """If sent and stale, the change gets a 409; left out, the last decision wins."""
    dedup_key: str | None = Field(default=None, min_length=1, max_length=200)
    """Required when made: the device's `type:entity:window` key. It never changes."""
    status: ReminderStatus
    snoozed_until: datetime | None = None
    """Required when snoozed, and only then."""


class PersonalReminderStateOut(Schema):
    id: uuid.UUID
    dedup_key: str
    status: ReminderStatus
    snoozed_until: datetime | None
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int


class PersonalReminderScheduleIn(Schema):
    id: uuid.UUID | None = None
    """Create only: an id made on the device, so a retried create doesn't make a duplicate."""
    version: int | None = None
    """Update only: the version you edited. If it changed since, the update gets a 409."""
    day_of_month: int = Field(ge=1, le=28)
    # On an update, a field you leave out keeps its value.
    goal_id: uuid.UUID | None = None
    """What it reminds you to put money into: a goal of yours (not archived) or `holding_id`,
    a holding of yours. Exactly one; on an update, giving one replaces the other."""
    holding_id: uuid.UUID | None = None
    amount_minor: AmountMinor | None = None
    """What you usually put in, as a hint."""
    active: bool = True


class PersonalReminderScheduleOut(Schema):
    """No due date: the app works out the next one."""

    id: uuid.UUID
    goal_id: uuid.UUID | None
    holding_id: uuid.UUID | None
    day_of_month: int
    amount_minor: int | None
    currency: str
    active: bool
    acting_admin_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    version: int


BatchKind = Literal[
    "account",
    "transaction",
    "goal",
    "goal_contribution",
    "allocation_rule",
    "allocation_plan",
    "holding",
    "reminder_state",
    "reminder_schedule",
]


class PersonalBatchItem(Schema):
    """One step of a mixed batch. Flat rather than one schema per kind, which generated clients
    handle better: the details go in the field named like `kind`."""

    kind: BatchKind
    op: Literal["create", "update", "delete"]
    """`delete` is for everything but accounts: it deletes as DELETE does, so for example a
    transfer can be unpaired (one leg changed back to an expense or income, the other deleted)
    in one go. For a reminder state, `create` makes or replaces the decision for its key."""
    id: uuid.UUID
    """create: the id to make it with; update and delete: what to change."""
    version: int | None = None
    """update and delete: the version you edited."""
    account: PersonalAccountIn | None = None
    transaction: PersonalTxnIn | None = None
    goal: PersonalGoalIn | None = None
    goal_contribution: PersonalGoalContributionIn | None = None
    allocation_rule: PersonalAllocationRuleIn | None = None
    allocation_plan: PersonalAllocationPlanIn | None = None
    holding: PersonalHoldingIn | None = None
    reminder_state: PersonalReminderStateIn | None = None
    reminder_schedule: PersonalReminderScheduleIn | None = None

    @model_validator(mode="after")
    def _matches_kind(self) -> "PersonalBatchItem":
        payload = getattr(self, self.kind)
        others = [getattr(self, k) for k in get_args(BatchKind) if k != self.kind]
        if any(o is not None for o in others) or (payload is None) != (self.op == "delete"):
            raise ValueError("Each item needs the details for its kind")
        if self.op == "delete" and self.kind == "account":
            raise ValueError("Delete an account with DELETE /personal/accounts/{id}")
        if payload is not None:
            if payload.id not in (None, self.id):
                raise ValueError("An item's details can't have a different id")
            if payload.version not in (None, self.version):
                raise ValueError("An item's details can't have a different version")
        return self


class PersonalMixedBatchIn(Schema):
    items: list[PersonalBatchItem] = Field(min_length=1, max_length=100)
    """Applied in order, all or none. An item may use what an earlier item made (an account, a
    goal, an entry, a rule), so an income and its plans go in one request. A refusal names the
    item it's about (`item`, counting from 0)."""


class PersonalBatchResult(Schema):
    kind: BatchKind
    account: PersonalAccountOut | None = None
    transaction: PersonalTxnOut | None = None
    goal: PersonalGoalOut | None = None
    goal_contribution: PersonalGoalContributionOut | None = None
    allocation_rule: PersonalAllocationRuleOut | None = None
    allocation_plan: PersonalAllocationPlanOut | None = None
    holding: PersonalHoldingOut | None = None
    reminder_state: PersonalReminderStateOut | None = None
    reminder_schedule: PersonalReminderScheduleOut | None = None


class PersonalMixedBatchOut(Schema):
    items: list[PersonalBatchResult]
    """In the order sent."""
