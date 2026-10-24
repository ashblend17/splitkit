"""personal holdings, and the holding an investment entry names

A holding is something kept in an investment account: a fund, shares, a deposit, gold. It has
its latest valuation only, typed in by you (no price feeds), and optionally what it cost. Gains
and whether a value is stale are worked out on the device; the server stores what you typed.

An investment or a withdrawal entry can name the holding it bought into or sold from
(`personal_transactions.holding_id`, one of yours, and only on those two types). Net worth then
counts a contribution made after the holding's last valuation at cost, until the next one.

Numbered before the reminder tables (0017) because a reminder schedule can be on a holding.
Nothing to backfill. Downgrading refuses while any holding exists.

Revision ID: 0016_personal_holdings
Revises: 0015_allocation_rules
Create Date: 2026-10-17
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0016_personal_holdings"
down_revision: str | Sequence[str] | None = "0015_allocation_rules"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

HOLDINGS = "personal_holdings"
TXN = "personal_transactions"

# name (after ck_personal_holdings_), condition. The model has the same text.
HOLDING_CHECKS = [
    ("asset_type", "asset_type IN ('mutual_fund', 'stock', 'fd', 'gold', 'other')"),
    ("valuation_source", "valuation_source IN ('manual')"),
    ("quantity_not_negative", "quantity >= 0"),
    ("cost_basis_not_negative", "cost_basis_minor >= 0"),
    ("market_value_not_negative", "market_value_minor >= 0"),
]
HOLDING_ON_INVESTMENTS = (
    "holding_id IS NULL OR type IN ('investment_contribution', 'investment_withdrawal')"
)


def upgrade() -> None:
    op.create_table(
        HOLDINGS,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("asset_type", sa.Text(), nullable=False),
        sa.Column("quantity", sa.Numeric(18, 6), nullable=True),
        sa.Column("cost_basis_minor", sa.BigInteger(), nullable=True),
        sa.Column("market_value_minor", sa.BigInteger(), nullable=False),
        sa.Column("valuation_at", sa.Date(), nullable=False),
        sa.Column("valuation_source", sa.Text(), server_default="manual", nullable=False),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        *(sa.CheckConstraint(c, name=op.f(f"ck_{HOLDINGS}_{n}")) for n, c in HOLDING_CHECKS),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f(f"fk_{HOLDINGS}_user_id_users")
        ),
        sa.ForeignKeyConstraint(
            ["acting_admin_id"], ["users.id"], name=op.f(f"fk_{HOLDINGS}_acting_admin_id_users")
        ),
        sa.ForeignKeyConstraint(
            ["account_id", "user_id"],
            ["personal_accounts.id", "personal_accounts.user_id"],
            name=op.f(f"fk_{HOLDINGS}_account_id_personal_accounts"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f(f"pk_{HOLDINGS}")),
        sa.UniqueConstraint("id", "user_id", name=op.f(f"uq_{HOLDINGS}_id")),
    )
    op.create_index(op.f(f"ix_{HOLDINGS}_user_id"), HOLDINGS, ["user_id"])

    op.add_column(TXN, sa.Column("holding_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        op.f("fk_personal_transactions_holding_id_personal_holdings"),
        TXN,
        HOLDINGS,
        ["holding_id", "user_id"],
        ["id", "user_id"],
    )
    op.create_check_constraint(
        op.f("ck_personal_transactions_holding_only_on_investments"), TXN, HOLDING_ON_INVESTMENTS
    )
    op.create_index(
        op.f("ix_personal_transactions_holding_id"),
        TXN,
        ["holding_id"],
        postgresql_where=sa.text("holding_id IS NOT NULL"),
    )


def downgrade() -> None:
    n = op.get_bind().scalar(sa.text("SELECT count(*) FROM personal_holdings"))
    if n:
        raise RuntimeError(
            f"Can't downgrade: {n} personal holdings (deleted ones included) exist. Remove them "
            "first."
        )
    op.drop_index(op.f("ix_personal_transactions_holding_id"), table_name=TXN)
    op.drop_constraint(
        op.f("ck_personal_transactions_holding_only_on_investments"), TXN, type_="check"
    )
    op.drop_constraint(
        op.f("fk_personal_transactions_holding_id_personal_holdings"), TXN, type_="foreignkey"
    )
    op.drop_column(TXN, "holding_id")
    op.drop_table(HOLDINGS)
