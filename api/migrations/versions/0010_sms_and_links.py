"""personal entries from bank SMS, linked to group expenses and payments

The app reads bank SMS on the phone and adds what it finds as personal entries, with how it was
paid, who was paid, the account, the bank's reference and the balance it reported (the message
itself never leaves the phone). An entry can be linked to the group expense it was split into,
or to the payment to a friend it was; while that link is live it isn't counted in your totals.

No backfill (say, channel from notes = "UPI"): migrations bypass the sync log, so devices would
never see it.

Revision ID: 0010_sms_and_links
Revises: 0009_reference_data
Create Date: 2026-10-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0010_sms_and_links"
down_revision: str | Sequence[str] | None = "0009_reference_data"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TABLE = "personal_transactions"


def upgrade() -> None:
    op.add_column(TABLE, sa.Column("channel", sa.Text(), nullable=True))
    op.add_column(TABLE, sa.Column("merchant", sa.Text(), nullable=True))
    op.add_column(TABLE, sa.Column("account", sa.Text(), nullable=True))
    op.add_column(TABLE, sa.Column("source", sa.Text(), server_default="manual", nullable=False))
    op.add_column(TABLE, sa.Column("reference", sa.Text(), nullable=True))
    op.add_column(TABLE, sa.Column("balance_minor", sa.BigInteger(), nullable=True))
    op.add_column(TABLE, sa.Column("sms_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column(
        TABLE, sa.Column("reviewed", sa.Boolean(), server_default=sa.text("true"), nullable=False)
    )
    op.add_column(TABLE, sa.Column("expense_id", sa.UUID(), nullable=True))
    op.add_column(TABLE, sa.Column("settlement_id", sa.UUID(), nullable=True))
    op.create_foreign_key(
        op.f("fk_personal_transactions_expense_id_expenses"),
        TABLE,
        "expenses",
        ["expense_id"],
        ["id"],
    )
    op.create_foreign_key(
        op.f("fk_personal_transactions_settlement_id_settlements"),
        TABLE,
        "settlements",
        ["settlement_id"],
        ["id"],
    )
    op.create_check_constraint(
        op.f("ck_personal_transactions_source"), TABLE, "source IN ('manual', 'sms')"
    )
    op.create_check_constraint(
        op.f("ck_personal_transactions_channel"),
        TABLE,
        "channel IN ('upi', 'card', 'bank', 'atm', 'cash', 'other')",
    )
    op.create_check_constraint(
        op.f("ck_personal_transactions_one_link"),
        TABLE,
        "expense_id IS NULL OR settlement_id IS NULL",
    )


def downgrade() -> None:
    op.drop_constraint(op.f("ck_personal_transactions_one_link"), TABLE, type_="check")
    op.drop_constraint(op.f("ck_personal_transactions_channel"), TABLE, type_="check")
    op.drop_constraint(op.f("ck_personal_transactions_source"), TABLE, type_="check")
    op.drop_constraint(
        op.f("fk_personal_transactions_settlement_id_settlements"), TABLE, type_="foreignkey"
    )
    op.drop_constraint(
        op.f("fk_personal_transactions_expense_id_expenses"), TABLE, type_="foreignkey"
    )
    for column in (
        "settlement_id",
        "expense_id",
        "reviewed",
        "sms_at",
        "balance_minor",
        "reference",
        "source",
        "account",
        "merchant",
        "channel",
    ):
        op.drop_column(TABLE, column)
