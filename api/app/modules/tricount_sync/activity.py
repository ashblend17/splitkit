"""Notes when people use the app, so the worker pulls their linked groups from Tricount every
minute while they're around (and not at all for groups nobody is looking at).

An ASGI middleware: for a signed-in request it sets `last_active_at` on the linked groups of
that person, at most once a minute per person (remembered in memory), in one UPDATE.
"""

import logging
import time

from sqlalchemy import text
from starlette.concurrency import run_in_threadpool
from starlette.types import ASGIApp, Receive, Scope, Send

from app.core.db import SessionLocal
from app.modules.auth.tokens import decode_access_token

log = logging.getLogger("tricount_sync")

EVERY_SECONDS = 60


def touch(user_id: str) -> None:
    with SessionLocal.begin() as session:
        session.execute(
            text(
                """
                UPDATE tricount_links SET last_active_at = now()
                WHERE group_id IN (
                    SELECT group_id FROM group_members WHERE user_id = :u AND left_at IS NULL
                )
                """
            ),
            {"u": user_id},
        )


class ActivityMiddleware:
    def __init__(self, app: ASGIApp):
        self.app = app
        self.seen: dict[str, float] = {}

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http":
            auth = dict(scope.get("headers") or []).get(b"authorization", b"")
            if auth[:7].lower() == b"bearer ":
                user_id = decode_access_token(auth[7:].decode("latin-1"))
                now = time.monotonic()
                if user_id and now - self.seen.get(str(user_id), -EVERY_SECONDS) >= EVERY_SECONDS:
                    self.seen[str(user_id)] = now
                    try:
                        await run_in_threadpool(touch, str(user_id))
                    except Exception:  # noqa: BLE001 (never fail a request over this)
                        log.warning("Couldn't note activity for %s", user_id, exc_info=True)
        await self.app(scope, receive, send)
