import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, Index, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class Category(Base):
    """System categories have owner_id NULL; users can add their own."""

    __tablename__ = "categories"
    __table_args__ = (
        CheckConstraint("scope IN ('group', 'personal', 'all')", name="scope"),
        Index(
            "uq_categories_system_key",
            "key",
            unique=True,
            postgresql_where=text("owner_id IS NULL"),
        ),
        Index(
            "uq_categories_owner_key",
            "owner_id",
            "key",
            unique=True,
            postgresql_where=text("owner_id IS NOT NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    key: Mapped[str]
    label: Mapped[str]
    icon: Mapped[str]
    scope: Mapped[str]
    owner_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    sort: Mapped[int] = mapped_column(server_default="0")


class CategoryRule(Base):
    """A category you chose for a merchant (or, without one, a description), learned from your
    own entries and splits (rules.py) so the app suggests it next time. The device matches
    patterns loosely (app/lib/core/categorise/), so "ZOMATO LIMITED" also covers "Zomato"."""

    __tablename__ = "category_rules"
    __table_args__ = (UniqueConstraint("user_id", "income", "pattern"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    """rules.rule_id(): the device makes the same one, so its own copy of a rule it just
    learned is replaced by the server's."""
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    pattern: Mapped[str]
    """Lowercase, with spaces collapsed."""
    income: Mapped[bool]
    """Rules for money received and for spending are kept apart: you pay a friend and get paid
    by them under different categories."""
    category_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("categories.id"))
    updated_at: Mapped[datetime] = now_default()
    """When it was last chosen. Of the rules that match, the newest wins."""
