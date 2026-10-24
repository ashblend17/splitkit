"""Tricount import: preview (writes nothing), commit (one transaction, one batch) and undo.

The preview is stateless: the client keeps the file and sends it again with the chosen
mapping on commit, so nothing half-imported is ever stored. Everything a commit creates
(group, memberships, expenses, settlements) carries the batch's `import_batch_id`, and
every write goes through `record()` so offline clients get it from the sync log.

Undo soft-deletes the batch's expenses and payments (restorable one by one from the group's
deleted items), including ones edited since the import: they still came from the file. It
then ends the memberships the import added for people no longer in any live expense or
payment of the group, and archives a group the import created once nothing live is left in
it. Undoing twice changes nothing.
"""

import re
import uuid
from collections import Counter
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import PurePath

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.money import SUPPORTED_CURRENCIES
from app.modules.auth.deps import Actor
from app.modules.categories import repository as categories
from app.modules.categories.models import Category
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups import repository as groups
from app.modules.groups.models import Group, GroupMember
from app.modules.groups.service import require_member
from app.modules.settlements.models import Settlement
from app.modules.users.models import User
from app.modules.users.schemas import brief

from .matching import Candidate, match_people, suggest_category
from .models import ImportBatch
from .parser import MAX_BYTES, ParsedFile, ParseError, parse
from .plan import PlannedRow, plan
from .schemas import (
    CategoryMatchOut,
    CategoryOptionOut,
    ImportBatchOut,
    ImportCommitIn,
    ImportPreviewOut,
    ImportRowOut,
    ImportStatsOut,
    ImportTotalsOut,
    PersonOut,
    ReviewItemOut,
    RowIssueOut,
    RowShareOut,
)


def _parse(file_name: str, content: bytes) -> ParsedFile:
    if len(content) > MAX_BYTES:
        raise ApiError(413, "file_too_large", "This file is larger than 5 MB")
    try:
        return parse(content, file_name)
    except ParseError as e:
        raise ApiError(422, "import_unreadable", str(e)) from None


def parse_options(text: str) -> ImportCommitIn:
    try:
        return ImportCommitIn.model_validate_json(text)
    except ValidationError as e:
        detail = e.errors()[0]
        where = ".".join(str(p) for p in detail["loc"])
        message = f"{where}: {detail['msg']}" if where else detail["msg"]
        raise ApiError(422, "import_options_invalid", message) from None


def _group_name(parsed: ParsedFile, file_name: str) -> str:
    if parsed.title and len(parsed.title) <= 80:
        return parsed.title
    stem = PurePath(file_name).stem
    words = [
        w
        for w in re.split(r"[\s_\-.]+", stem)
        if w
        and w.lower() not in {"tricount", "export", "expenses", "transactions"}
        and not w.isdigit()
    ]
    name = " ".join(w if w.isupper() else w.capitalize() for w in words)
    return name[:80] or "Imported from Tricount"


def _main_currency(parsed: ParsedFile) -> str | None:
    counts = Counter(r.currency for r in parsed.rows if r.currency in SUPPORTED_CURRENCIES)
    return counts.most_common(1)[0][0] if counts else None


def _candidates(
    session: Session, actor: Actor, group: Group | None
) -> list[tuple[User, str | None]]:
    """You, the group's current members (placeholders included), and the accounts you share
    any group with."""
    people: dict[uuid.UUID, tuple[User, str | None]] = {actor.user_id: (actor.user, None)}
    if group is not None:
        for m, u in groups.active_members(session, group.id):
            people.setdefault(u.id, (u, m.placeholder_name))
    mine = select(GroupMember.group_id).where(
        GroupMember.user_id == actor.user_id, GroupMember.left_at.is_(None)
    )
    friends = session.scalars(
        select(User)
        .join(GroupMember, GroupMember.user_id == User.id)
        .where(
            GroupMember.group_id.in_(mine),
            GroupMember.left_at.is_(None),
            User.email.is_not(None),
        )
        .distinct()
        .order_by(User.name)
    )
    for u in friends:
        people.setdefault(u.id, (u, None))
    return list(people.values())


