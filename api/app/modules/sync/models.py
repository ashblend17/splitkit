import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, SmallInteger
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default


class SyncStream(Base):
    """One ordered log: `group:<id>`, `user:<id>` or `global`. Created on its first change."""

    __tablename__ = "sync_streams"

    id: Mapped[str] = mapped_column(primary_key=True)
    head_seq: Mapped[int] = mapped_column(BigInteger, server_default="0")
    """Seq of the newest change. Bumped under a row lock: gap-free, and committed in order."""
    oldest_seq: Mapped[int] = mapped_column(BigInteger, server_default="0")
    """Changes after this seq are kept. A cursor below it must reload from a snapshot."""


class ChangeLog(Base):
    """What a client needs to catch up: the full state of one entity after a change, or a
    tombstone. Kept separate from audit_logs, which is permanent and holds before/after."""

    __tablename__ = "change_log"
    __table_args__ = (CheckConstraint("op IN ('upsert', 'delete')", name="op"),)

    stream_id: Mapped[str] = mapped_column(ForeignKey("sync_streams.id"), primary_key=True)
    seq: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    action: Mapped[str]
    """Domain event, e.g. expense.update or member.leave."""
    entity: Mapped[str]
    entity_id: Mapped[uuid.UUID]
    op: Mapped[str]
    version: Mapped[int | None]
    data: Mapped[dict[str, Any] | None]
    """Full state after the change. None for a tombstone."""
    actor_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    schema_version: Mapped[int] = mapped_column(SmallInteger, server_default="1")
    at: Mapped[datetime] = now_default()
