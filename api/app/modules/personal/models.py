import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CHAR,
    BigInteger,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Numeric,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk
from app.modules.personal.ledger_rules import (
    ACCOUNT_STATUSES,
    ACCOUNT_TYPES,
    ALLOCATION_KINDS,
    ALLOCATION_TRIGGERS,
    DIRECTIONS,
    GOAL_MODES,
    GOAL_STATUSES,
    HOLDING_TYPES,
    IMPLIED_DIRECTION,
    INVESTMENT_TYPES,
    REMINDER_STATUSES,
    TXN_TYPES,
    VALUATION_SOURCES,
    sql_in,
)

_IN_TYPES = tuple(t for t, d in IMPLIED_DIRECTION.items() if d == "in")
_OUT_TYPES = tuple(t for t, d in IMPLIED_DIRECTION.items() if d == "out")


class PersonalAccount(Base):
    """Where your money is (cash, a bank account, an investment account) or what you owe on (a
    credit card, a loan). The balance is never stored: the app derives it from the opening
    balance and the entries that use the account."""

    __tablename__ = "personal_accounts"
    __table_args__ = (
        CheckConstraint(sql_in("type", ACCOUNT_TYPES), name="type"),
        CheckConstraint(sql_in("status", ACCOUNT_STATUSES), name="status"),
        # What entries point at, so an entry can only use its owner's account.
        UniqueConstraint("id", "user_id"),
        # One account per label, ever (deleted ones too), as the label's id is fixed.
        Index(
            "uq_personal_accounts_user_sms_label",
            "user_id",
            "sms_label",
            unique=True,
            postgresql_where=text("sms_label IS NOT NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    """Bank SMS accounts use ledger_rules.sms_account_id(), so every phone makes the same."""
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str]
    type: Mapped[str]
    """cash, bank, credit_card, loan, investment or other_asset."""
    currency: Mapped[str] = mapped_column(CHAR(3))
    opening_balance_minor: Mapped[int] = mapped_column(BigInteger, server_default="0")
    """What you had in it (or owed on it, for a card or loan) before its first entry."""
    sms_label: Mapped[str | None]
    """The label bank SMS entries carry ("HDFC ··4821"); they land in this account."""
    status: Mapped[str] = mapped_column(server_default="active")
    """active or closed. A closed account takes no new entries and still counts in net worth."""
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalTransaction(Base):
    __tablename__ = "personal_transactions"
    __table_args__ = (
        CheckConstraint(sql_in("type", TXN_TYPES), name="type"),
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        CheckConstraint("source IN ('manual', 'sms')", name="source"),
        CheckConstraint(
            "channel IN ('upi', 'card', 'bank', 'atm', 'cash', 'other')", name="channel"
        ),
        CheckConstraint("expense_id IS NULL OR settlement_id IS NULL", name="one_link"),
        CheckConstraint(sql_in("direction", DIRECTIONS), name="direction"),
        CheckConstraint(
            f"({sql_in('type', _IN_TYPES)} AND direction = 'in') "
            f"OR ({sql_in('type', _OUT_TYPES)} AND direction = 'out') "
            "OR type IN ('transfer', 'adjustment')",
            name="direction_matches_type",
        ),
        CheckConstraint(
            "type <> 'transfer' OR (transfer_group_id IS NOT NULL AND account_id IS NOT NULL)",
            name="transfer_complete",
        ),
        CheckConstraint(
            "transfer_group_id IS NULL OR type = 'transfer'", name="group_only_transfers"
        ),
        CheckConstraint(
            "type <> 'adjustment' OR account_id IS NOT NULL", name="adjustment_account"
        ),
        CheckConstraint("refund_of_id IS NULL OR type = 'refund'", name="refund_of_only_refunds"),
        CheckConstraint(
            "(expense_id IS NULL AND settlement_id IS NULL) OR type IN ('income', 'expense')",
            name="links_only_income_expense",
        ),
        CheckConstraint(
            "category_id IS NULL OR type NOT IN ('transfer', 'adjustment')",
            name="no_category_on_moves",
        ),
        CheckConstraint(
            f"holding_id IS NULL OR {sql_in('type', INVESTMENT_TYPES)}",
            name="holding_only_on_investments",
        ),
        # The targets below include user_id, so an entry can only use its owner's account and
        # refund its owner's spend.
        UniqueConstraint("id", "user_id"),
        ForeignKeyConstraint(
            ["account_id", "user_id"], ["personal_accounts.id", "personal_accounts.user_id"]
        ),
        ForeignKeyConstraint(
            ["refund_of_id", "user_id"],
            ["personal_transactions.id", "personal_transactions.user_id"],
        ),
        ForeignKeyConstraint(
            ["holding_id", "user_id"], ["personal_holdings.id", "personal_holdings.user_id"]
        ),
        Index(
            "ix_personal_transactions_user_date",
            "user_id",
            text("date DESC"),
            postgresql_where=text("deleted_at IS NULL"),
        ),
        Index(
            "ix_personal_transactions_account_id",
            "account_id",
            postgresql_where=text("account_id IS NOT NULL"),
        ),
        Index(
            "ix_personal_transactions_transfer_group_id",
            "transfer_group_id",
            postgresql_where=text("transfer_group_id IS NOT NULL"),
        ),
        Index(
            "ix_personal_transactions_refund_of_id",
            "refund_of_id",
            postgresql_where=text("refund_of_id IS NOT NULL"),
        ),
        Index(
            "ix_personal_transactions_holding_id",
            "holding_id",
            postgresql_where=text("holding_id IS NOT NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    type: Mapped[str]
    """income, expense, transfer (one leg), refund, investment_contribution,
    investment_withdrawal or adjustment (a balance correction)."""
    direction: Mapped[str]
    """'in' or 'out' of the account. Implied by the type, except for transfers and
    adjustments (ledger_rules.IMPLIED_DIRECTION)."""
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    category_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("categories.id"))
    date: Mapped[date]
    description: Mapped[str]
    notes: Mapped[str | None]
    account_id: Mapped[uuid.UUID | None]
    """The account it moved. Its balance counts every live entry, counted in totals or not:
    the money left the account either way."""
    transfer_group_id: Mapped[uuid.UUID | None]
    """A transfer is two legs (one out, one in, same amount, two of your accounts) sharing
    this id. A deferred trigger refuses a commit that leaves a group with anything else."""
    refund_of_id: Mapped[uuid.UUID | None]
    """The spend this refund gives money back for."""
    holding_id: Mapped[uuid.UUID | None]
    """For an investment or a withdrawal: the holding it bought into or sold from."""
    channel: Mapped[str | None]
    """How it was paid: upi, card, bank (transfer), atm, cash or other."""
    merchant: Mapped[str | None]
    """Who was paid (or paid you), as the bank named them. The app learns categories by it."""
    account: Mapped[str | None]
    """The account or card it went through, as the app labels it ("HDFC ··4821")."""
    # Where it came from. Set when it's made, never edited: a bank SMS read on your phone (the
    # message itself stays there), its reference number and the balance it reported.
    source: Mapped[str] = mapped_column(server_default="manual")
    reference: Mapped[str | None]
    balance_minor: Mapped[int | None] = mapped_column(BigInteger)
    sms_at: Mapped[datetime | None]
    reviewed: Mapped[bool] = mapped_column(server_default=text("true"))
    """False for an entry the app added from a bank SMS that you haven't looked at yet."""
    # What this spend became in Split, seen only by you. While the expense or payment is live
    # in a group you're still in, the entry isn't counted in your totals: your share of the
    # expense counts as group spending, and a payment isn't spending at all.
    expense_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("expenses.id"))
    settlement_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("settlements.id"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalGoal(Base):
    """Something you're saving towards. Its progress is never stored: the app derives it from
    the goal's contributions, from the balance of the account it follows, or from the figure you
    typed, depending on `tracking_mode`."""

    __tablename__ = "personal_goals"
    __table_args__ = (
        CheckConstraint("target_minor > 0", name="target_positive"),
        CheckConstraint(sql_in("tracking_mode", GOAL_MODES), name="tracking_mode"),
        CheckConstraint(sql_in("status", GOAL_STATUSES), name="status"),
        CheckConstraint(
            "(tracking_mode = 'linked_balance') = (linked_account_id IS NOT NULL)",
            name="account_only_when_linked",
        ),
        CheckConstraint(
            "(tracking_mode = 'manual') = (manual_progress_minor IS NOT NULL)",
            name="progress_only_when_manual",
        ),
        CheckConstraint("manual_progress_minor >= 0", name="progress_not_negative"),
        CheckConstraint("expected_return_bp >= 0", name="return_not_negative"),
        # What contributions point at, so a contribution can only be to its owner's goal.
        UniqueConstraint("id", "user_id"),
        ForeignKeyConstraint(
            ["linked_account_id", "user_id"], ["personal_accounts.id", "personal_accounts.user_id"]
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str]
    target_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    target_date: Mapped[date | None]
    tracking_mode: Mapped[str] = mapped_column(server_default="contribution")
    """contribution (the sum of its contributions), linked_balance (the balance of
    `linked_account_id`) or manual (`manual_progress_minor`)."""
    linked_account_id: Mapped[uuid.UUID | None]
    manual_progress_minor: Mapped[int | None] = mapped_column(BigInteger)
    expected_return_bp: Mapped[int | None]
    """Expected monthly return in basis points, for an optional estimate the app labels as one."""
    priority: Mapped[int] = mapped_column(server_default="0")
    status: Mapped[str] = mapped_column(server_default="active")
    """active, paused, completed or archived."""
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalGoalContribution(Base):
    """Money you put towards a goal, optionally the entry that moved it (a transfer to savings,
    an investment). An entry counts towards one goal at most, and never towards a goal that
    also counts it through an account's balance."""

    __tablename__ = "personal_goal_contributions"
    __table_args__ = (
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        ForeignKeyConstraint(
            ["goal_id", "user_id"], ["personal_goals.id", "personal_goals.user_id"]
        ),
        ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["personal_transactions.id", "personal_transactions.user_id"],
        ),
        Index(
            "uq_personal_goal_contributions_live_transaction",
            "transaction_id",
            unique=True,
            postgresql_where=text("transaction_id IS NOT NULL AND deleted_at IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    goal_id: Mapped[uuid.UUID] = mapped_column(index=True)
    transaction_id: Mapped[uuid.UUID | None]
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    date: Mapped[date]
    note: Mapped[str | None]
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


def _destination() -> tuple:
    """Exactly one of a goal or an account, each its owner's."""
    return (
        CheckConstraint("(goal_id IS NULL) <> (account_id IS NULL)", name="one_destination"),
        ForeignKeyConstraint(
            ["goal_id", "user_id"], ["personal_goals.id", "personal_goals.user_id"]
        ),
        ForeignKeyConstraint(
            ["account_id", "user_id"], ["personal_accounts.id", "personal_accounts.user_id"]
        ),
    )


class PersonalAllocationRule(Base):
    """ "Put 10% of every income towards the trip." When you record an income, the app makes a
    plan for each active rule that applies. A plan is an intention, never money (spec §4.3)."""

    __tablename__ = "personal_allocation_rules"
    __table_args__ = (
        CheckConstraint(sql_in("trigger", ALLOCATION_TRIGGERS), name="trigger"),
        CheckConstraint(sql_in("kind", ALLOCATION_KINDS), name="kind"),
        CheckConstraint(
            "(kind = 'percentage') = (percent_bp IS NOT NULL)", name="percent_when_percentage"
        ),
        CheckConstraint("(kind = 'fixed') = (amount_minor IS NOT NULL)", name="amount_when_fixed"),
        CheckConstraint("percent_bp BETWEEN 1 AND 100000", name="percent_range"),
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        *_destination(),
        ForeignKeyConstraint(
            ["source_account_id", "user_id"], ["personal_accounts.id", "personal_accounts.user_id"]
        ),
        # What plans point at, so a plan can only follow its owner's rule.
        UniqueConstraint("id", "user_id"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str | None]
    trigger: Mapped[str] = mapped_column(server_default="income_recorded")
    source_category_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("categories.id"))
    """Only incomes in this category, if set."""
    source_account_id: Mapped[uuid.UUID | None]
    """Only incomes into this account, if set."""
    kind: Mapped[str]
    """percentage (`percent_bp`) or fixed (`amount_minor`)."""
    percent_bp: Mapped[int | None]
    """Basis points of the income: 1000 is 10%. Up to 1000%: over 100% is the user's call."""
    amount_minor: Mapped[int | None] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    goal_id: Mapped[uuid.UUID | None]
    account_id: Mapped[uuid.UUID | None]
    active: Mapped[bool] = mapped_column(server_default=text("true"))
    priority: Mapped[int] = mapped_column(server_default="0")
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalAllocationPlan(Base):
    """What a rule set aside from one income, as calculated then: the rule's kind and value are
    snapshotted, so a plan still explains itself after the rule changes. Whether it's planned,
    partly or wholly done, or cancelled (its income deleted) is the app's to work out."""

    __tablename__ = "personal_allocation_plans"
    __table_args__ = (
        CheckConstraint(sql_in("snapshot_kind", ALLOCATION_KINDS), name="snapshot_kind"),
        CheckConstraint(
            "(snapshot_kind = 'percentage') = (snapshot_percent_bp IS NOT NULL)",
            name="percent_when_percentage",
        ),
        CheckConstraint(
            "(snapshot_kind = 'fixed') = (snapshot_amount_minor IS NOT NULL)",
            name="amount_when_fixed",
        ),
        CheckConstraint("planned_minor > 0", name="planned_positive"),
        *_destination(),
        ForeignKeyConstraint(
            ["source_transaction_id", "user_id"],
            ["personal_transactions.id", "personal_transactions.user_id"],
        ),
        ForeignKeyConstraint(
            ["rule_id", "user_id"],
            ["personal_allocation_rules.id", "personal_allocation_rules.user_id"],
        ),
        # One plan per income and rule, ever (deleted ones too), so a replay can't add one.
        UniqueConstraint("source_transaction_id", "rule_id"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    """ledger_rules.plan_id(income, rule): the app makes the same one every time."""
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    source_transaction_id: Mapped[uuid.UUID]
    rule_id: Mapped[uuid.UUID]
    snapshot_kind: Mapped[str]
    snapshot_percent_bp: Mapped[int | None]
    snapshot_amount_minor: Mapped[int | None] = mapped_column(BigInteger)
    planned_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    goal_id: Mapped[uuid.UUID | None]
    account_id: Mapped[uuid.UUID | None]
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalHolding(Base):
    """Something held in an investment account: a fund, shares, a deposit, gold. Only its
    latest valuation, typed in by you. Gains and whether the value is stale (over 30 days) are
    the app's to work out; it shows a gain only when both cost basis and value are known."""

    __tablename__ = "personal_holdings"
    __table_args__ = (
        CheckConstraint(sql_in("asset_type", HOLDING_TYPES), name="asset_type"),
        CheckConstraint(sql_in("valuation_source", VALUATION_SOURCES), name="valuation_source"),
        CheckConstraint("quantity >= 0", name="quantity_not_negative"),
        CheckConstraint("cost_basis_minor >= 0", name="cost_basis_not_negative"),
        CheckConstraint("market_value_minor >= 0", name="market_value_not_negative"),
        ForeignKeyConstraint(
            ["account_id", "user_id"], ["personal_accounts.id", "personal_accounts.user_id"]
        ),
        # What entries and reminder schedules point at, so they can only name their owner's.
        UniqueConstraint("id", "user_id"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    account_id: Mapped[uuid.UUID]
    """An investment account of yours."""
    name: Mapped[str]
    asset_type: Mapped[str]
    """mutual_fund, stock, fd, gold or other."""
    quantity: Mapped[Decimal | None] = mapped_column(Numeric(18, 6))
    """Units, shares or grams, if you track them."""
    cost_basis_minor: Mapped[int | None] = mapped_column(BigInteger)
    """What you paid in all, if you know it."""
    market_value_minor: Mapped[int] = mapped_column(BigInteger)
    valuation_at: Mapped[date]
    """When `market_value_minor` was true."""
    valuation_source: Mapped[str] = mapped_column(server_default="manual")
    currency: Mapped[str] = mapped_column(CHAR(3))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalReminderState(Base):
    """Your decision on one reminder, so every device honours it: dismissed, snoozed until a
    time, or done. Which reminders are due, and whether one was shown, is worked out and kept on
    each device; only decisions are stored."""

    __tablename__ = "personal_reminder_states"
    __table_args__ = (
        CheckConstraint(sql_in("status", REMINDER_STATUSES), name="status"),
        CheckConstraint(
            "(status = 'snoozed') = (snoozed_until IS NOT NULL)", name="until_only_when_snoozed"
        ),
        CheckConstraint("char_length(dedup_key) BETWEEN 1 AND 200", name="dedup_key_length"),
        # One decision per reminder, ever: its id comes from the key (ledger_rules).
        UniqueConstraint("user_id", "dedup_key"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    """ledger_rules.reminder_state_id(user, dedup_key)."""
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    dedup_key: Mapped[str]
    """The device's `type:entity:window` key, e.g. "goal_behind:<goal id>:2026-10"."""
    status: Mapped[str]
    snoozed_until: Mapped[datetime | None]
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class PersonalReminderSchedule(Base):
    """A monthly reminder for a recurring investment (a SIP) into a goal or a holding. It only
    reminds: it never records an entry (spec §4.7)."""

    __tablename__ = "personal_reminder_schedules"
    __table_args__ = (
        CheckConstraint("(goal_id IS NULL) <> (holding_id IS NULL)", name="one_target"),
        CheckConstraint("day_of_month BETWEEN 1 AND 28", name="day_of_month"),
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        ForeignKeyConstraint(
            ["goal_id", "user_id"], ["personal_goals.id", "personal_goals.user_id"]
        ),
        ForeignKeyConstraint(
            ["holding_id", "user_id"], ["personal_holdings.id", "personal_holdings.user_id"]
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    goal_id: Mapped[uuid.UUID | None]
    holding_id: Mapped[uuid.UUID | None]
    day_of_month: Mapped[int]
    """1 to 28, so every month has it."""
    amount_minor: Mapped[int | None] = mapped_column(BigInteger)
    """What you usually put in, as a hint for the reminder."""
    currency: Mapped[str] = mapped_column(CHAR(3))
    active: Mapped[bool] = mapped_column(server_default=text("true"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}
