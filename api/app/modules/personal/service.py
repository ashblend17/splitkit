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
from app.modules.categories import rules
from app.modules.categories.models import Category
from app.modules.categories.schemas import CategoryOut
from app.modules.expenses.models import Expense
from app.modules.groups import repository as groups
from app.modules.personal import accounts, allocation_plans, contributions, transfers
from app.modules.personal import repository as repo
from app.modules.personal.ledger_rules import INVESTMENT_TYPES, implied_direction
from app.modules.personal.models import PersonalAccount, PersonalHolding, PersonalTransaction
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
EDITABLE = (
    "channel",
    "merchant",
    "account",
    "expense_id",
    "settlement_id",
    "reviewed",
    "account_id",
    "transfer_group_id",
    "refund_of_id",
    "holding_id",
)
# Which other rows an entry points at; checked together by _validate.
LINKS = (
    "account_id",
    "transfer_group_id",
    "refund_of_id",
    "holding_id",
    "expense_id",
    "settlement_id",
)
MOVES = ("transfer", "adjustment")
"""Money moved between accounts or a balance corrected: never income or spending."""

DIRECTION_RULES = {
    "income": "Income is money coming in",
    "expense": "An expense is money going out",
    "refund": "A refund is money coming in",
    "investment_contribution": "Money invested is money going out",
    "investment_withdrawal": "Money taken out of an investment is money coming in",
}


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
        direction=t.direction,
        account_id=t.account_id,
        transfer_group_id=t.transfer_group_id,
        refund_of_id=t.refund_of_id,
        holding_id=t.holding_id,
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


def outs(session: Session, actor: Actor, rows: list[PersonalTransaction]) -> list[PersonalTxnOut]:
    cats = _categories(session, rows)
    covered = repo.covered_ids(session, actor.user_id)
    return [_out(t, cats, covered) for t in rows]


def _spending(rows: list[PersonalTransaction]) -> tuple[int, int, int]:
    """(spent, income, refunds) of counted rows: spent is expenses minus refunds."""
    total = defaultdict(int)
    for t in rows:
        total[t.type] += t.amount_minor
    return total["expense"] - total["refund"], total["income"], total["refund"]


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
    account_id: uuid.UUID | None = None,
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
        account_id=account_id,
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
    spent, income, refunds = _spending(counted)
    return PersonalListOut(
        items=[_out(t, cats, covered) for t in page],
        spent_minor=spent,
        income_minor=income,
        refunds_minor=refunds,
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
    spent, income, refunds = _spending(rows)
    by_cat: dict[uuid.UUID | None, int] = defaultdict(int)
    for t in rows:
        if t.type == "expense":
            by_cat[t.category_id] += t.amount_minor
        elif t.type == "refund":
            by_cat[t.category_id] -= t.amount_minor
    totals = [
        CategoryTotal(
            category=CategoryOut.model_validate(cats[k]) if k in cats else None,
            label=cats[k].label if k in cats else "Uncategorised",
            amount_minor=v,
        )
        for k, v in by_cat.items()
        if v
    ]
    totals.sort(key=lambda t: (-t.amount_minor, t.label))
    label = f"{start:%B}" if start.year == date.today().year else f"{start:%B %Y}"
    return PersonalSummaryOut(
        month=f"{start:%Y-%m}",
        month_label=label,
        currency=currency,
        spent_minor=spent,
        income_minor=income,
        refunds_minor=refunds,
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


def _check_account(session: Session, actor: Actor, account_id: uuid.UUID, currency: str) -> None:
    """For an entry moving into this account (a new one, or one changing account)."""
    a = session.get(PersonalAccount, account_id)
    if a is None or a.user_id != actor.user_id or a.deleted_at is not None:
        raise ApiError(422, "unknown_account", "That account isn't available")
    if a.status == "closed":
        raise ApiError(422, "account_closed", "That account is closed")
    if a.linked_account_id is not None:
        # Its entries count in the account it's linked to, which takes none while closed.
        root = session.get(PersonalAccount, a.linked_account_id)
        if root is not None and root.status == "closed":
            raise ApiError(
                422, "account_closed", f"That account is part of {root.name}, which is closed"
            )
    if a.currency != currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That account is in {a.currency}; this entry is in {currency}",
        )


def _check_holding(session: Session, actor: Actor, holding_id: uuid.UUID, currency: str) -> None:
    h = session.get(PersonalHolding, holding_id)
    if h is None or h.user_id != actor.user_id or h.deleted_at is not None:
        raise ApiError(422, "unknown_holding", "That holding isn't available")
    if h.currency != currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That holding is in {h.currency}; this entry is in {currency}",
        )


