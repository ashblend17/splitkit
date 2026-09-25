import uuid
from typing import Literal

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.modules.categories.models import Category

Scope = Literal["group", "personal"]


def visible(session: Session, user_id: uuid.UUID, scope: Scope | None) -> list[Category]:
    """System categories plus the user's own, in display order."""
    query = select(Category).where(or_(Category.owner_id.is_(None), Category.owner_id == user_id))
    if scope is not None:
        query = query.where(Category.scope.in_([scope, "all"]))
    return list(session.scalars(query.order_by(Category.sort, Category.label)))


def get_visible(
    session: Session, category_id: uuid.UUID, user_id: uuid.UUID, scope: Scope
) -> Category | None:
    category = session.get(Category, category_id)
    if (
        category is None
        or category.owner_id not in (None, user_id)
        or category.scope not in (scope, "all")
    ):
        return None
    return category
