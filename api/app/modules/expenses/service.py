import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.balances import repository as ledger
from app.modules.balances.engine import pairwise
from app.modules.categories import repository as categories
from app.modules.categories.schemas import CategoryOut
from app.modules.expenses import repository as repo
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.expenses.schemas import ExpenseIn, ExpenseOut, HistoryEntry, SplitOut
from app.modules.groups.models import Group
from app.modules.groups.service import active_member_ids, require_member
from app.modules.splits import service as splits
from app.modules.users import repository as users
from app.modules.users.schemas import brief


def to_out(session: Session, e: Expense, me: uuid.UUID) -> ExpenseOut:
    people = users.get_many(session, [e.payer_id, e.created_by, *(s.user_id for s in e.splits)])
    category = (
        categories.get_visible(session, e.category_id, me, "group") if e.category_id else None
    )
    my_share = next((s.share_minor for s in e.splits if s.user_id == me), 0)
    owed_to_payer = pairwise(
        e.payer_id, ledger.flows_by_group(session, [e.group_id]).get(e.group_id, [])
    )

    def status(user_id: uuid.UUID) -> str:
        if user_id == e.payer_id:
            return "paid"
        return "owes" if owed_to_payer.get(user_id, 0) > 0 else "settled"

    return ExpenseOut(
        id=e.id,
        group_id=e.group_id,
        description=e.description,
        amount_minor=e.amount_minor,
        currency=e.currency,
        payer=brief(people[e.payer_id]),
        date=e.date,
        category=CategoryOut.model_validate(category) if category else None,
        notes=e.notes,
        split_method=e.split_method,
        splits=[
            SplitOut(
                user=brief(people[s.user_id]),
                share_minor=s.share_minor,
                input_value=s.input_value,
                status=status(s.user_id),
            )
            for s in e.splits
        ],
        my_share_minor=my_share,
        my_net_minor=(e.amount_minor if e.payer_id == me else 0) - my_share,
        created_by=brief(people[e.created_by]),
        acting_admin_id=e.acting_admin_id,
        import_batch_id=e.import_batch_id,
        created_at=e.created_at,
        updated_at=e.updated_at,
        deleted_at=e.deleted_at,
        version=e.version,
    )


def _load(session: Session, actor: Actor, expense_id: uuid.UUID) -> Expense:
    expense = repo.get(session, expense_id)
    if expense is None:
        raise not_found("Expense")
    require_member(session, expense.group_id, actor.user_id)
    return expense


def _check(
    session: Session, actor: Actor, group: Group, body: ExpenseIn, allowed: set[uuid.UUID]
) -> list[ExpenseSplit]:
    """Validate people and category, then run the split engine."""
    if body.payer_id not in allowed:
        raise ApiError(422, "payer_not_member", "The payer has to be in this group")
    outsiders = [i.user_id for i in body.split.inputs if i.user_id not in allowed]
    if outsiders:
        raise ApiError(
            422, "participant_not_member", "Everyone in the split has to be in this group"
        )
    if body.category_id and not categories.get_visible(
        session, body.category_id, actor.user_id, "group"
    ):
        raise ApiError(422, "unknown_category", "That category isn't available")
    shares = splits.allocate(body.split, body.amount_minor, group.currency)
    return [
        ExpenseSplit(
            user_id=uuid.UUID(s.user_id), share_minor=s.share_minor, input_value=s.input_value
        )
        for s in shares
    ]


def get_expense(session: Session, actor: Actor, expense_id: uuid.UUID) -> ExpenseOut:
    return to_out(session, _load(session, actor, expense_id), actor.user_id)