def _names_in(row: PlannedRow) -> list[str]:
    return [*([row.payer] if row.payer else []), *(n for n, _ in row.shares)]


def _group_categories(session: Session, actor: Actor) -> list[Category]:
    """In display order, with the user's own category after (so winning over) a built-in one
    with the same key when put in a dict."""
    return sorted(
        categories.visible(session, actor.user_id, "group"), key=lambda c: c.owner_id is not None
    )


def _category_options(session: Session, actor: Actor) -> dict[str, CategoryOptionOut]:
    return {
        c.key: CategoryOptionOut(key=c.key, label=c.label, icon=c.icon)
        for c in _group_categories(session, actor)
    }


def _payments(r: PlannedRow) -> list[tuple[str, str, int]]:
    """The payments transfer or income row `r` becomes, as (from, to, amount): a transfer is
    paid by its payer to each recipient; income is paid to whoever received it by each other
    person it was for, their share (ISS-019)."""
    if r.kind == "income":
        return [(name, r.payer, amount) for name, amount in r.shares if name != r.payer]
    return [(r.payer, name, amount) for name, amount in r.shares]


def _totals(rows: list[PlannedRow]) -> ImportTotalsOut:
    ok = [r for r in rows if r.ok]
    expenses = [r for r in ok if r.kind == "expense"]
    transfers = [r for r in ok if r.kind in ("transfer", "income")]
    days = [r.date for r in ok if r.date]
    return ImportTotalsOut(
        expenses=len(expenses),
        expense_total_minor=sum(r.amount_minor for r in expenses),
        transfers=len(transfers),
        transfer_total_minor=sum(a for r in transfers for _, _, a in _payments(r)),
        skipped=len(rows) - len(ok),
        first_date=min(days, default=None),
        last_date=max(days, default=None),
    )


def preview(
    session: Session,
    actor: Actor,
    file_name: str,
    content: bytes,
    group_id: uuid.UUID | None = None,
    currency: str | None = None,
) -> ImportPreviewOut:
    parsed = _parse(file_name, content)
    group = require_member(session, group_id, actor.user_id) if group_id else None
    if group is not None:
        target = group.currency
    else:
        fallback = actor.user.currency if actor.user.currency in SUPPORTED_CURRENCIES else "INR"
        target = currency if currency in SUPPORTED_CURRENCIES else None
        target = target or _main_currency(parsed) or fallback
    rows = plan(parsed.rows, target, parsed.default_currency)

    candidates = _candidates(session, actor, group)
    matches = match_people(
        parsed.people,
        [Candidate(u.id, u.name, ph, u.id == actor.user_id) for u, ph in candidates],
    )
    by_id = {u.id: u for u, _ in candidates}
    # Who's in each line as imported: a zero share in an export that fills every column isn't
    # being in it (ISS-029), and a line split by payer counts once.
    by_line: dict[int, set[str]] = {}
    for r in rows:
        by_line.setdefault(r.line, set()).update(_names_in(r))
    in_rows = Counter(n for names in by_line.values() for n in names)

    options = _category_options(session, actor)
    labels = {k: o.label for k, o in options.items()}
    category_rows = Counter(r.category for r in parsed.rows if r.category)

    return ImportPreviewOut(
        file_name=file_name,
        group_name=group.name if group else _group_name(parsed, file_name),
        currency=target,
        people=[
            PersonOut(
                name=name,
                rows=in_rows.get(name, 0),
                match=matches[name].state,
                user=brief(by_id[matches[name].candidate.id]) if matches[name].candidate else None,
            )
            for name in parsed.people
        ],
        candidates=[brief(u) for u, _ in candidates],
        categories=[
            CategoryMatchOut(name=name, rows=n, key=suggest_category(name, labels))
            for name, n in category_rows.items()
        ],
        category_options=list(options.values()),
        rows=[
            ImportRowOut(
                line=r.line,
                date=r.date,
                title=r.title,
                kind=r.kind,
                payer=r.payer,
                amount_minor=r.amount_minor,
                currency=r.currency,
                original=r.original,
                shares=[RowShareOut(name=n, share_minor=s) for n, s in r.shares],
                category=r.category,
                issues=[
                    RowIssueOut(level=i.level, code=i.code, message=i.message) for i in r.issues
                ],
            )
            for r in rows
        ],
        totals=_totals(rows),
    )


