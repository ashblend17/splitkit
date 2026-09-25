import uuid
from collections.abc import Iterable

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.users.models import User


def get_by_email(session: Session, email: str) -> User | None:
    return session.scalar(select(User).where(func.lower(User.email) == email.lower()))


def get_many(session: Session, ids: Iterable[uuid.UUID]) -> dict[uuid.UUID, User]:
    ids = set(ids)
    if not ids:
        return {}
    return {u.id: u for u in session.scalars(select(User).where(User.id.in_(ids)))}
