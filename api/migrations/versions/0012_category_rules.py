"""categories learned from what you chose

A rule remembers the category you put a merchant (or a description) under, so the app suggests
it the next time. Written by the API when you pick a category (categories/rules.py) and synced
on your user stream. Nothing is backfilled: past entries' categories were mostly guessed by the
app, not chosen.

Revision ID: 0012_category_rules
Revises: 0011_personal_insight_cards
Create Date: 2026-10-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0012_category_rules"
down_revision: str | Sequence[str] | None = "0011_personal_insight_cards"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "category_rules",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("pattern", sa.Text(), nullable=False),
        sa.Column("income", sa.Boolean(), nullable=False),
        sa.Column("category_id", sa.Uuid(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["categories.id"],
            name=op.f("fk_category_rules_category_id_categories"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_category_rules_user_id_users")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_category_rules")),
        sa.UniqueConstraint("user_id", "income", "pattern", name=op.f("uq_category_rules_user_id")),
    )


def downgrade() -> None:
    op.drop_table("category_rules")
