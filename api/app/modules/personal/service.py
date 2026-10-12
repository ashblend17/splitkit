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
from app.modules.expenses.models import Expense
from app.modules.groups import repository as groups
from app.modules.personal import repository as repo
from app.modules.personal.models import PersonalTransaction
from app.modules.personal.schemas import (
    AccountOut,
    CategoryTotal,
    PersonalListOut,
    PersonalSummaryOut,
    PersonalTxnIn,
    PersonalTxnOut,
)
from app.modules.settlements.models import Settlement

# What an update may change besides the basics. A field the body leaves out keeps its value,
# so an older app that doesn't know them can't wipe a link.
EDITABLE = ("channel", "merchant", "account", "expense_id", "settlement_id", "reviewed")


def _categories(session: Session, rows: list[PersonalTransaction]) -> dict[uuid.UUID, Category]:
    ids = {r.category_id for r in rows if r.category_id}
    return {c.id: c for c in (session.get(Category, i) for i in ids) if c}


def _out(
    t: PersonalTransaction, cats: dict[uuid.UUID, Category], covered: set[uuid.UUID]
) -> PersonalTxnOut:
    c = cats.get(t.category_id) if t.category_id else None
    return PersonalTxnOut(
        id=t.id,
        type=t.type,
        amount_minor=t.amount_minor,
        currency=t.currency,
        description=t.description,
        date=t.date,
        notes=t.notes,
        channel=t.channel,
        merchant=t.merchant,
        account=t.account,
        source=t.source,
        reference=t.reference,
        balance_minor=t.balance_minor,
        sms_at=t.sms_at,
        reviewed=t.reviewed,
        expense_id=t.expense_id,
        settlement_id=t.settlement_id,
        counted=t.id not in covered,
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
    account: str | None = None,
    channel: str | None = None,
    source: str | None = None,
    reviewed: bool | None = None,
) -> PersonalListOut:
    rows = repo.query(
        session,
        actor.user_id,
        start=start,
        end=end,
        type=type,
        category_keys=category_keys,
        deleted=deleted,
        account=account,
        channel=channel,
        source=source,
        reviewed=reviewed,
    )
    page = rows[offset : offset + limit]
    cats = _categories(session, page)
    covered = repo.covered_ids(session, actor.user_id)
    # Totals can't add up different currencies: entries made before you changed your currency
    # are listed but not counted. Nor are entries that became a group expense or payment.
    counted = [t for t in rows if t.currency == actor.user.currency and t.id not in covered]
    return PersonalListOut(
        items=[_out(t, cats, covered) for t in page],
        spent_minor=sum(t.amount_minor for t in counted if t.type == "expense"),
        income_minor=sum(t.amount_minor for t in counted if t.type == "income"),
        count=len(rows),
    )


def summary(session: Session, actor: Actor, month: date) -> PersonalSummaryOut:
    start, end = month.replace(day=1), month_end(month)
    currency = actor.user.currency
    covered = repo.covered_ids(session, actor.user_id)
    rows = [
        t
        for t in repo.query(session, actor.user_id, start=start, end=end)
        if t.currency == currency and t.id not in covered
    ]
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
        currency=currency,
        spent_minor=spent,
        income_minor=income,
        left_over_minor=income - spent,
        group_share_minor=repo.group_share(session, actor.user_id, start, end, currency),
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


