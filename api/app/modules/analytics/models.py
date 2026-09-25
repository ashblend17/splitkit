import uuid
from typing import Any

from sqlalchemy import CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, uuid_pk


class AnalyticsConfiguration(Base):
    """One dashboard card. Rows with owner_id NULL are the defaults for their scope.
    The client loops over rows in `position` order and picks a renderer by `type`."""

    __tablename__ = "analytics_configuration"
    __table_args__ = (
        CheckConstraint("scope IN ('personal', 'group')", name="scope"),
        Index("ix_analytics_configuration_scope_owner", "scope", "owner_id", "position"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    scope: Mapped[str]
    owner_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    position: Mapped[int]
    type: Mapped[str]
    title: Mapped[str]
    period: Mapped[str]
    source: Mapped[str]
    params_json: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
