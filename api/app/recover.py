"""Repairs for when validation (python -m app.validate) finds a problem. See validation.md.

    uv run python -m app.recover reset-stream group:<id>   # every device reloads that stream
    uv run python -m app.recover reset-stream --all
    uv run python -m app.recover end-admin-sessions        # close every open view-as session

Nothing here deletes user data. Each command is recorded in audit_logs.
"""

import argparse
import sys
import uuid

from sqlalchemy import select, text, update
from sqlalchemy.orm import Session

from app.core.db import SessionLocal
from app.modules.admin.models import AdminSession, AuditLog
from app.modules.categories.models import Category
from app.modules.groups.models import Group
from app.modules.sync import log
from app.modules.sync.models import ChangeLog, SyncStream
from app.modules.users.models import User


def _root_entries(session: Session, stream: str) -> list[log.Entry]:
    """The full state of the stream's own entity (the group, the profile, or the built-in
    categories), written again so the stream moves forward."""
    kind, _, raw = stream.partition(":")
    if kind == "group":
        obj = session.get(Group, uuid.UUID(raw))
        objs = [obj] if obj else []
    elif kind == "user":
        obj = session.get(User, uuid.UUID(raw))
        objs = [obj] if obj else []
    elif stream == log.GLOBAL:
        objs = list(session.scalars(select(Category).where(Category.owner_id.is_(None))))
    else:
        raise ValueError(f"Not a stream: {stream}")
    if not objs:
        raise ValueError(f"{stream} names nothing that exists")
    return [e for o in objs for e in log.entries_for(session, o) if e.stream == stream]


def reset_stream(session: Session, stream: str) -> int:
    """Makes every device reload `stream` from a snapshot on its next sync, so they end up with
    exactly what the tables hold. Appends one `sync.reset` entry per root entity and moves
    `oldest_seq` up to it: any older cursor is then "too old". Returns the new head."""
    entries = _root_entries(session, stream)
    head = log.bump(session, stream, len(entries))
    for i, e in enumerate(entries):
        session.add(
            ChangeLog(
                stream_id=stream,
                seq=head - len(entries) + 1 + i,
                action="sync.reset",
                entity=e.entity,
                entity_id=e.entity_id,
                op=e.op,
                version=e.version,
                data=e.data,
            )
        )
    session.execute(update(SyncStream).where(SyncStream.id == stream).values(oldest_seq=head))
    session.add(
        AuditLog(
            action="sync.reset",
            entity="sync_stream",
            entity_id=None,
            diff_json={"stream": stream, "head_seq": head},
        )
    )
    return head


def all_streams(session: Session) -> list[str]:
    groups = [log.group_stream(g) for g in session.scalars(select(Group.id))]
    users = [
        log.user_stream(u) for u in session.scalars(select(User.id).where(User.email.isnot(None)))
    ]
    return [log.GLOBAL, *sorted(users), *sorted(groups)]


def end_admin_sessions(session: Session) -> int:
    ids = list(session.scalars(select(AdminSession.id).where(AdminSession.ended_at.is_(None))))
    if ids:
        session.execute(text("UPDATE admin_sessions SET ended_at = now() WHERE ended_at IS NULL"))
        session.add(
            AuditLog(
                action="admin.sessions_end_all",
                entity="admin_session",
                entity_id=None,
                diff_json={"count": len(ids)},
            )
        )
    return len(ids)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.recover", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    reset = sub.add_parser("reset-stream", help="make every device reload a stream")
    reset.add_argument("stream", nargs="?", help="global, user:<id> or group:<id>")
    reset.add_argument("--all", action="store_true", help="every stream")
    sub.add_parser("end-admin-sessions", help="close every open view-as session")
    args = parser.parse_args(argv)

    with SessionLocal.begin() as session:
        if args.command == "reset-stream":
            if bool(args.stream) == args.all:
                parser.error("give a stream or --all")
            streams = all_streams(session) if args.all else [args.stream]
            for s in streams:
                print(f"{s}: devices reload from seq {reset_stream(session, s)}")
        else:
            print(f"Ended {end_admin_sessions(session)} open view-as session(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
