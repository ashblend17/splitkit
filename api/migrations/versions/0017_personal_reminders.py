"""reminder decisions and recurring-investment reminders

Reminders are worked out on each device (spec §5.7): which are due, which were shown, and the
notifications themselves. Only your decisions sync, so every device honours them: a
`personal_reminder_states` row per reminder (by the device's `type:entity:window` dedup key,
one per key ever, with an id derived from it) says dismissed, snoozed until when, or done.

`personal_reminder_schedules` are monthly reminders for a recurring investment (a SIP) into a
goal or a holding: a day of the month and an optional amount hint. They only remind; nothing
ever records an entry for them (spec §4.7).

Nothing to backfill. Downgrading refuses while any decision or schedule exists.

Revision ID: 0017_personal_reminders
Revises: 0016_personal_holdings
Create Date: 2026-10-17
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0017_personal_reminders"
down_revision: str | Sequence[str] | None = "0016_personal_holdings"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

STATES = "personal_reminder_states"
SCHEDULES = "personal_reminder_schedules"

# name (after ck_<table>_), condition. The models have the same text.
STATE_CHECKS = [
    ("status", "status IN ('dismissed', 'snoozed', 'done')"),
    ("until_only_when_snoozed", "(status = 'snoozed') = (snoozed_until IS NOT NULL)"),
    ("dedup_key_length", "char_length(dedup_key) BETWEEN 1 AND 200"),
]
SCHEDULE_CHECKS = [
    ("one_target", "(goal_id IS NULL) <> (holding_id IS NULL)"),
    ("day_of_month", "day_of_month BETWEEN 1 AND 28"),
    ("amount_positive", "amount_minor > 0"),
]


def _common(table: str) -> list:
    return [
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f(f"fk_{table}_user_id_users")),
        sa.ForeignKeyConstraint(
            ["acting_admin_id"], ["users.id"], name=op.f(f"fk_{table}_acting_admin_id_users")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f(f"pk_{table}")),
    ]


def upgrade() -> None:
    op.create_table(
        STATES,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("dedup_key", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True),
        *_common(STATES),
        *(sa.CheckConstraint(c, name=op.f(f"ck_{STATES}_{n}")) for n, c in STATE_CHECKS),
        sa.UniqueConstraint("user_id", "dedup_key", name=op.f(f"uq_{STATES}_user_id")),
    )

    op.create_table(
        SCHEDULES,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("goal_id", sa.Uuid(), nullable=True),
        sa.Column("holding_id", sa.Uuid(), nullable=True),
        sa.Column("day_of_month", sa.Integer(), nullable=False),
        sa.Column("amount_minor", sa.BigInteger(), nullable=True),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        *_common(SCHEDULES),
        *(sa.CheckConstraint(c, name=op.f(f"ck_{SCHEDULES}_{n}")) for n, c in SCHEDULE_CHECKS),
        sa.ForeignKeyConstraint(
            ["goal_id", "user_id"],
            ["personal_goals.id", "personal_goals.user_id"],
            name=op.f(f"fk_{SCHEDULES}_goal_id_personal_goals"),
        ),
        sa.ForeignKeyConstraint(
            ["holding_id", "user_id"],
            ["personal_holdings.id", "personal_holdings.user_id"],
            name=op.f(f"fk_{SCHEDULES}_holding_id_personal_holdings"),
        ),
    )
    op.create_index(op.f(f"ix_{SCHEDULES}_user_id"), SCHEDULES, ["user_id"])


def downgrade() -> None:
    conn = op.get_bind()
    n = conn.scalar(sa.text(f"SELECT count(*) FROM {STATES}")) + conn.scalar(
        sa.text(f"SELECT count(*) FROM {SCHEDULES}")
    )
    if n:
        raise RuntimeError(
            f"Can't downgrade: {n} reminder decisions and schedules (deleted ones included) "
            "exist. Remove them first."
        )
    op.drop_table(SCHEDULES)
    op.drop_table(STATES)
