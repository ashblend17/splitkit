import uuid
from datetime import datetime

from sqlalchemy import CHAR, CheckConstraint, Index, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class User(Base):
    """An account, or a placeholder person (no email, cannot log in) such as an imported
    Tricount participant who has not been linked to a real account yet."""

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("role IN ('user', 'admin')", name="role"),
        CheckConstraint("password_hash IS NULL OR email IS NOT NULL", name="login_needs_email"),
        Index("uq_users_email_lower", func.lower(text("email")), unique=True),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str]
    email: Mapped[str | None]
    password_hash: Mapped[str | None]
    avatar_url: Mapped[str | None]
    currency: Mapped[str] = mapped_column(CHAR(3), server_default="INR")
    role: Mapped[str] = mapped_column(server_default="user")
    created_at: Mapped[datetime] = now_default()
    version: Mapped[int] = mapped_column(server_default="1")

    __mapper_args__ = {"version_id_col": version}
