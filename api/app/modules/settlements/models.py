import uuid
from datetime import date, datetime

from sqlalchemy import CHAR, BigInteger, CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class Settlement(Base):
    """A payment between two members. Its own record; it never modifies an expense."""

    __tablename__ = "settlements"
    __table_args__ = (
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        CheckConstraint("from_user <> to_user", name="different_people"),
        CheckConstraint("method IN ('upi', 'cash', 'bank', 'other')", name="method"),
        Index("ix_settlements_group", "group_id", postgresql_where=text("deleted_at IS NULL")),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"))
    from_user: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    to_user: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    date: Mapped[date]
    method: Mapped[str]
    note: Mapped[str | None]
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}
