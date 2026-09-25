import uuid
from datetime import date

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.events import record
from app.modules.analytics import sources
from app.modules.analytics.models import AnalyticsConfiguration
from app.modules.analytics.periods import Period, range_label
from app.modules.analytics.schemas import (
    AnalyticsCardOut,
    DashboardOut,
    LayoutCard,
    LayoutIn,
    LayoutOut,
)
from app.modules.auth.deps import Actor
from app.modules.categories.models import Category
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups import repository as groups
from app.modules.groups.service import require_member
from app.modules.personal.models import PersonalTransaction
from app.modules.sync import log as sync_log
from app.modules.users.models import User

Scope = str  # "personal" | "group"


def _rows(
    session: Session, scope: Scope, owner_id: uuid.UUID | None
) -> list[AnalyticsConfiguration]:
    return list(
        session.scalars(
            select(AnalyticsConfiguration)
            .where(
                AnalyticsConfiguration.scope == scope,
                AnalyticsConfiguration.owner_id.is_(None)
                if owner_id is None
                else AnalyticsConfiguration.owner_id == owner_id,
            )
            .order_by(AnalyticsConfiguration.position)
        )
    )


def layout_rows(session: Session, scope: Scope, user_id: uuid.UUID) -> list[AnalyticsConfiguration]:
    """Your own layout if you saved one, otherwise the defaults."""
    return _rows(session, scope, user_id) or _rows(session, scope, None)


def _cards(rows: list[AnalyticsConfiguration], ctx: sources.Context) -> list[AnalyticsCardOut]:
    cards = []
    for r in rows:
        data = sources.build(r.source, ctx)
        cards.append(
            AnalyticsCardOut(
                id=r.id,
                type=r.type,
                title=r.title,
                source=r.source,
                period_label=data.period_label,
                headline=data.headline,
                bars=data.bars,
                rows=data.rows,
                stat=data.stat,
            )
        )
    return cards


def _labels(session: Session) -> dict[uuid.UUID, str]:
    return {c.id: c.label for c in session.scalars(select(Category))}


def personal_dashboard(session: Session, actor: Actor, period: Period, on: date) -> DashboardOut:
    me = actor.user_id
    labels = _labels(session)
    personal = [
        sources.Entry(t.date, t.amount_minor, labels.get(t.category_id, "Uncategorised"))
        for t in session.scalars(
            select(PersonalTransaction).where(
                PersonalTransaction.user_id == me,
                PersonalTransaction.type == "expense",
                PersonalTransaction.deleted_at.is_(None),
            )
        )
    ]
    shares = [
        sources.Entry(d, share)
        for d, share in session.execute(
            select(Expense.date, ExpenseSplit.share_minor)
            .join(ExpenseSplit, ExpenseSplit.expense_id == Expense.id)
            .where(ExpenseSplit.user_id == me, Expense.deleted_at.is_(None))
        )
    ]
    ctx = sources.Context(
        period=period, on=on, currency=actor.user.currency, personal=personal, group_shares=shares
    )
    return DashboardOut(
        scope="personal",
        currency=actor.user.currency,
        cards=_cards(layout_rows(session, "personal", me), ctx),
    )


def group_dashboard(session: Session, actor: Actor, group_id: uuid.UUID, on: date) -> DashboardOut:
    group = require_member(session, group_id, actor.user_id)
    me = actor.user_id
    labels = _labels(session)
    expenses = list(
        session.scalars(
            select(Expense).where(Expense.group_id == group_id, Expense.deleted_at.is_(None))
        )
    )
    payer_ids = {e.payer_id for e in expenses}
    names = (
        {u.id: u.name for u in session.scalars(select(User).where(User.id.in_(payer_ids)))}
        if payer_ids
        else {}
    )
    entries = [
        sources.Entry(
            e.date,
            e.amount_minor,
            labels.get(e.category_id, "Uncategorised"),
            "You" if e.payer_id == me else names.get(e.payer_id, "Someone").split()[0],
        )
        for e in expenses
    ]
    my_share = sum(
        s
        for (s,) in session.execute(
            select(ExpenseSplit.share_minor)
            .join(Expense, Expense.id == ExpenseSplit.expense_id)
            .where(
                Expense.group_id == group_id,
                Expense.deleted_at.is_(None),
                ExpenseSplit.user_id == me,
            )
        )
    )
    members = len(groups.active_members(session, group_id))
    ctx = sources.Context(
        period="month",
        on=on,
        currency=group.currency,
        group_expenses=entries,
        my_share_in_group=my_share,
        member_count=members,
    )
    subtitle = f"{members} {'member' if members == 1 else 'members'}"
    if entries:
        days = [e.day for e in entries]
        subtitle = f"{range_label(min(days), max(days))} · {subtitle}"
    return DashboardOut(
        scope="group",
        currency=group.currency,
        subtitle=subtitle,
        cards=_cards(layout_rows(session, "group", me), ctx),
    )


def _layout_card(r: AnalyticsConfiguration) -> LayoutCard:
    return LayoutCard(
        type=r.type, title=r.title, period=r.period, source=r.source, params=r.params_json
    )


def get_layout(session: Session, actor: Actor, scope: Scope) -> LayoutOut:
    mine = _rows(session, scope, actor.user_id)
    defaults = _rows(session, scope, None)
    return LayoutOut(
        cards=[_layout_card(r) for r in (mine or defaults)],
        available=[_layout_card(r) for r in defaults],
        customised=bool(mine),
    )


def save_layout(session: Session, actor: Actor, scope: Scope, body: LayoutIn) -> LayoutOut:
    """Your cards in your order. Sources must be known so every card can render."""
    unknown = [c.source for c in body.cards if c.source not in sources.SOURCES]
    if unknown:
        raise ApiError(422, "unknown_source", f"Unknown data source: {unknown[0]}")
    session.execute(
        delete(AnalyticsConfiguration).where(
            AnalyticsConfiguration.scope == scope, AnalyticsConfiguration.owner_id == actor.user_id
        )
    )
    rows = [
        AnalyticsConfiguration(
            scope=scope,
            owner_id=actor.user_id,
            position=i + 1,
            type=c.type,
            title=c.title,
            period=c.period,
            source=c.source,
            params_json=c.params,
        )
        for i, c in enumerate(body.cards)
    ]
    session.add_all(rows)
    _record_layout(session, actor, "layout.save", scope, rows)
    session.commit()
    return get_layout(session, actor, scope)


def _record_layout(
    session: Session, actor: Actor, action: str, scope: Scope, rows: list[AnalyticsConfiguration]
) -> None:
    layout_id = sync_log.layout_id(actor.user_id, scope)
    diff = {"scope": scope, "sources": [r.source for r in rows]}
    record(session, actor, action, "layout", layout_id, diff=diff)
    sync_log.track_layout(session, actor, action, scope, rows)


def reset_layout(session: Session, actor: Actor, scope: Scope) -> LayoutOut:
    session.execute(
        delete(AnalyticsConfiguration).where(
            AnalyticsConfiguration.scope == scope, AnalyticsConfiguration.owner_id == actor.user_id
        )
    )
    _record_layout(session, actor, "layout.reset", scope, [])
    session.commit()
    return get_layout(session, actor, scope)
