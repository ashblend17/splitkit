"""The fixed rules of the personal ledger: which entry types exist and which way each moves
money, which account types exist and which of them are owed, the goal and allocation enums, and
the ids the app makes itself: an account read from bank SMS, a rule's plan for an income, and
your decision on a reminder.

The app's `core/finance/` mirrors these. Migration 0013 keeps its own copy of the namespace
and of the label rule, so it never changes with the app; `shared/ledger_vectors.json` pins
both sides.
"""

import uuid

TXN_TYPES = (
    "income",
    "expense",
    "transfer",
    "refund",
    "investment_contribution",
    "investment_withdrawal",
    "adjustment",
)
DIRECTIONS = ("in", "out")
IMPLIED_DIRECTION = {
    "income": "in",
    "refund": "in",
    "investment_withdrawal": "in",
    "expense": "out",
    "investment_contribution": "out",
}
"""The direction a type implies. A transfer leg or a balance correction says its own."""

ACCOUNT_TYPES = ("cash", "bank", "credit_card", "loan", "investment", "other_asset")
LIABILITY_TYPES = frozenset({"credit_card", "loan"})
"""Accounts whose balance is what you owe: money going out raises it."""
ACCOUNT_STATUSES = ("active", "closed")
GOAL_MODES = ("contribution", "linked_balance", "manual")
"""Where a goal's progress comes from: its contributions, an account's balance, or a figure you
type. An entry counts towards a goal one way only."""
GOAL_STATUSES = ("active", "paused", "completed", "archived")
HOLDING_TYPES = ("mutual_fund", "stock", "fd", "gold", "other")
VALUATION_SOURCES = ("manual",)
"""Where a holding's market value came from: typed in by you (no price feeds in v1)."""
INVESTMENT_TYPES = ("investment_contribution", "investment_withdrawal")
"""The entry types that can name the holding they bought into or sold from."""
REMINDER_STATUSES = ("dismissed", "snoozed", "done")
"""Your decision on a reminder. Pending and sent are per device and never stored."""
ALLOCATION_TRIGGERS = ("income_recorded",)
ALLOCATION_KINDS = ("percentage", "fixed")
"""A rule sends a percentage of each income it applies to (in basis points, over 100% allowed:
the app warns and never rescales) or a fixed amount."""

ACCOUNT_NAMESPACE = uuid.UUID("e90fe153-8f9c-5d42-8516-3ac04850d447")
"""uuid5(NAMESPACE_URL, "https://splitkit.app/sms-account")."""


PLAN_NAMESPACE = uuid.UUID("1e9fd80e-c002-5f96-bd4e-d295ec89c7fc")
"""uuid5(NAMESPACE_URL, "https://splitkit.app/allocation-plan")."""
REMINDER_NAMESPACE = uuid.UUID("3b36adfa-75dd-550a-ac0b-0e156df727cc")
"""uuid5(NAMESPACE_URL, "https://splitkit.app/reminder-state")."""


def implied_direction(type: str) -> str | None:
    """'in' or 'out' for a type that implies one, None for a transfer or an adjustment."""
    return IMPLIED_DIRECTION.get(type)


def sms_account_id(user_id: uuid.UUID | str, label: str) -> uuid.UUID:
    """The account for a bank SMS label ("HDFC ··4821"). Every phone, and migration 0013's
    backfill, makes the same id for the same label, so a repeat create returns the row."""
    return uuid.uuid5(ACCOUNT_NAMESPACE, f"{user_id}|{label}")


def plan_id(transaction_id: uuid.UUID | str, rule_id: uuid.UUID | str) -> uuid.UUID:
    """The plan a rule makes for an income. The app makes it with the income, so a replay or a
    second read of the same bank SMS gives the same plan, never a second one."""
    return uuid.uuid5(PLAN_NAMESPACE, f"{transaction_id}|{rule_id}")


def reminder_state_id(user_id: uuid.UUID | str, dedup_key: str) -> uuid.UUID:
    """Your decision on the reminder with this dedup key ("goal_behind:<goal id>:2026-10"):
    every device makes the same id, so two phones dismissing the same reminder make one row."""
    return uuid.uuid5(REMINDER_NAMESPACE, f"{user_id}|{dedup_key}")


def account_type_for_label(label: str) -> str:
    """The SMS parser labels cards "<Bank> Credit card ··1234". Debit cards draw from a bank
    account, so they're `bank`."""
    return "credit_card" if "credit card" in label.lower() else "bank"


def sql_in(column: str, values: tuple[str, ...]) -> str:
    """`column IN ('a', 'b')` for a check constraint."""
    return f"{column} IN ({', '.join(repr(v) for v in values)})"
