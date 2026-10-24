"""reference data

The system categories and the default dashboards came only from the demo seed, which refuses
to run in production, so a production database had no categories to pick and no analytics
cards. They are added here with the seed's ids (uuid5 in its namespace), so reseeding a dev
database replaces them in place.

The trend cards are renamed "Spending over time" (from "Monthly spending" and "Spending per
day"): their bars are days, weeks, months or years depending on the period.

Revision ID: 0009_reference_data
Revises: 0008_tricount_sync
Create Date: 2026-10-11
"""

import json
import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0009_reference_data"
down_revision: str | Sequence[str] | None = "0008_tricount_sync"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# app.seed.loader._NAMESPACE; copied so this migration never changes with the app.
_NAMESPACE = uuid.UUID("5b1e7c1a-5911-4a6b-8e0c-5b117c17a5ed")

# key, label, icon, scope, sort
CATEGORIES = [
    ("food", "Food", "food", "all", 10),
    ("transport", "Transport", "transport", "all", 20),
    ("shopping", "Shopping", "shopping", "all", 30),
    ("entertainment", "Fun", "entertainment", "all", 40),
    ("travel", "Travel", "travel", "group", 50),
    ("stay", "Stay", "rent", "group", 60),
    ("rent", "Rent", "rent", "all", 70),
    ("bills", "Bills", "bills", "all", 80),
    ("health", "Health", "health", "personal", 90),
    ("income", "Income", "income", "personal", 100),
    ("other", "Other", "other", "all", 999),
]

# scope, position, type, title, period, source, params
DASHBOARDS = [
    ("personal", 1, "spending_trend", "Spending over time", "last_6_months", "personal_monthly", {"bucket": "month"}),
    ("personal", 2, "spending_by_category", "Spending by category", "this_month", "personal_by_category", {}),
    ("personal", 3, "personal_vs_group", "Personal vs group", "this_month", "scope_split", {}),
    ("personal", 4, "average_daily", "Average per day", "this_month", "personal_daily_avg", {"compare": "previous_month"}),
    ("group", 1, "total_spend", "Total group spending", "all_time", "group_total", {}),
    ("group", 2, "spending_trend", "Spending over time", "all_time", "group_daily", {"bucket": "day"}),
    ("group", 3, "spending_by_category", "By category", "all_time", "group_by_category", {}),
    ("group", 4, "paid_by_member", "Who paid", "all_time", "group_paid_by", {}),
]


def _id(kind: str, key: str) -> str:
    return str(uuid.uuid5(_NAMESPACE, f"{kind}:{key}"))


def upgrade() -> None:
    conn = op.get_bind()
    for key, label, icon, scope, sort in CATEGORIES:
        # A system category with this key may already exist (a seeded database): keep it.
        conn.execute(
            sa.text(
                "INSERT INTO categories (id, key, label, icon, scope, sort) "
                "VALUES (:id, :key, :label, :icon, :scope, :sort) ON CONFLICT DO NOTHING"
            ),
            {"id": _id("category", key), "key": key, "label": label, "icon": icon, "scope": scope, "sort": sort},
        )
    for scope in ("personal", "group"):
        has_defaults = conn.scalar(
            sa.text("SELECT 1 FROM analytics_configuration WHERE scope = :s AND owner_id IS NULL LIMIT 1"),
            {"s": scope},
        )
        if has_defaults:
            continue
        for s, position, type_, title, period, source, params in DASHBOARDS:
            if s != scope:
                continue
            conn.execute(
                sa.text(
                    "INSERT INTO analytics_configuration "
                    "(id, scope, owner_id, position, type, title, period, source, params_json) "
                    "VALUES (:id, :scope, NULL, :position, :type, :title, :period, :source, "
                    "CAST(:params AS jsonb)) ON CONFLICT DO NOTHING"
                ),
                {
                    "id": _id("analytics", f"{scope}:{position}"),
                    "scope": scope,
                    "position": position,
                    "type": type_,
                    "title": title,
                    "period": period,
                    "source": source,
                    "params": json.dumps(params),
                },
            )
    # Defaults and the layouts people saved from them.
    op.execute(
        "UPDATE analytics_configuration SET title = 'Spending over time' "
        "WHERE (source = 'personal_monthly' AND title IN ('Monthly spending', 'Spending')) "
        "OR (source = 'group_daily' AND title = 'Spending per day')"
    )


def downgrade() -> None:
    # The reference data stays: entries may point at the categories.
    op.execute(
        "UPDATE analytics_configuration SET title = 'Monthly spending' "
        "WHERE source = 'personal_monthly' AND title = 'Spending over time'"
    )
    op.execute(
        "UPDATE analytics_configuration SET title = 'Spending per day' "
        "WHERE source = 'group_daily' AND title = 'Spending over time'"
    )
