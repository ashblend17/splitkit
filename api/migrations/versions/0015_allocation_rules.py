"""allocation rules and plans

A rule says what to set aside from each income: a percentage (in basis points; over 100% is
allowed, the app warns and never rescales) or a fixed amount, for one goal or one account,
optionally only for incomes in a category or into an account. When you record an income, the
app makes one plan per active rule that applies, in the same request, with an id derived from
the income and the rule. A plan is an intention, never money: progress moves only when money
actually moves (a contribution, a transfer).

A plan snapshots the rule's kind and value as calculated, so it still explains itself after
the rule changes. One plan per income and rule, ever (deleted ones too), so a replay can't add a
second. Planned amounts and whether a plan is fulfilled are worked out on the device.

Nothing to backfill. Downgrading refuses while any rule exists.

Revision ID: 0015_allocation_rules
Revises: 0014_personal_goals
Create Date: 2026-10-17
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0015_allocation_rules"
down_revision: str | Sequence[str] | None = "0014_personal_goals"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

RULES = "personal_allocation_rules"
PLANS = "personal_allocation_plans"
ONE_DESTINATION = "(goal_id IS NULL) <> (account_id IS NULL)"

# name (after ck_<table>_), condition. The models have the same text.
RULE_CHECKS = [
    ("trigger", "trigger IN ('income_recorded')"),
    ("kind", "kind IN ('percentage', 'fixed')"),
    ("percent_when_percentage", "(kind = 'percentage') = (percent_bp IS NOT NULL)"),
    ("amount_when_fixed", "(kind = 'fixed') = (amount_minor IS NOT NULL)"),
    ("percent_range", "percent_bp BETWEEN 1 AND 100000"),
    ("amount_positive", "amount_minor > 0"),
    ("one_destination", ONE_DESTINATION),
]
PLAN_CHECKS = [
    ("snapshot_kind", "snapshot_kind IN ('percentage', 'fixed')"),
    (
        "percent_when_percentage",
        "(snapshot_kind = 'percentage') = (snapshot_percent_bp IS NOT NULL)",
    ),
    ("amount_when_fixed", "(snapshot_kind = 'fixed') = (snapshot_amount_minor IS NOT NULL)"),
    ("planned_positive", "planned_minor > 0"),
    ("one_destination", ONE_DESTINATION),
]


def _timestamp(name: str, nullable: bool = False) -> sa.Column:
    if nullable:
        return sa.Column(name, sa.DateTime(timezone=True), nullable=True)
    return sa.Column(
        name, sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
    )


def _owned(table: str, column: str, target: str) -> sa.ForeignKeyConstraint:
    """(column, user_id) -> target (id, user_id): the row it points at is the owner's."""
    return sa.ForeignKeyConstraint(
        [column, "user_id"],
        [f"{target}.id", f"{target}.user_id"],
        name=op.f(f"fk_{table}_{column}_{target}"),
    )


def _people(table: str) -> list[sa.ForeignKeyConstraint]:
    return [
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f(f"fk_{table}_user_id_users")),
        sa.ForeignKeyConstraint(
            ["acting_admin_id"], ["users.id"], name=op.f(f"fk_{table}_acting_admin_id_users")
        ),
    ]


def upgrade() -> None:
    op.create_table(
        RULES,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("trigger", sa.Text(), server_default="income_recorded", nullable=False),
        sa.Column("source_category_id", sa.Uuid(), nullable=True),
        sa.Column("source_account_id", sa.Uuid(), nullable=True),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("percent_bp", sa.Integer(), nullable=True),
        sa.Column("amount_minor", sa.BigInteger(), nullable=True),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("goal_id", sa.Uuid(), nullable=True),
        sa.Column("account_id", sa.Uuid(), nullable=True),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("priority", sa.Integer(), server_default="0", nullable=False),
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        _timestamp("deleted_at", nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        *(sa.CheckConstraint(c, name=op.f(f"ck_{RULES}_{n}")) for n, c in RULE_CHECKS),
        *_people(RULES),
        sa.ForeignKeyConstraint(
            ["source_category_id"],
            ["categories.id"],
            name=op.f(f"fk_{RULES}_source_category_id_categories"),
        ),
        _owned(RULES, "source_account_id", "personal_accounts"),
        _owned(RULES, "goal_id", "personal_goals"),
        _owned(RULES, "account_id", "personal_accounts"),
        sa.PrimaryKeyConstraint("id", name=op.f(f"pk_{RULES}")),
        sa.UniqueConstraint("id", "user_id", name=op.f(f"uq_{RULES}_id")),
    )
    op.create_index(op.f(f"ix_{RULES}_user_id"), RULES, ["user_id"])

    op.create_table(
        PLANS,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("source_transaction_id", sa.Uuid(), nullable=False),
        sa.Column("rule_id", sa.Uuid(), nullable=False),
        sa.Column("snapshot_kind", sa.Text(), nullable=False),
        sa.Column("snapshot_percent_bp", sa.Integer(), nullable=True),
        sa.Column("snapshot_amount_minor", sa.BigInteger(), nullable=True),
        sa.Column("planned_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("goal_id", sa.Uuid(), nullable=True),
        sa.Column("account_id", sa.Uuid(), nullable=True),
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        _timestamp("deleted_at", nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        *(sa.CheckConstraint(c, name=op.f(f"ck_{PLANS}_{n}")) for n, c in PLAN_CHECKS),
        *_people(PLANS),
        _owned(PLANS, "source_transaction_id", "personal_transactions"),
        _owned(PLANS, "rule_id", RULES),
        _owned(PLANS, "goal_id", "personal_goals"),
        _owned(PLANS, "account_id", "personal_accounts"),
        sa.PrimaryKeyConstraint("id", name=op.f(f"pk_{PLANS}")),
        sa.UniqueConstraint(
            "source_transaction_id", "rule_id", name=op.f(f"uq_{PLANS}_source_transaction_id")
        ),
    )
    op.create_index(op.f(f"ix_{PLANS}_user_id"), PLANS, ["user_id"])


def downgrade() -> None:
    n = op.get_bind().scalar(sa.text("SELECT count(*) FROM personal_allocation_rules"))
    if n:
        raise RuntimeError(
            f"Can't downgrade: {n} allocation rules (deleted ones included) exist. Remove them "
            "and their plans first."
        )
    op.drop_table(PLANS)
    op.drop_table(RULES)
