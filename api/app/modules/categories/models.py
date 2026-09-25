import uuid

from sqlalchemy import CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, uuid_pk


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
