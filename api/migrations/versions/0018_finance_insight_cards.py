"""finance insight cards: savings rate, needs and wants

Two default cards for Personal's Insights, from the finance revamp (Phase 6): the savings rate
(income less spending, refunds netted) and spending split into needs and wants by each
category's `kind` (migration 0013). Appended after 0011's cards, since a default card's id
comes from its position. People who saved their own layout find them under Edit layout.

Migrations don't write the sync change log, so devices only see the new default layout after
`python -m app.recover reset-stream global` at deploy (if 0013 deploys with it, one reset of
`global` covers both).

Downgrading deletes the two default cards and any card people saved with these sources, which
older servers can't draw. Reset `global` again, and `user:<id>` for each person whose layout lost
a card (or `--all`), so devices drop them too.

Revision ID: 0018_finance_insight_cards
Revises: 0017_personal_reminders
Create Date: 2026-10-18
"""

import json
import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0018_finance_insight_cards"
down_revision: str | Sequence[str] | None = "0017_personal_reminders"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_NAMESPACE = uuid.UUID("5b1e7c1a-5911-4a6b-8e0c-5b117c17a5ed")  # as in 0009, 0011 and the seed

# scope, position, type, title, period, source, params
CARDS = [
    ("personal", 8, "savings_rate", "Savings rate", "this_month", "personal_savings_rate", {}),
    ("personal", 9, "need_vs_want", "Needs and wants", "this_month", "personal_need_want", {}),
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
    conn.execute(
        sa.text(
            "DELETE FROM analytics_configuration "
            "WHERE owner_id IS NOT NULL AND source IN :sources"
        ).bindparams(sa.bindparam("sources", expanding=True)),
        {"sources": [source for *_, source, _params in CARDS]},
    )
