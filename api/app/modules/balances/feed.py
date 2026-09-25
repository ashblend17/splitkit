"""Recent expenses and payments, from the viewer's point of view (Home and group detail)."""

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.modules.auth.deps import Actor
from app.modules.balances import repository as ledger
from app.modules.balances.engine import pairwise
from app.modules.balances.schemas import FeedItem
from app.modules.categories.models import Category
from app.modules.categories.schemas import CategoryOut
from app.modules.expenses.models import Expense
from app.modules.groups import repository as groups
from app.modules.groups.models import Group
from app.modules.groups.service import require_member
from app.modules.settlements.models import Settlement
from app.modules.users import repository as users
from app.modules.users.models import User
from app.modules.users.schemas import brief


@dataclass(frozen=True)
class FeedFilters:
    """Narrowing for the desktop activity table. Category and "open only" leave payments out."""

    category: str | None = None
    start: date | None = None
    end: date | None = None
    open_only: bool = False
    """Only expenses where you and the other side are not square yet."""
    search: str | None = None
    """Expense description or payer name; either person's name for a payment."""

    @property
    def payments(self) -> bool:
        return self.category is None and not self.open_only


def _like(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def feed(
    session: Session,
    actor: Actor,
    group_id: uuid.UUID | None,
    limit: int,
    offset: int,
    deleted: bool,
    filters: FeedFilters | None = None,
) -> list[FeedItem]:
    me = actor.user_id
    f = filters or FeedFilters()
    if group_id is not None:
        group_ids = [require_member(session, group_id, me).id]
    else:
        group_ids = [g.id for g in groups.groups_for_user(session, me)]
    if not group_ids:
        return []

    window = offset + limit
    named = (
        select(User.id).where(User.name.ilike(_like(f.search), escape="\\")) if f.search else None
    )

    exp_deleted = Expense.deleted_at.isnot(None) if deleted else Expense.deleted_at.is_(None)
    exp_query = (
        select(Expense)
        .options(selectinload(Expense.splits))
        .where(Expense.group_id.in_(group_ids), exp_deleted)
        .order_by(Expense.date.desc(), Expense.created_at.desc(), Expense.id.desc())
    )
    if f.category:
        exp_query = exp_query.join(Category, Expense.category_id == Category.id).where(
            Category.key == f.category
        )
    if f.start:
        exp_query = exp_query.where(Expense.date >= f.start)
    if f.end:
        exp_query = exp_query.where(Expense.date <= f.end)
    if named is not None:
        exp_query = exp_query.where(
            or_(
                Expense.description.ilike(_like(f.search), escape="\\"),
                Expense.payer_id.in_(named),
            )
        )
    # "Open only" is decided from balances after loading, so the page is cut in Python.
    expenses = list(session.scalars(exp_query if f.open_only else exp_query.limit(window)))

    settlements = []
    if f.payments:
        set_deleted = (
            Settlement.deleted_at.isnot(None) if deleted else Settlement.deleted_at.is_(None)
        )
        set_query = (
            select(Settlement)
            .where(Settlement.group_id.in_(group_ids), set_deleted)
            .order_by(Settlement.date.desc(), Settlement.created_at.desc(), Settlement.id.desc())
        )
        if f.start:
            set_query = set_query.where(Settlement.date >= f.start)
        if f.end:
            set_query = set_query.where(Settlement.date <= f.end)
        if named is not None:
            set_query = set_query.where(
                or_(Settlement.from_user.in_(named), Settlement.to_user.in_(named))
            )
        settlements = list(session.scalars(set_query.limit(window)))

    rows = session.execute(select(Group.id, Group.name).where(Group.id.in_(group_ids)))
    names = {g: n for g, n in rows}
    people = users.get_many(
        session,
        [e.payer_id for e in expenses] + [u for s in settlements for u in (s.from_user, s.to_user)],
    )
    category_ids = {e.category_id for e in expenses if e.category_id}
    cats = {
        c.id: CategoryOut.model_validate(c)
        for c in session.scalars(select(Category).where(Category.id.in_(category_ids)))
    }

    flows = ledger.flows_by_group(session, list({e.group_id for e in expenses}))
    my_pairs = {gid: pairwise(me, f) for gid, f in flows.items()}

    items = []
    for e in expenses:
        my_share = next((s.share_minor for s in e.splits if s.user_id == me), 0)
        pairs = my_pairs.get(e.group_id, {})
        if f.open_only and not _open(e, me, my_share, pairs):
            continue
        items.append(
            FeedItem(
                kind="expense",
                id=e.id,
                group_id=e.group_id,
                group_name=names[e.group_id],
                title=e.description,
                date=e.date,
                created_at=e.created_at,
                amount_minor=e.amount_minor,
                currency=e.currency,
                category=cats.get(e.category_id),
                payer=brief(people[e.payer_id]),
                to_user=None,
                method=e.split_method,
                participant_count=sum(1 for s in e.splits if s.share_minor),
                my_share_minor=my_share,
                my_net_minor=(e.amount_minor if e.payer_id == me else 0) - my_share,
                settled=(e.payer_id != me and my_share > 0 and pairs.get(e.payer_id, 0) >= 0),
                by_admin=e.acting_admin_id is not None,
                deleted_at=e.deleted_at,
            )
        )
    for s in settlements:
        effect = s.amount_minor if s.from_user == me else -s.amount_minor if s.to_user == me else 0
        items.append(
            FeedItem(
                kind="settlement",
                id=s.id,
                group_id=s.group_id,
                group_name=names[s.group_id],
                title=None,
                date=s.date,
                created_at=s.created_at,
                amount_minor=s.amount_minor,
                currency=s.currency,
                category=None,
                payer=brief(people[s.from_user]),
                to_user=brief(people[s.to_user]),
                method=s.method,
                participant_count=2,
                my_share_minor=0,
                my_net_minor=effect,
                settled=False,
                by_admin=s.acting_admin_id is not None,
                deleted_at=s.deleted_at,
            )
        )
    # id breaks ties (imported rows share a timestamp) so pages never overlap or skip.
    items.sort(key=lambda i: (i.date, i.created_at, str(i.id)), reverse=True)
    return items[offset:window]


def _open(e: Expense, me: uuid.UUID, my_share: int, pairs: dict[uuid.UUID, int]) -> bool:
    """You owe the payer, or you paid and someone in the split still owes you."""
    if e.payer_id == me:
        return any(
            s.user_id != me and s.share_minor and pairs.get(s.user_id, 0) > 0 for s in e.splits
        )
    return my_share > 0 and pairs.get(e.payer_id, 0) < 0
