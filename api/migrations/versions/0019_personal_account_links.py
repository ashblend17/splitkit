"""personal account links and account numbers

An account can be linked to another of yours (`linked_account_id`): the same account under a
second bank SMS label ("HDFC ··787778" and "HDFC ··7778"), or a debit card on a bank account. Its
entries then count in that account's balance. And an account can carry its full number
(`account_number`, digits only), so a label with more or fewer of its last digits lands in it.

Both are new columns with no backfill, so devices see nothing change until an account is
linked or numbered; no stream reset is needed.

Downgrading is refused while any account is linked or numbered, since older servers and apps
would count a linked account on its own again.

Revision ID: 0019_personal_account_links
Revises: 0018_finance_insight_cards
Create Date: 2026-10-20
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0019_personal_account_links"
down_revision: str | Sequence[str] | None = "0018_finance_insight_cards"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("personal_accounts", sa.Column("linked_account_id", sa.Uuid(), nullable=True))
    op.add_column("personal_accounts", sa.Column("account_number", sa.Text(), nullable=True))
    op.create_foreign_key(
        op.f("fk_personal_accounts_linked_account_id_personal_accounts"),
        "personal_accounts",
        "personal_accounts",
        ["linked_account_id", "user_id"],
        ["id", "user_id"],
    )
    op.create_check_constraint(
        op.f("ck_personal_accounts_not_linked_to_itself"),
        "personal_accounts",
        "linked_account_id <> id",
    )
    op.create_check_constraint(
        op.f("ck_personal_accounts_account_number_digits"),
        "personal_accounts",
        "account_number ~ '^[0-9]{4,20}$'",
    )


def downgrade() -> None:
    used = op.get_bind().scalar(
        sa.text(
            "SELECT count(*) FROM personal_accounts "
            "WHERE linked_account_id IS NOT NULL OR account_number IS NOT NULL"
        )
    )
    if used:
        raise RuntimeError(
            f"{used} accounts are linked or have an account number. Unlink them and clear the "
            "numbers before downgrading"
        )
    op.drop_constraint(
        op.f("ck_personal_accounts_account_number_digits"), "personal_accounts", type_="check"
    )
    op.drop_constraint(
        op.f("ck_personal_accounts_not_linked_to_itself"), "personal_accounts", type_="check"
    )
    op.drop_constraint(
        op.f("fk_personal_accounts_linked_account_id_personal_accounts"),
        "personal_accounts",
        type_="foreignkey",
    )
    op.drop_column("personal_accounts", "account_number")
    op.drop_column("personal_accounts", "linked_account_id")