def _check_refund(
    session: Session,
    actor: Actor,
    body: PersonalTxnIn,
    refund_of_id: uuid.UUID,
    t: PersonalTransaction | None,
) -> None:
    """The spend must be yours and live when the refund is pointed at it (so one deleted since
    doesn't block other edits), and at least as much as the refund."""
    pointed = t is None or refund_of_id != t.refund_of_id
    original = session.get(PersonalTransaction, refund_of_id)
    if pointed and (
        original is None
        or original.user_id != actor.user_id
        or original.deleted_at is not None
        or original.type != "expense"
    ):
        raise ApiError(422, "unknown_refund_target", "That spend isn't available")
    resized = t is None or pointed or body.amount_minor != t.amount_minor
    if original is not None and resized and body.amount_minor > original.amount_minor:
        raise ApiError(422, "refund_too_large", "A refund can't be more than the spend")


def _validate(
    session: Session,
    actor: Actor,
    body: PersonalTxnIn,
    links: dict[str, uuid.UUID | None],
    t: PersonalTransaction | None,
) -> str:
    """Checks an entry as `body` and `links` (what it points at, stored values filled in for
    any the body left out) would leave it: a new one, or `t`. Returns its direction."""
    kind = body.type
    implied = implied_direction(kind)
    if implied is not None:
        if body.direction not in (None, implied):
            raise ApiError(422, "direction_invalid", DIRECTION_RULES[kind])
        direction = implied
    elif body.direction is not None:
        direction = body.direction
    elif t is not None and t.type == kind:
        direction = t.direction
    else:
        raise ApiError(422, "direction_required", "Say whether money came in or went out")

    if kind in MOVES and body.category_id:
        raise ApiError(
            422,
            "category_not_allowed",
            "Transfers and balance corrections don't have a category",
        )
    if (links["expense_id"] or links["settlement_id"]) and kind not in ("income", "expense"):
        raise ApiError(422, "link_invalid", "Only spending and income can be linked to Split")
    if links["refund_of_id"] and kind != "refund":
        raise ApiError(422, "refund_invalid", "Only a refund can point at a spend")
    if links["transfer_group_id"] and kind != "transfer":
        raise ApiError(422, "transfer_invalid", "Only a transfer has a transfer_group_id")
    if kind == "transfer" and links["account_id"] is None:
        raise ApiError(422, "transfer_invalid", "A transfer needs an account on each side")
    if kind == "transfer" and links["transfer_group_id"] is None:
        raise ApiError(
            422, "transfer_invalid", "Give both halves of a transfer the same transfer_group_id"
        )
    if kind == "adjustment" and links["account_id"] is None:
        raise ApiError(422, "account_required", "Pick the account to correct")

    account_id = links["account_id"]
    if account_id is not None and (t is None or account_id != t.account_id):
        _check_account(session, actor, account_id, t.currency if t else actor.user.currency)
    if links["refund_of_id"] is not None:
        _check_refund(session, actor, body, links["refund_of_id"], t)
    holding_id = links["holding_id"]
    if holding_id is not None and kind not in INVESTMENT_TYPES:
        raise ApiError(422, "holding_invalid", "Only an investment or a withdrawal names a holding")
    if holding_id is not None and (t is None or holding_id != t.holding_id):
        _check_holding(session, actor, holding_id, t.currency if t else actor.user.currency)
    return direction


def _text(value: str | None) -> str | None:
    """Trimmed, and blank as none."""
    return (value or "").strip() or None


