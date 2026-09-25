import uuid
from datetime import datetime

from sqlalchemy import CHAR, CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class Group(Base):
    __tablename__ = "groups"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str]
    icon: Mapped[str] = mapped_column(server_default="groups")
    """Glyph name from the icon set (travel, rent, food, groups…)."""
    currency: Mapped[str] = mapped_column(CHAR(3), server_default="INR")
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    archived_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}


class GroupMember(Base):
    __tablename__ = "group_members"
    __table_args__ = (CheckConstraint("role IN ('owner', 'member')", name="role"),)

    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), primary_key=True, index=True)
    role: Mapped[str] = mapped_column(server_default="member")
    joined_at: Mapped[datetime] = now_default()
    left_at: Mapped[datetime | None]
    placeholder_name: Mapped[str | None]
    """The name this person had before being linked to an account, e.g. "Kabir M." from Tricount."""


class ActivityEvent(Base):
    """Append-only feed of group writes. The V2 notifier reads from here."""

    __tablename__ = "activity_events"
    __table_args__ = (Index("ix_activity_events_group_at", "group_id", text("at DESC")),)

    id: Mapped[uuid.UUID] = uuid_pk()
    group_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("groups.id"))
    actor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    type: Mapped[str]
    entity: Mapped[str]
    entity_id: Mapped[uuid.UUID]
    at: Mapped[datetime] = now_default()