# ---- commit ----


def _stats(batch: ImportBatch) -> ImportStatsOut:
    """Batches made before stats had today's shape (e.g. the seed's) still list."""
    defaults = {
        "expenses": 0,
        "expense_total_minor": 0,
        "transfers": 0,
        "transfer_total_minor": 0,
        "people": 0,
        "placeholders": 0,
        "skipped": 0,
        "currency": "INR",
        "created_group": False,
        "review": [],
        "skipped_rows": [],
    }
    return ImportStatsOut(**{k: batch.stats_json.get(k, v) for k, v in defaults.items()})


def _batch_out(session: Session, batch: ImportBatch) -> ImportBatchOut:
    group = session.get(Group, batch.group_id) if batch.group_id else None
    return ImportBatchOut(
        id=batch.id,
        source=batch.source,
        file_name=batch.file_name,
        group_id=batch.group_id,
        group_name=group.name if group else None,
        created_at=batch.created_at,
        undone_at=batch.undone_at,
        stats=_stats(batch),
    )


def _add_member(
    session: Session,
    actor: Actor,
    group: Group,
    batch: ImportBatch,
    user: User,
    placeholder_name: str | None = None,
    role: str = "member",
) -> None:
    existing = groups.membership(session, group.id, user.id)
    if existing is not None and existing.left_at is None:
        return
    if existing is not None:
        existing.left_at = None  # rejoining keeps their history; undo ends it again
        existing.import_batch_id = batch.id
        member = existing
    else:
        member = GroupMember(
            group_id=group.id,
            user_id=user.id,
            role=role,
            placeholder_name=placeholder_name,
            import_batch_id=batch.id,
        )
        session.add(member)
    record(
        session,
        actor,
        "member.add",
        "group",
        group.id,
        group.id,
        {"user_id": str(user.id), "import_batch_id": str(batch.id)},
        obj=member,
    )


