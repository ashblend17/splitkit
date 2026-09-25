import re
import uuid

from fastapi import APIRouter, Response
from sqlalchemy import exists, select

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import client_id, replayed_create
from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.categories import repository
from app.modules.categories.models import Category
from app.modules.categories.schemas import CategoryIn, CategoryOut
from app.modules.expenses.models import Expense
from app.modules.personal.models import PersonalTransaction

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
def list_categories(actor: CurrentActor, session: DbSession, scope: repository.Scope | None = None):
    return repository.visible(session, actor.user_id, scope)


@router.post("", response_model=CategoryOut, status_code=201)
def create_category(body: CategoryIn, actor: CurrentActor, session: DbSession):
    """Add your own category. Only you see it."""
    actor.require_write()
    replay = replayed_create(session, Category, body.id, lambda c: c.owner_id == actor.user_id)
    if replay is not None:
        return replay
    key = re.sub(r"[^a-z0-9]+", "_", body.label.lower()).strip("_") or "category"
    taken = {c.key for c in repository.visible(session, actor.user_id, None)}
    if any(
        c.label.lower() == body.label.strip().lower()
        for c in repository.visible(session, actor.user_id, None)
    ):
        raise ApiError(
            409, "category_exists", f"You already have a “{body.label.strip()}” category"
        )
    base, n = key, 2
    while key in taken:
        key, n = f"{base}_{n}", n + 1
    category = Category(
        **client_id(body.id),
        key=key,
        label=body.label.strip(),
        icon=body.icon,
        scope=body.scope,
        owner_id=actor.user_id,
        sort=500,
    )
    session.add(category)
    session.flush()
    record(
        session,
        actor,
        "category.create",
        "category",
        category.id,
        diff={"label": category.label},
        obj=category,
    )
    session.commit()
    return category


@router.delete("/{category_id}", status_code=204)
def delete_category(category_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Delete one of your own categories, if nothing uses it."""
    actor.require_write()
    category = session.get(Category, category_id)
    if category is None or category.owner_id != actor.user_id:
        raise not_found("Category")
    in_use = session.scalar(
        select(
            exists().where(Expense.category_id == category_id)
            | exists().where(PersonalTransaction.category_id == category_id)
        )
    )
    if in_use:
        raise ApiError(409, "category_in_use", "This category is in use, so it can't be deleted")
    record(
        session,
        actor,
        "category.delete",
        "category",
        category_id,
        diff={"label": category.label},
        obj=category,
        deleted=True,
    )
    session.delete(category)
    session.commit()
    return Response(status_code=204)
