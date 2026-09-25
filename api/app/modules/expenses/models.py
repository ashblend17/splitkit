import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import CHAR, BigInteger, CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, now_default, uuid_pk


class Expense(Base):
    __tablename__ = "expenses"
    __table_args__ = (
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        Index(
            "ix_expenses_group_date",
            "group_id",
            text("date DESC"),
            postgresql_where=text("deleted_at IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"))
    description: Mapped[str]
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(CHAR(3))
    payer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    date: Mapped[date]
    category_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("categories.id"))
    notes: Mapped[str | None]
    split_method: Mapped[str]
    """Key of a registered split method. Not a DB enum: new methods are plugins."""
    # Plain FK column with no ORM relationship so the import module stays removable.
    import_batch_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("import_batches.id"), index=True
    )
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    updated_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")
    """Bumped on every change; clients send it back so stale edits get a 409."""

    __mapper_args__ = {"version_id_col": version}

    splits: Mapped[list["ExpenseSplit"]] = relationship(
        back_populates="expense", cascade="all, delete-orphan"
    )


class ExpenseSplit(Base):
    """Each participant's share. A deferred DB trigger checks shares sum to amount_minor."""

    __tablename__ = "expense_splits"
    __table_args__ = (CheckConstraint("share_minor >= 0", name="share_not_negative"),)

    expense_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("expenses.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), primary_key=True, index=True)
    share_minor: Mapped[int] = mapped_column(BigInteger)
    input_value: Mapped[Decimal | None]

    expense: Mapped[Expense] = relationship(back_populates="splits")
