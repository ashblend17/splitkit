import uuid
from collections import defaultdict
from datetime import UTC, date, datetime

from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.analytics.periods import month_end
from app.modules.auth.deps import Actor
from app.modules.categories import repository as categories
from app.modules.categories.models import Category
from app.modules.categories.schemas import CategoryOut
from app.modules.personal import repository as repo
from app.modules.personal.models import PersonalTransaction
from app.modules.personal.schemas import (
    CategoryTotal,
    PersonalListOut,
    PersonalSummaryOut,
    PersonalTxnIn,
    PersonalTxnOut,
)


def _categories(session: Session, rows: list[PersonalTransaction]) -> dict[uuid.UUID, Category]:
    ids = {r.category_id for r in rows if r.category_id}
    return {c.id: c for c in (session.get(Category, i) for i in ids) if c}


def _out(t: PersonalTransaction, cats: dict[uuid.UUID, Category]) -> PersonalTxnOut:
    c = cats.get(t.category_id) if t.category_id else None
    return PersonalTxnOut(
        id=t.id,
        type=t.type,
        amount_minor=t.amount_minor,
        currency=t.currency,
        description=t.description,
        date=t.date,
        notes=t.notes,
        acting_admin_id=t.acting_admin_id,
        created_at=t.created_at,
        deleted_at=t.deleted_at,
        version=t.version,
        category=CategoryOut.model_validate(c) if c else None,
    )


def list_transactions(
    session: Session,
    actor: Actor,
    *,
    start: date | None,
    end: date | None,
    type: str | None,
    category_keys: list[str] | None,
    deleted: bool,
    limit: int,
    offset: int,
) -> PersonalListOut:
    rows = repo.query(
        session,
        actor.user_id,
        start=start,
        end=end,
        type=type,
        category_keys=category_keys,
        deleted=deleted,
    )
    page = rows[offset : offset + limit]
    cats = _categories(session, page)
    return PersonalListOut(
        items=[_out(t, cats) for t in page],
        spent_minor=sum(t.amount_minor for t in rows if t.type == "expense"),
        income_minor=sum(t.amount_minor for t in rows if t.type == "income"),
        count=len(rows),
    )


def summary(session: Session, actor: Actor, month: date) -> PersonalSummaryOut:
    start, end = month.replace(day=1), month_end(month)
    rows = repo.query(session, actor.user_id, start=start, end=end)
    cats = _categories(session, rows)
    spent = sum(t.amount_minor for t in rows if t.type == "expense")
    income = sum(t.amount_minor for t in rows if t.type == "income")
    by_cat: dict[uuid.UUID | None, int] = defaultdict(int)
    for t in rows:
        if t.type == "expense":
            by_cat[t.category_id] += t.amount_minor
    totals = [
        CategoryTotal(
            category=CategoryOut.model_validate(cats[k]) if k in cats else None,
            label=cats[k].label if k in cats else "Uncategorised",
            amount_minor=v,
        )
        for k, v in by_cat.items()
    ]
    totals.sort(key=lambda t: (-t.amount_minor, t.label))
    label = f"{start:%B}" if start.year == date.today().year else f"{start:%B %Y}"
    return PersonalSummaryOut(
        month=f"{start:%Y-%m}",
        month_label=label,
        currency=actor.user.currency,
        spent_minor=spent,
        income_minor=income,
        left_over_minor=income - spent,
        group_share_minor=repo.group_share(session, actor.user_id, start, end),
        by_category=totals,
    )


def _load(session: Session, actor: Actor, txn_id: uuid.UUID) -> PersonalTransaction:
    t = session.get(PersonalTransaction, txn_id)
    if t is None or t.user_id != actor.user_id:
        raise not_found("Transaction")
    return t


def _check_category(session: Session, actor: Actor, category_id: uuid.UUID | None) -> None:
    if category_id and not categories.get_visible(session, category_id, actor.user_id, "personal"):
        raise ApiError(422, "unknown_category", "That category isn't available")


def get_transaction(session: Session, actor: Actor, txn_id: uuid.UUID) -> PersonalTxnOut:
    t = _load(session, actor, txn_id)
    return _out(t, _categories(session, [t]))


def create_transaction(session: Session, actor: Actor, body: PersonalTxnIn) -> PersonalTxnOut:
    actor.require_write()
    replay = replayed_create(
        session, PersonalTransaction, body.id, lambda t: t.user_id == actor.user_id
    )
    if replay is not None:
        return get_transaction(session, actor, replay.id)
    _check_category(session, actor, body.category_id)
    t = PersonalTransaction(
        **client_id(body.id),
        user_id=actor.user_id,
        type=body.type,
        amount_minor=body.amount_minor,
        currency=actor.user.currency,
        category_id=body.category_id,
        date=body.date,
        description=body.description.strip(),
        notes=body.notes,
        acting_admin_id=actor.admin_id,
    )
    session.add(t)
    session.flush()
    record(
        session,
        actor,
        "personal.create",
        "personal_transaction",
        t.id,
        diff={"type": t.type, "amount_minor": t.amount_minor},
        obj=t,
    )
    session.commit()
    return get_transaction(session, actor, t.id)


def update_transaction(
    session: Session, actor: Actor, txn_id: uuid.UUID, body: PersonalTxnIn
) -> PersonalTxnOut:
    actor.require_write()
    t = _load(session, actor, txn_id)
    if t.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this entry before editing it")
    check_version(t, body.version)
    _check_category(session, actor, body.category_id)
    before = {
        "type": t.type,
        "amount_minor": t.amount_minor,
        "description": t.description,
        "date": t.date.isoformat(),
        "category_id": str(t.category_id) if t.category_id else None,
        "notes": t.notes,
    }
    t.type, t.amount_minor, t.description = body.type, body.amount_minor, body.description.strip()
    t.date, t.category_id, t.notes, t.acting_admin_id = (
        body.date,
        body.category_id,
        body.notes,
        actor.admin_id,
    )
    after = {
        "type": t.type,
        "amount_minor": t.amount_minor,
        "description": t.description,
        "date": t.date.isoformat(),
        "category_id": str(t.category_id) if t.category_id else None,
        "notes": t.notes,
    }
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    record(session, actor, "personal.update", "personal_transaction", t.id, diff=diff, obj=t)
    session.commit()
    return get_transaction(session, actor, t.id)


def set_deleted(
    session: Session, actor: Actor, txn_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalTxnOut:
    actor.require_write()
    t = _load(session, actor, txn_id)
    if (t.deleted_at is not None) != deleted:
        check_version(t, version)
        t.deleted_at = datetime.now(UTC) if deleted else None
        record(
            session,
            actor,
            "personal.delete" if deleted else "personal.restore",
            "personal_transaction",
            t.id,
            obj=t,
        )
        session.commit()
    return get_transaction(session, actor, txn_id)
