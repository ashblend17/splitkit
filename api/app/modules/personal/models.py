import uuid
from datetime import date, datetime

from sqlalchemy import CHAR, BigInteger, CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class PersonalTransaction(Base):
    __tablename__ = "personal_transactions"
    __table_args__ = (
        CheckConstraint("type IN ('income', 'expense')", name="type"),
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        Index(
            "ix_personal_transactions_user_date",
            "user_id",
            text("date DESC"),
            postgresql_where=text("deleted_at IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    type: Mapped[str]
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    category_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("categories.id"))
    date: Mapped[date]
    description: Mapped[str]
    notes: Mapped[str | None]
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}
