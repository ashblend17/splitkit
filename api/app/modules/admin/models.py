import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class AdminSession(Base):
    __tablename__ = "admin_sessions"
    __table_args__ = (CheckConstraint("mode IN ('read_only', 'edit')", name="mode"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    admin_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    target_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    mode: Mapped[str] = mapped_column(server_default="read_only")
    started_at: Mapped[datetime] = now_default()
    ended_at: Mapped[datetime | None]


class AuditLog(Base):
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_audit_logs_at", text("at DESC")),
        Index("ix_audit_logs_entity", "entity", "entity_id"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    actor_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    """NULL for system actors such as the importer."""
    acting_as_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    action: Mapped[str]
    entity: Mapped[str]
    entity_id: Mapped[uuid.UUID | None]
    diff_json: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
    at: Mapped[datetime] = now_default()