def commit(
    session: Session, actor: Actor, file_name: str, content: bytes, options: ImportCommitIn
) -> ImportBatchOut:
    actor.require_write()
    parsed = _parse(file_name, content)
    group = require_member(session, options.group_id, actor.user_id) if options.group_id else None
    currency = group.currency if group else options.new_group.currency
    planned = plan(parsed.rows, currency, parsed.default_currency)
    rows = [r for r in planned if r.ok]
    skipped = [r for r in planned if not r.ok]
    if not rows:
        raise ApiError(422, "import_empty", "None of the rows in this file can be imported")

    allowed = {u.id: u for u, _ in _candidates(session, actor, group)}
    mapping = {p.name: p for p in options.people}
    for p in options.people:
        if p.user_id is not None and p.user_id not in allowed:
            raise ApiError(
                422, "import_unknown_person", f"{p.name} can't be matched to that person"
            )

    batch = ImportBatch(source="tricount", file_name=file_name, created_by=actor.user_id)
    session.add(batch)
    session.flush()

    if group is None:
        group = Group(
            name=options.new_group.name.strip(),
            icon=options.new_group.icon,
            currency=currency,
            created_by=actor.user_id,
            import_batch_id=batch.id,
        )
        session.add(group)
        session.flush()
        owner = GroupMember(
            group_id=group.id, user_id=actor.user_id, role="owner", import_batch_id=batch.id
        )
        session.add(owner)
        record(
            session,
            actor,
            "group.create",
            "group",
            group.id,
            group.id,
            {"name": group.name, "import_batch_id": str(batch.id)},
            obj=[group, owner],
        )
    batch.group_id = group.id

    # People: everyone in an imported row gets a person here in the group.
    needed = [n for n in parsed.people if any(n in _names_in(r) for r in rows)]
    person: dict[str, uuid.UUID] = {}
    placeholders: set[str] = set()
    for name in needed:
        chosen = mapping.get(name)
        if chosen is not None and chosen.user_id is not None:
            user = allowed[chosen.user_id]
            _add_member(session, actor, group, batch, user)
        else:
            label = ((chosen.placeholder_name if chosen else None) or name).strip()[:80]
            user = User(name=label)
            session.add(user)
            session.flush()
            record(session, actor, "user.create_placeholder", "user", user.id, diff={"name": label})
            _add_member(session, actor, group, batch, user, placeholder_name=label)
            placeholders.add(name)
        person[name] = user.id

    options_by_key = {c.key: c for c in _group_categories(session, actor)}
    labels = {k: c.label for k, c in options_by_key.items()}
    other = options_by_key.get("other")

    review: list[ReviewItemOut] = []
    expense_total = transfer_total = transfers = 0
    expenses: list[Expense] = []
    for r in rows:
        if r.kind in ("transfer", "income"):
            for frm, to, amount in _payments(r):
                if person[frm] == person[to]:
                    review.append(
                        ReviewItemOut(
                            title=r.title,
                            why="skipped a payment to the same person",
                            expense_id=None,
                        )
                    )
                    continue
                s = Settlement(
                    group_id=group.id,
                    from_user=person[frm],
                    to_user=person[to],
                    amount_minor=amount,
                    currency=currency,
                    date=r.date,
                    method="other",
                    note=f"From Tricount: {r.title}"[:200],
                    created_by=actor.user_id,
                    acting_admin_id=actor.admin_id,
                    import_batch_id=batch.id,
                )
                session.add(s)
                session.flush()
                record(
                    session,
                    actor,
                    "settlement.create",
                    "settlement",
                    s.id,
                    diff={"amount_minor": amount, "import_batch_id": str(batch.id)},
                    obj=s,
                )
                transfers += 1
                transfer_total += amount
            continue

        suggested = suggest_category(r.category, labels) if r.category else None
        key = options.categories.get(r.category) if r.category else None
        category = options_by_key.get(key or suggested or "other") or other
        merged: dict[uuid.UUID, int] = {}
        for name, share in r.shares:
            merged[person[name]] = merged.get(person[name], 0) + share
        expense = Expense(
            group_id=group.id,
            description=r.title[:200],
            amount_minor=r.amount_minor,
            currency=currency,
            payer_id=person[r.payer],
            date=r.date,
            category_id=category.id if category else None,
            notes=f"Converted from {r.original} in Tricount" if r.original else None,
            split_method="exact",
            import_batch_id=batch.id,
            created_by=actor.user_id,
            acting_admin_id=actor.admin_id,
            splits=[
                ExpenseSplit(user_id=u, share_minor=s, input_value=Decimal(s))
                for u, s in merged.items()
                if s > 0
            ],
        )
        session.add(expense)
        session.flush()
        record(
            session,
            actor,
            "expense.create",
            "expense",
            expense.id,
            diff={"amount_minor": expense.amount_minor, "import_batch_id": str(batch.id)},
            obj=expense,
        )
        expenses.append(expense)
        expense_total += expense.amount_minor

        whys = []
        if r.payer in placeholders:
            whys.append(f"paid by placeholder “{r.payer}” — link to a real account")
        if r.category and category is other and suggested is None:
            whys.append("category set to Other")
        if r.original:
            whys.append(f"converted from {r.original}")
        whys += [i.message for i in r.issues if i.code in ("note", "rounded", "no_title")]
        if whys:
            review.append(ReviewItemOut(title=r.title, why="; ".join(whys), expense_id=expense.id))

    stats = ImportStatsOut(
        expenses=len(expenses),
        expense_total_minor=expense_total,
        transfers=transfers,
        transfer_total_minor=transfer_total,
        people=len(needed),
        placeholders=len(placeholders),
        skipped=len(skipped),
        currency=currency,
        created_group=options.new_group is not None,
        review=review,
        skipped_rows=[
            f"Row {r.line} · {r.title}: {next(i.message for i in r.issues if i.level == 'error')}"
            for r in skipped
        ],
    )
    batch.stats_json = stats.model_dump(mode="json")
    record(
        session,
        actor,
        "import.complete",
        "import_batch",
        batch.id,
        group.id,
        {"expenses": stats.expenses, "transfers": transfers, "flagged": len(review)},
    )
    session.commit()
    return _batch_out(session, batch)


