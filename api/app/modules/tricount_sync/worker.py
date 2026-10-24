"""Runs sync passes when they're due:

- right away when someone changed the group here (its sync stream has entries past
  `seen_seq` not written by the sync itself), so writes reach Tricount within seconds;
- every `tricount_poll_seconds` while someone in the group is using the app
  (`last_active_at`, set by ActivityMiddleware), to pick up changes made in Tricount;
- never before `next_attempt_at` after a failure (backoff).

Run it as its own process: `python -m app.modules.tricount_sync` (docker compose service
`tricount`), or one round with `--once`. Several processes can run at once: a link is leased
for the length of a pass.
"""

import logging
import time
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import text

import app.models  # noqa: F401  (every table, so cross-module foreign keys resolve)
from app.core.config import get_settings
from app.core.db import SessionLocal
from app.modules.tricount_sync import reconcile

log = logging.getLogger("tricount_sync")

TICK_SECONDS = 3


def due(now: datetime | None = None) -> list[uuid.UUID]:
    settings = get_settings()
    now = now or datetime.now(UTC)
    with SessionLocal() as session:
        rows = session.execute(
            text(
                """
                SELECT l.group_id FROM tricount_links l
                WHERE (l.lease_until IS NULL OR l.lease_until < :now)
                  AND (l.next_attempt_at IS NULL OR l.next_attempt_at <= :now)
                  AND (
                    l.state = 'syncing'
                    OR l.last_synced_at IS NULL
                    OR EXISTS (
                      -- Changed here since the last pass began (not by the sync itself)
                      SELECT 1 FROM change_log c
                      WHERE c.stream_id = 'group:' || l.group_id::text AND c.seq > l.seen_seq
                        AND c.actor_id IS DISTINCT FROM :system
                    )
                    OR (l.last_active_at >= :active AND l.last_synced_at <= :stale)
                  )
                ORDER BY l.last_synced_at NULLS FIRST
                """
            ),
            {
                "now": now,
                "active": now - timedelta(minutes=settings.tricount_active_minutes),
                "stale": now - timedelta(seconds=settings.tricount_poll_seconds),
                "system": reconcile.SYSTEM_USER_ID,
            },
        )
        return [r[0] for r in rows]


def tick() -> int:
    """One round: a pass for every link that's due. Returns how many ran."""
    ran = 0
    for group_id in due():
        try:
            outcome = reconcile.run(group_id)
            ran += 1
            if outcome.pulled or outcome.pushed or outcome.conflicts:
                log.info(
                    "group %s: %d from Tricount, %d to Tricount, %d conflicts",
                    group_id,
                    outcome.pulled,
                    outcome.pushed,
                    outcome.conflicts,
                )
        except reconcile.Busy:
            continue
        except Exception as e:  # noqa: BLE001 (stored on the link; backoff decides the retry)
            ran += 1
            log.warning("group %s: %s", group_id, reconcile.human_error(e))
    return ran


def loop() -> None:
    log.info("Tricount sync worker started")
    while True:
        try:
            tick()
        except Exception:  # noqa: BLE001 (the database may be restarting; keep going)
            log.exception("Tricount sync round failed")
        time.sleep(TICK_SECONDS)