def _in_group(session: Session, group_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    member = groups.membership(session, group_id, user_id)
    return member is not None and member.left_at is None


def _check_links(
    session: Session,
    actor: Actor,
    type: str,
    expense_id: uuid.UUID | None,
    settlement_id: uuid.UUID | None,
) -> None:
    """A spend can become a split you paid for, or a payment you made; income can be a
    payment you received. Only in groups you're in, and only one link at a time."""
    if expense_id and settlement_id:
        raise ApiError(422, "link_invalid", "An entry can be a split or a payment, not both")
    if expense_id:
        e = session.get(Expense, expense_id)
        live = e is not None and e.deleted_at is None
        if not live or not _in_group(session, e.group_id, actor.user_id):
            raise ApiError(422, "unknown_expense", "That split isn't available")
        if type != "expense":
            raise ApiError(422, "link_invalid", "Only spending can be split")
        if e.payer_id != actor.user_id:
            raise ApiError(422, "link_invalid", "Link a split you paid for")
    if settlement_id:
        p = session.get(Settlement, settlement_id)
        live = p is not None and p.deleted_at is None
        if not live or not _in_group(session, p.group_id, actor.user_id):
            raise ApiError(422, "unknown_payment", "That payment isn't available")
        if type == "expense" and p.from_user != actor.user_id:
            raise ApiError(422, "link_invalid", "Link a payment you made")
        if type == "income" and p.to_user != actor.user_id:
            raise ApiError(422, "link_invalid", "Link a payment you received")


def _text(value: str | None) -> str | None:
    """Trimmed, and blank as none."""
    return (value or "").strip() or None


def get_transaction(session: Session, actor: Actor, txn_id: uuid.UUID) -> PersonalTxnOut:
    t = _load(session, actor, txn_id)
    return _out(t, _categories(session, [t]), repo.covered_ids(session, actor.user_id))


def accounts(session: Session, actor: Actor) -> list[AccountOut]:
    """Each account or card your entries went through, most recently used first, with the
    latest balance its bank reported."""
    by_account: dict[str, list[PersonalTransaction]] = defaultdict(list)
    for t in repo.query(session, actor.user_id):
        if t.account:
            by_account[t.account].append(t)

    def when(t: PersonalTransaction) -> tuple[datetime, datetime, str]:
        return (t.sms_at or t.created_at, t.created_at, str(t.id))

    out = []
    for name, rows in by_account.items():
        latest = max(rows, key=when)
        reported = max((t for t in rows if t.balance_minor is not None), key=when, default=None)
        out.append(
            (
                when(latest),
                AccountOut(
                    account=name,
                    currency=latest.currency,
                    balance_minor=reported.balance_minor if reported else None,
                    balance_at=(reported.sms_at or reported.created_at) if reported else None,
                    count=len(rows),
                ),
            )
        )
    out.sort(key=lambda o: o[1].account)
    out.sort(key=lambda o: o[0], reverse=True)
    return [a for _, a in out]


def create_transaction(session: Session, actor: Actor, body: PersonalTxnIn) -> PersonalTxnOut:
    actor.require_write()
    replay = replayed_create(
        session, PersonalTransaction, body.id, lambda t: t.user_id == actor.user_id
    )
    if replay is not None:
        return get_transaction(session, actor, replay.id)
    _check_category(session, actor, body.category_id)
    _check_links(session, actor, body.type, body.expense_id, body.settlement_id)
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
        channel=body.channel,
        merchant=_text(body.merchant),
        account=_text(body.account),
        source=body.source,
        reference=_text(body.reference),
        balance_minor=body.balance_minor,
        sms_at=body.sms_at,
        reviewed=body.reviewed,
        expense_id=body.expense_id,
        settlement_id=body.settlement_id,
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
        diff={"type": t.type, "amount_minor": t.amount_minor, "source": t.source},
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
    given = {k: getattr(body, k) for k in EDITABLE if k in body.model_fields_set}
    for k in ("merchant", "account"):
        if k in given:
            given[k] = _text(given[k])
    expense_id = given.get("expense_id", t.expense_id)
    settlement_id = given.get("settlement_id", t.settlement_id)
    # Checked when the link (or what it links) changes, so a link whose expense was deleted
    # since doesn't block other edits.
    if (expense_id, settlement_id, body.type) != (t.expense_id, t.settlement_id, t.type):
        _check_links(session, actor, body.type, expense_id, settlement_id)

    def state() -> dict:
        return {
            "type": t.type,
            "amount_minor": t.amount_minor,
            "description": t.description,
            "date": t.date.isoformat(),
            "category_id": str(t.category_id) if t.category_id else None,
            "notes": t.notes,
            "channel": t.channel,
            "merchant": t.merchant,
            "account": t.account,
            "expense_id": str(t.expense_id) if t.expense_id else None,
            "settlement_id": str(t.settlement_id) if t.settlement_id else None,
            "reviewed": t.reviewed,
        }

    before = state()
    t.type, t.amount_minor, t.description = body.type, body.amount_minor, body.description.strip()
    t.date, t.category_id, t.notes, t.acting_admin_id = (
        body.date,
        body.category_id,
        body.notes,
        actor.admin_id,
    )
    for k, v in given.items():
        setattr(t, k, v)
    after = state()
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
        t.acting_admin_id = actor.admin_id
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
