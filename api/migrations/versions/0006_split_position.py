"""expense split position

Splits had no order, so two reads of one expense (or a read and its sync entry) could list
them differently. Existing rows keep the order they are stored in.

Revision ID: 0006_split_position
Revises: 0005_import
Create Date: 2026-09-25
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006_split_position"
down_revision: str | Sequence[str] | None = "0005_import"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "expense_splits",
        sa.Column("position", sa.SmallInteger(), server_default="0", nullable=False),
    )
    op.execute(
        """
        UPDATE expense_splits s SET position = o.n
        FROM (
            SELECT ctid, row_number() OVER (PARTITION BY expense_id ORDER BY ctid) - 1 AS n
            FROM expense_splits
        ) o
        WHERE s.ctid = o.ctid
        """
    )


def downgrade() -> None:
    op.drop_column("expense_splits", "position")
