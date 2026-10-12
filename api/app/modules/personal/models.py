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
        CheckConstraint("source IN ('manual', 'sms')", name="source"),
        CheckConstraint(
            "channel IN ('upi', 'card', 'bank', 'atm', 'cash', 'other')", name="channel"
        ),
        CheckConstraint("expense_id IS NULL OR settlement_id IS NULL", name="one_link"),
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
    channel: Mapped[str | None]
    """How it was paid: upi, card, bank (transfer), atm, cash or other."""
    merchant: Mapped[str | None]
    """Who was paid (or paid you), as the bank named them. The app learns categories by it."""
    account: Mapped[str | None]
    """The account or card it went through, as the app labels it ("HDFC ··4821")."""
    # Where it came from. Set when it's made, never edited: a bank SMS read on your phone (the
    # message itself stays there), its reference number and the balance it reported.
    source: Mapped[str] = mapped_column(server_default="manual")
    reference: Mapped[str | None]
    balance_minor: Mapped[int | None] = mapped_column(BigInteger)
    sms_at: Mapped[datetime | None]
    reviewed: Mapped[bool] = mapped_column(server_default=text("true"))
    """False for an entry the app added from a bank SMS that you haven't looked at yet."""
    # What this spend became in Split, seen only by you. While the expense or payment is live
    # in a group you're still in, the entry isn't counted in your totals: your share of the
    # expense counts as group spending, and a payment isn't spending at all.
    expense_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("expenses.id"))
    settlement_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("settlements.id"))
    acting_admin_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    deleted_at: Mapped[datetime | None]
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}
