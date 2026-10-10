"""member invite email

A placeholder member can be linked to an account. When no account has that email yet, the
email is kept on the membership until someone signs up with it.

Revision ID: 0007_member_invite
Revises: 0006_split_position
Create Date: 2026-10-09
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0007_member_invite"
down_revision: str | Sequence[str] | None = "0006_split_position"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("group_members", sa.Column("invite_email", sa.Text(), nullable=True))
    op.create_index(
        "ix_group_members_invite_email",
        "group_members",
        ["invite_email"],
        postgresql_where=sa.text("invite_email IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_group_members_invite_email", table_name="group_members")
    op.drop_column("group_members", "invite_email")