# ---- batches and undo ----


def list_batches(session: Session, actor: Actor) -> list[ImportBatchOut]:
    batches = session.scalars(
        select(ImportBatch)
        .where(ImportBatch.created_by == actor.user_id)
        .order_by(ImportBatch.created_at.desc())
    )
    return [_batch_out(session, b) for b in batches]


def _load_batch(session: Session, actor: Actor, batch_id: uuid.UUID) -> ImportBatch:
    batch = session.get(ImportBatch, batch_id)
    if batch is None or batch.created_by != actor.user_id:
        raise not_found("Import")
    return batch


def get_batch(session: Session, actor: Actor, batch_id: uuid.UUID) -> ImportBatchOut:
    return _batch_out(session, _load_batch(session, actor, batch_id))


def _involved(session: Session, group_id: uuid.UUID) -> set[uuid.UUID]:
    """Everyone in a live expense or payment of the group."""
    live = Expense.group_id == group_id, Expense.deleted_at.is_(None)
    payers = session.scalars(select(Expense.payer_id).where(*live))
    sharers = session.scalars(
        select(ExpenseSplit.user_id)
        .join(Expense, Expense.id == ExpenseSplit.expense_id)
        .where(*live)
    )
    paid = session.execute(
        select(Settlement.from_user, Settlement.to_user).where(
            Settlement.group_id == group_id, Settlement.deleted_at.is_(None)
        )
    )
    return {*payers, *sharers, *(u for pair in paid for u in pair)}


def undo(session: Session, actor: Actor, batch_id: uuid.UUID) -> ImportBatchOut:
    actor.require_write()
    batch = _load_batch(session, actor, batch_id)
    if batch.undone_at is not None:
        return _batch_out(session, batch)
    now = datetime.now(UTC)
    expenses = session.scalars(
        select(Expense)
        .where(Expense.import_batch_id == batch.id, Expense.deleted_at.is_(None))
        .options(selectinload(Expense.splits))
    ).all()
    for e in expenses:
        e.deleted_at = now
        e.acting_admin_id = actor.admin_id
        record(
            session, actor, "expense.delete", "expense", e.id, diff={"undo": str(batch.id)}, obj=e
        )
    settlements = session.scalars(
        select(Settlement).where(
            Settlement.import_batch_id == batch.id, Settlement.deleted_at.is_(None)
        )
    ).all()
    for s in settlements:
        s.deleted_at = now
        record(
            session,
            actor,
            "settlement.delete",
            "settlement",
            s.id,
            diff={"undo": str(batch.id)},
            obj=s,
        )
    session.flush()

    group = session.get(Group, batch.group_id) if batch.group_id else None
    if group is not None:
        involved = _involved(session, group.id)
        created_here = group.import_batch_id == batch.id
        empty = not involved
        members = session.scalars(
            select(GroupMember).where(
                GroupMember.import_batch_id == batch.id, GroupMember.left_at.is_(None)
            )
        ).all()
        for m in members:
            keep = m.user_id in involved or (m.user_id == batch.created_by and not empty)
            if keep:
                continue
            m.left_at = now
            record(
                session,
                actor,
                "member.remove",
                "group",
                group.id,
                group.id,
                {"user_id": str(m.user_id), "undo": str(batch.id)},
                obj=m,
            )
        if created_here and empty and group.archived_at is None:
            group.archived_at = now
            record(
                session,
                actor,
                "group.update",
                "group",
                group.id,
                group.id,
                {"archived": {"from": False, "to": True}, "undo": str(batch.id)},
                obj=group,
            )

    batch.undone_at = now
    record(
        session,
        actor,
        "import.undo",
        "import_batch",
        batch.id,
        batch.group_id,
        {"expenses": len(expenses), "settlements": len(settlements)},
    )
    session.commit()
    return _batch_out(session, batch)
