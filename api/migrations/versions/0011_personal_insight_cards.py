"""personal insight cards: by account, by payment mode, top merchants

Default cards for Personal's Insights, from what entries now say (migration 0010): which
account or card, how it was paid, and who was paid. People who saved their own layout find
them under Edit layout.

Revision ID: 0011_personal_insight_cards
Revises: 0010_sms_and_links
Create Date: 2026-10-13
"""

import json
import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0011_personal_insight_cards"
down_revision: str | Sequence[str] | None = "0010_sms_and_links"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_NAMESPACE = uuid.UUID("5b1e7c1a-5911-4a6b-8e0c-5b117c17a5ed")  # as in 0009 and the seed

# scope, position, type, title, period, source, params
CARDS = [
    ("personal", 5, "spending_by_account", "By account", "this_month", "personal_by_account", {}),
    ("personal", 6, "spending_by_channel", "By payment mode", "this_month", "personal_by_channel", {}),
    ("personal", 7, "top_merchants", "Top merchants", "this_month", "personal_top_merchants", {}),
]


def _id(scope: str, position: int) -> str:
    return str(uuid.uuid5(_NAMESPACE, f"analytics:{scope}:{position}"))


def upgrade() -> None:
    conn = op.get_bind()
    for scope, position, type_, title, period, source, params in CARDS:
        conn.execute(
            sa.text(
                "INSERT INTO analytics_configuration "
                "(id, scope, owner_id, position, type, title, period, source, params_json) "
                "VALUES (:id, :scope, NULL, :position, :type, :title, :period, :source, "
                "CAST(:params AS jsonb)) ON CONFLICT DO NOTHING"
            ),
            {
                "id": _id(scope, position),
                "scope": scope,
                "position": position,
                "type": type_,
                "title": title,
                "period": period,
                "source": source,
                "params": json.dumps(params),
            },
        )


def downgrade() -> None:
    conn = op.get_bind()
    for scope, position, *_ in CARDS:
        conn.execute(
            sa.text("DELETE FROM analytics_configuration WHERE id = :id AND owner_id IS NULL"),
            {"id": _id(scope, position)},
        )