def create_expense(
    session: Session, actor: Actor, group_id: uuid.UUID, body: ExpenseIn
) -> ExpenseOut:
    actor.require_write()
    group = require_member(session, group_id, actor.user_id)
    replay = replayed_create(
        session,
        Expense,
        body.id,
        lambda e: e.group_id == group_id and e.created_by == actor.user_id,
    )
    if replay is not None:
        return get_expense(session, actor, replay.id)
    split_rows = _check(session, actor, group, body, active_member_ids(session, group_id))
    expense = Expense(
        **client_id(body.id),
        group_id=group_id,
        description=body.description.strip(),
        amount_minor=body.amount_minor,
        currency=group.currency,
        payer_id=body.payer_id,
        date=body.date,
        category_id=body.category_id,
        notes=body.notes,
        split_method=body.split.method,
        created_by=actor.user_id,
        acting_admin_id=actor.admin_id,
        splits=split_rows,
    )
    session.add(expense)
    session.flush()
    record(
        session,
        actor,
        "expense.create",
        "expense",
        expense.id,
        group_id,
        {"description": expense.description, "amount_minor": expense.amount_minor},
        obj=expense,
    )
    session.commit()
    return get_expense(session, actor, expense.id)


def update_expense(
    session: Session, actor: Actor, expense_id: uuid.UUID, body: ExpenseIn
) -> ExpenseOut:
    actor.require_write()
    expense = _load(session, actor, expense_id)
    if expense.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this expense before editing it")
    check_version(expense, body.version)
    group = session.get(Group, expense.group_id)
    # People who have since left can stay on an expense they were already part of.
    allowed = (
        active_member_ids(session, group.id)
        | {expense.payer_id}
        | {s.user_id for s in expense.splits}
    )
    split_rows = _check(session, actor, group, body, allowed)

    before = _snapshot(expense)
    expense.description = body.description.strip()
    expense.amount_minor = body.amount_minor
    expense.payer_id = body.payer_id
    expense.date = body.date
    expense.category_id = body.category_id
    expense.notes = body.notes
    expense.split_method = body.split.method
    expense.acting_admin_id = actor.admin_id
    expense.updated_at = datetime.now(UTC)
    repo.replace_splits(session, expense, split_rows)
    after = {**_snapshot(expense), "splits": {str(s.user_id): s.share_minor for s in split_rows}}
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    record(session, actor, "expense.update", "expense", expense.id, group.id, diff, obj=expense)
    session.commit()
    return get_expense(session, actor, expense.id)


def _snapshot(e: Expense) -> dict:
    return {
        "description": e.description,
        "amount_minor": e.amount_minor,
        "payer_id": str(e.payer_id),
        "date": e.date.isoformat(),
        "category_id": str(e.category_id) if e.category_id else None,
        "notes": e.notes,
        "split_method": e.split_method,
        "splits": {str(s.user_id): s.share_minor for s in e.splits},
    }


def set_deleted(
    session: Session, actor: Actor, expense_id: uuid.UUID, deleted: bool, version: int | None = None
) -> ExpenseOut:
    actor.require_write()
    expense = _load(session, actor, expense_id)
    if (expense.deleted_at is not None) != deleted:
        check_version(expense, version)
        expense.deleted_at = datetime.now(UTC) if deleted else None
        expense.acting_admin_id = actor.admin_id
        action = "expense.delete" if deleted else "expense.restore"
        record(session, actor, action, "expense", expense.id, expense.group_id, obj=expense)
        session.commit()
    return get_expense(session, actor, expense_id)


def expense_history(session: Session, actor: Actor, expense_id: uuid.UUID) -> list[HistoryEntry]:
    _load(session, actor, expense_id)
    rows = repo.history(session, expense_id)
    people = users.get_many(session, [u for r in rows for u in (r.actor_id, r.acting_as_id) if u])
    entries = []
    for r in rows:
        person_id = r.acting_as_id or r.actor_id
        admin_id = r.actor_id if r.acting_as_id else None
        entries.append(
            HistoryEntry(
                action=r.action,
                person=brief(people[person_id]) if person_id else None,
                admin=brief(people[admin_id]) if admin_id else None,
                at=r.at,
                diff=r.diff_json,
            )
        )
    return entries
