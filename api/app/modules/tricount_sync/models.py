import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    CHAR,
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Index,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class TricountDevice(Base):
    """The one anonymous Tricount "device" this server registers as. Every linked tricount
    is followed by it. Keep the row: losing it means joining every tricount again."""

    __tablename__ = "tricount_devices"

    id: Mapped[int] = mapped_column(primary_key=True)
    """Always 1."""
    app_id: Mapped[str]
    public_key_pem: Mapped[str]
    token: Mapped[str | None]
    tricount_user_id: Mapped[int | None] = mapped_column(BigInteger)
    created_at: Mapped[datetime] = now_default()


class TricountLink(Base):
    """A group kept in sync with a tricount."""

    __tablename__ = "tricount_links"
    __table_args__ = (
        CheckConstraint("state IN ('syncing', 'ok', 'error')", name="state"),
        UniqueConstraint("registry_id"),
    )

    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"), primary_key=True)
    public_token: Mapped[str]
    """The tXXXX of the share link. Anyone holding it can read and change the tricount."""
    registry_id: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    title_base: Mapped[str | None]
    """The group name both sides last agreed on, to tell which side renamed it."""
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()

    state: Mapped[str] = mapped_column(server_default="syncing")
    last_error: Mapped[str | None]
    warnings: Mapped[list[Any]] = mapped_column(JSONB, server_default=text("'[]'::jsonb"))
    """What the last pass couldn't carry over, in human words (income entries, …)."""
    last_synced_at: Mapped[datetime | None]
    failures: Mapped[int] = mapped_column(server_default="0")
    next_attempt_at: Mapped[datetime | None]
    """Set after a failure: no automatic pass before then (exponential backoff)."""
    lease_until: Mapped[datetime | None]
    """A pass in progress holds the link until then, so two processes never run one at once."""
    seen_seq: Mapped[int] = mapped_column(BigInteger, server_default="0")
    """The group stream's head after the last pass. A higher head means Splitkit changed."""
    last_active_at: Mapped[datetime | None]
    """When a member of the group last used the app (pulls run only while it's recent)."""


class TricountMember(Base):
    """A tricount member and the Splitkit person they are."""

    __tablename__ = "tricount_members"
    __table_args__ = (UniqueConstraint("group_id", "user_id"),)

    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tricount_links.group_id", ondelete="CASCADE"), primary_key=True
    )
    membership_uuid: Mapped[str] = mapped_column(primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))


class TricountEntry(Base):
    """An expense or payment and the Tricount entry it is."""

    __tablename__ = "tricount_entries"
    __table_args__ = (
        CheckConstraint("entity IN ('expense', 'settlement')", name="entity"),
        CheckConstraint("force IN ('push', 'pull')", name="force"),
        UniqueConstraint("group_id", "entity", "entity_id"),
        Index("ix_tricount_entries_remote", "group_id", "remote_id"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tricount_links.group_id", ondelete="CASCADE")
    )
    entity: Mapped[str]
    entity_id: Mapped[uuid.UUID]
    remote_id: Mapped[int | None] = mapped_column(BigInteger)
    """None while the entry exists only in Splitkit (deleted in Tricount, or not sent yet)."""
    base: Mapped[dict[str, Any] | None]
    """The entry as both sides last agreed on it (see mapping.py), or None if they agreed it
    was deleted."""
    generation: Mapped[int] = mapped_column(server_default="0")
    """Bumped each time the entry is created in Tricount again (after a delete and restore),
    so its creation id is new."""
    force: Mapped[str | None]
    """Set when someone resolves a conflict: the next pass sends Splitkit's version ("push")
    or takes Tricount's ("pull") whatever the base says, then clears it."""


class TricountConflict(Base):
    """An entry changed on both sides since they last agreed. Someone in the group picks."""

    __tablename__ = "tricount_conflicts"
    __table_args__ = (
        CheckConstraint("resolution IN ('splitkit', 'tricount')", name="resolution"),
        Index(
            "ix_tricount_conflicts_open",
            "entry_id",
            unique=True,
            postgresql_where=text("resolved_at IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tricount_links.group_id", ondelete="CASCADE"), index=True
    )
    entry_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tricount_entries.id", ondelete="CASCADE")
    )
    local: Mapped[dict[str, Any] | None]
    """Splitkit's version (mapping.py form), or None if it was deleted in Splitkit."""
    remote: Mapped[dict[str, Any] | None]
    """Tricount's version, or None if it was deleted in Tricount."""
    created_at: Mapped[datetime] = now_default()
    resolved_at: Mapped[datetime | None]
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    resolution: Mapped[str | None]
