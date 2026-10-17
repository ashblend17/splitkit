"""personal goals and goal contributions

A goal is something you're saving towards: a target, an optional date, and where its progress
comes from (`tracking_mode`): its contributions, the balance of one account it follows, or a
figure you type. Progress, what's left and what's needed per month are never stored; the app
derives them.

A contribution is money put towards a goal, optionally with the entry that moved it. An entry
counts towards one goal at most (a unique index on live contributions), and the API refuses a
contribution from an entry that moves an account some goal follows by balance, so nothing is
counted twice. The goal and entry foreign keys include `user_id`, so both are the owner's.

Nothing to backfill. Downgrading refuses while any goal exists: silently deleting what people
are saving towards is worse than refusing.

Revision ID: 0014_personal_goals
Revises: 0013_personal_ledger
Create Date: 2026-10-17
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0014_personal_goals"
down_revision: str | Sequence[str] | None = "0013_personal_ledger"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

GOALS = "personal_goals"
CONTRIBUTIONS = "personal_goal_contributions"

# name (after ck_personal_goals_), condition. The model has the same text.
GOAL_CHECKS = [
    ("target_positive", "target_minor > 0"),
    ("tracking_mode", "tracking_mode IN ('contribution', 'linked_balance', 'manual')"),
    ("status", "status IN ('active', 'paused', 'completed', 'archived')"),
    (
        "account_only_when_linked",
        "(tracking_mode = 'linked_balance') = (linked_account_id IS NOT NULL)",
    ),
    ("progress_only_when_manual", "(tracking_mode = 'manual') = (manual_progress_minor IS NOT NULL)"),
    ("progress_not_negative", "manual_progress_minor >= 0"),
    ("return_not_negative", "expected_return_bp >= 0"),
]


def _timestamp(name: str, nullable: bool = False) -> sa.Column:
    if nullable:
        return sa.Column(name, sa.DateTime(timezone=True), nullable=True)
    return sa.Column(
        name, sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
    )


def upgrade() -> None:
    op.create_table(
        GOALS,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("target_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("target_date", sa.Date(), nullable=True),
        sa.Column("tracking_mode", sa.Text(), server_default="contribution", nullable=False),
        sa.Column("linked_account_id", sa.Uuid(), nullable=True),
        sa.Column("manual_progress_minor", sa.BigInteger(), nullable=True),
        sa.Column("expected_return_bp", sa.Integer(), nullable=True),
        sa.Column("priority", sa.Integer(), server_default="0", nullable=False),
        sa.Column("status", sa.Text(), server_default="active", nullable=False),
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        _timestamp("deleted_at", nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        *(sa.CheckConstraint(c, name=op.f(f"ck_personal_goals_{n}")) for n, c in GOAL_CHECKS),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_personal_goals_user_id_users")
        ),
        sa.ForeignKeyConstraint(
            ["acting_admin_id"], ["users.id"], name=op.f("fk_personal_goals_acting_admin_id_users")
        ),
        sa.ForeignKeyConstraint(
            ["linked_account_id", "user_id"],
            ["personal_accounts.id", "personal_accounts.user_id"],
            name=op.f("fk_personal_goals_linked_account_id_personal_accounts"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_personal_goals")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_personal_goals_id")),
    )
    op.create_index(op.f("ix_personal_goals_user_id"), GOALS, ["user_id"])

    op.create_table(
        CONTRIBUTIONS,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("goal_id", sa.Uuid(), nullable=False),
        sa.Column("transaction_id", sa.Uuid(), nullable=True),
        sa.Column("amount_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        _timestamp("created_at"),
        _timestamp("deleted_at", nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        sa.CheckConstraint(
            "amount_minor > 0", name=op.f("ck_personal_goal_contributions_amount_positive")
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_personal_goal_contributions_user_id_users")
        ),
        sa.ForeignKeyConstraint(
            ["acting_admin_id"],
            ["users.id"],
            name=op.f("fk_personal_goal_contributions_acting_admin_id_users"),
        ),
        sa.ForeignKeyConstraint(
            ["goal_id", "user_id"],
            ["personal_goals.id", "personal_goals.user_id"],
            name=op.f("fk_personal_goal_contributions_goal_id_personal_goals"),
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["personal_transactions.id", "personal_transactions.user_id"],
            name=op.f("fk_personal_goal_contributions_transaction_id_personal_transactions"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_personal_goal_contributions")),
    )
    op.create_index(op.f("ix_personal_goal_contributions_user_id"), CONTRIBUTIONS, ["user_id"])
    op.create_index(op.f("ix_personal_goal_contributions_goal_id"), CONTRIBUTIONS, ["goal_id"])
    op.create_index(
        "uq_personal_goal_contributions_live_transaction",
        CONTRIBUTIONS,
        ["transaction_id"],
        unique=True,
        postgresql_where=sa.text("transaction_id IS NOT NULL AND deleted_at IS NULL"),
    )


def downgrade() -> None:
    n = op.get_bind().scalar(sa.text("SELECT count(*) FROM personal_goals"))
    if n:
        raise RuntimeError(
            f"Can't downgrade: {n} personal goals (deleted ones included) exist. Remove them "
            "and their contributions first."
        )
    op.drop_table(CONTRIBUTIONS)
    op.drop_table(GOALS)