def get_transaction(session: Session, actor: Actor, txn_id: uuid.UUID) -> PersonalTxnOut:
    t = _load(session, actor, txn_id)
    return _out(t, _categories(session, [t]), repo.covered_ids(session, actor.user_id))


def reported_accounts(session: Session, actor: Actor) -> list[AccountOut]:
    """Each account label your entries carry, most recently used first, with the latest
    balance its bank reported."""
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
    touched: dict[uuid.UUID, bool] = {}
    t = create(session, actor, body, touched=touched)
    transfers.check_groups(session, actor.user_id, touched)
    contributions.check_counted_once(session, actor.user_id, "contribution")
    session.commit()
    return get_transaction(session, actor, t.id)


def create(
    session: Session,
    actor: Actor,
    body: PersonalTxnIn,
    txn_id: uuid.UUID | None = None,
    touched: dict[uuid.UUID, bool] | None = None,
) -> PersonalTransaction:
    """The entry for `body` (with id `txn_id` or `body.id`), recorded but not committed: the
    one a repeated create already made (deleted or not, unchanged), or a new one. Adds the
    transfer it starts to `touched`, for transfers.check_groups()."""
    txn_id = txn_id or body.id
    replay = replayed_create(
        session, PersonalTransaction, txn_id, lambda t: t.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    label = _text(body.account)
    links = {k: getattr(body, k) for k in LINKS}
    if "account_id" not in body.model_fields_set and label:
        # An older app: it knows the label, not the account.
        found = accounts.for_label(session, actor.user_id, label, actor.user.currency)
        links["account_id"] = found.id if found else None
    direction = _validate(session, actor, body, links, None)
    _check_category(session, actor, body.category_id)
    _check_links(session, actor, body.type, body.expense_id, body.settlement_id)
    t = PersonalTransaction(
        **client_id(txn_id),
        user_id=actor.user_id,
        type=body.type,
        direction=direction,
        amount_minor=body.amount_minor,
        currency=actor.user.currency,
        category_id=body.category_id,
        date=body.date,
        description=body.description.strip(),
        notes=body.notes,
        channel=body.channel,
        merchant=_text(body.merchant),
        account=label,
        source=body.source,
        reference=_text(body.reference),
        balance_minor=body.balance_minor,
        sms_at=body.sms_at,
        reviewed=body.reviewed,
        account_id=links["account_id"],
        transfer_group_id=links["transfer_group_id"],
        refund_of_id=links["refund_of_id"],
        holding_id=links["holding_id"],
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
    # The app guessed an SMS entry's category; you chose a manual one's.
    if t.source != "sms" and t.type in ("income", "expense"):
        _learn(session, actor, t)
    if touched is not None and t.transfer_group_id:
        touched[t.transfer_group_id] = True
    return t


def _learn(session: Session, actor: Actor, t: PersonalTransaction) -> None:
    rules.learn(
        session, actor, t.merchant or t.description, t.category_id, income=t.type == "income"
    )


def update_transaction(
    session: Session, actor: Actor, txn_id: uuid.UUID, body: PersonalTxnIn
) -> PersonalTxnOut:
    actor.require_write()
    touched: dict[uuid.UUID, bool] = {}
    t = update(session, actor, txn_id, body, touched)
    transfers.check_groups(session, actor.user_id, touched)
    contributions.check_counted_once(session, actor.user_id, "contribution")
    session.commit()
    return get_transaction(session, actor, t.id)


def update(
    session: Session,
    actor: Actor,
    txn_id: uuid.UUID,
    body: PersonalTxnIn,
    touched: dict[uuid.UUID, bool],
) -> PersonalTransaction:
    """Recorded but not committed. Adds the transfers the entry was or is in to `touched`."""
    t = _load(session, actor, txn_id)
    if t.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this entry before editing it")
    check_version(t, body.version)
    _check_category(session, actor, body.category_id)
    given = {k: getattr(body, k) for k in EDITABLE if k in body.model_fields_set}
    for k in ("merchant", "account"):
        if k in given:
            given[k] = _text(given[k])
    if "account_id" not in body.model_fields_set and given.get("account") not in (None, t.account):
        # An older app relabelled it: the account with that label, or none, so the label and the
        # account agree (ISS-068).
        found = accounts.for_label(session, actor.user_id, given["account"], t.currency)
        given["account_id"] = found.id if found is not None else None
    links = {k: given.get(k, getattr(t, k)) for k in LINKS}
    direction = _validate(session, actor, body, links, t)
    if body.amount_minor < t.amount_minor:
        contributions.check_entry_amount(session, t, body.amount_minor)
    if t.type == "income" and body.type != "income" and allocation_plans.has_live_plans(session, t):
        raise ApiError(
            422,
            "income_has_plans",
            "Your allocation rules made plans from this income. Delete them first",
        )
    # Checked when the link (or what it links) changes, so a link whose expense was deleted
    # since doesn't block other edits.
    expense_id, settlement_id = links["expense_id"], links["settlement_id"]
    if (expense_id, settlement_id, body.type) != (t.expense_id, t.settlement_id, t.type):
        _check_links(session, actor, body.type, expense_id, settlement_id)

    def state() -> dict:
        ids = ("category_id", *LINKS)
        return {
            "type": t.type,
            "direction": t.direction,
            "amount_minor": t.amount_minor,
            "description": t.description,
            "date": t.date.isoformat(),
            "notes": t.notes,
            "channel": t.channel,
            "merchant": t.merchant,
            "account": t.account,
            "reviewed": t.reviewed,
            **{k: str(getattr(t, k)) if getattr(t, k) else None for k in ids},
        }

    before, old_group = state(), t.transfer_group_id
    t.type, t.amount_minor, t.description = body.type, body.amount_minor, body.description.strip()
    t.direction = direction
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
    if "category_id" in diff and t.type in ("income", "expense"):
        _learn(session, actor, t)
    for group in (old_group, t.transfer_group_id):
        if group is not None:
            touched.setdefault(group, False)
    return t


def change_deleted(
    session: Session,
    actor: Actor,
    txn_id: uuid.UUID,
    deleted: bool,
    version: int | None,
    touched: dict[uuid.UUID, bool],
) -> PersonalTransaction:
    """Deletes or restores the entry, and a transfer leg's partner with it (the version is
    checked on the one addressed), each with its goal contribution. Restoring refuses an entry
    whose account was deleted. Recorded but not committed."""
    t = _load(session, actor, txn_id)
    if (t.deleted_at is not None) == deleted:
        return t
    check_version(t, version)
    legs = [t, *transfers.partners(session, t)]
    now = datetime.now(UTC)
    for leg in legs:
        if not deleted and leg.account_id is not None:
            account = session.get(PersonalAccount, leg.account_id)
            if account is None or account.deleted_at is not None:
                raise ApiError(
                    422,
                    "unknown_account",
                    "This entry's account was deleted. Restore the account first",
                )
        if not deleted and leg.holding_id is not None:
            holding = session.get(PersonalHolding, leg.holding_id)
            if holding.deleted_at is not None:
                raise ApiError(
                    422,
                    "unknown_holding",
                    "This entry's holding was deleted. Restore the holding first",
                )
        # A contribution follows its entry: it went at the same moment, so it comes back too.
        at = now if deleted else leg.deleted_at
        leg.deleted_at = now if deleted else None
        leg.acting_admin_id = actor.admin_id
        contributions.follow_entry(session, actor, leg, deleted, at)
        allocation_plans.follow_income(session, actor, leg, deleted, at)
        action = "personal.delete" if deleted else "personal.restore"
        record(session, actor, action, "personal_transaction", leg.id, obj=leg)
    if t.transfer_group_id is not None:
        touched.setdefault(t.transfer_group_id, False)
    return t


def set_deleted(
    session: Session, actor: Actor, txn_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalTxnOut:
    actor.require_write()
    touched: dict[uuid.UUID, bool] = {}
    change_deleted(session, actor, txn_id, deleted, version, touched)
    transfers.check_groups(session, actor.user_id, touched)
    contributions.check_counted_once(session, actor.user_id, "contribution")
    session.commit()
    return get_transaction(session, actor, txn_id)
