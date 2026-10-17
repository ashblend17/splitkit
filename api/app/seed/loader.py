"""Writes app.seed.data into the database. Ids are deterministic (uuid5) so they are stable
across reseeds, which keeps client fixtures and bookmarks working."""

import uuid
from decimal import Decimal

from sqlalchemy import delete, text
from sqlalchemy.orm import Session

from app.core.db import Base
from app.core.security import hash_password
from app.models import (
    ActivityEvent,
    AdminSession,
    AnalyticsConfiguration,
    AuditLog,
    Category,
    Expense,
    ExpenseSplit,
    Group,
    GroupMember,
    ImportBatch,
    PersonalAccount,
    PersonalAllocationPlan,
    PersonalAllocationRule,
    PersonalGoal,
    PersonalGoalContribution,
    PersonalHolding,
    PersonalReminderSchedule,
    PersonalReminderState,
    PersonalTransaction,
    Settlement,
    User,
)
from app.modules.personal.ledger_rules import (
    implied_direction,
    plan_id,
    reminder_state_id,
    sms_account_id,
)
from app.modules.splits.engine import Share, SplitInput, registry
from app.seed import data as d

_NAMESPACE = uuid.UUID("5b1e7c1a-5911-4a6b-8e0c-5b117c17a5ed")
CURRENCY = "INR"


def seed_id(kind: str, key: str) -> uuid.UUID:
    return uuid.uuid5(_NAMESPACE, f"{kind}:{key}")


def rupees(amount: int) -> int:
    return amount * 100


def compute_splits(e: d.SeedExpense) -> list[Share]:
    """Run a seed expense through the split engine. Share.user_id is the seed person key."""
    if e.method == "exact":
        inputs = [SplitInput(p, Decimal(rupees(v))) for p, v in e.inputs]
    else:
        inputs = [SplitInput(p, None if v is None else Decimal(v)) for p, v in e.inputs]
    return registry.get(e.method).allocate(rupees(e.amount), inputs, CURRENCY)


def account_id(a: d.SeedAccount) -> uuid.UUID:
    """A bank SMS account has the id the app makes for its label."""
    user = seed_id("user", a.user)
    return (
        sms_account_id(user, a.sms_label)
        if a.sms_label
        else seed_id("account", f"{a.user}:{a.key}")
    )


def _account(p: d.SeedPersonal) -> uuid.UUID | None:
    """The account a seed entry moved: named by key, or by the label its bank SMS had."""
    if p.account:
        [a] = [a for a in d.ACCOUNTS if (a.user, a.key) == (p.user, p.account)]
        return account_id(a)
    if p.sms:
        found = [a for a in d.ACCOUNTS if (a.user, a.sms_label) == (p.user, p.sms.account)]
        return account_id(found[0]) if found else None
    return None


def _refunded(pid: list[uuid.UUID], refund: d.SeedPersonal) -> uuid.UUID:
    """The id of the spend a seed refund names by description."""
    [i] = [
        i
        for i, p in enumerate(d.PERSONAL)
        if p.user == refund.user and p.type == "expense" and p.description == refund.refund_of
    ]
    return pid[i]


def _entry(pid: list[uuid.UUID], c: d.SeedContribution) -> uuid.UUID:
    """The id of the entry a seed contribution names by description and direction."""
    description, direction = c.entry
    [i] = [
        i
        for i, p in enumerate(d.PERSONAL)
        if (p.user, p.description, p.direction or implied_direction(p.type))
        == (c.user, description, direction)
    ]
    return pid[i]


def _seed_account_id(user: str, key: str) -> uuid.UUID:
    return account_id(next(a for a in d.ACCOUNTS if (a.user, a.key) == (user, key)))


def _income(pid: list[uuid.UUID], user: str, source: tuple[str, d.date]) -> uuid.UUID:
    """The id of the income a seed plan names by description and date."""
    [i] = [
        i
        for i, p in enumerate(d.PERSONAL)
        if (p.user, p.type, p.description, p.day) == (user, "income", *source)
    ]
    return pid[i]


def reset(session: Session) -> None:
    tables = ", ".join(t.name for t in Base.metadata.sorted_tables)
    session.execute(text(f"TRUNCATE {tables} RESTART IDENTITY CASCADE"))


def load(session: Session) -> dict[str, int]:
    uid = {u.key: seed_id("user", u.key) for u in d.USERS}
    cat = {c.key: seed_id("category", c.key) for c in d.CATEGORIES}
    gid = {g.key: seed_id("group", g.key) for g in d.GROUPS}
    eid = {e.key: seed_id("expense", e.key) for e in d.EXPENSES}
    sid = {s.key: seed_id("settlement", s.key) for s in d.SETTLEMENTS}
    batch_id = seed_id("import_batch", "goa")

    password_hash = hash_password(d.DEV_PASSWORD)
    session.add_all(
        User(
            id=uid[u.key],
            name=u.name,
            email=u.email,
            password_hash=password_hash,
            role=u.role,
            currency=CURRENCY,
            created_at=d.at(d.date(2026, 6, 20)),
        )
        for u in d.USERS
    )
    # Migration 0009 adds the system categories and default dashboards; the seed's replace them
    # (nothing points at them yet: there are no users).
    session.execute(delete(AnalyticsConfiguration).where(AnalyticsConfiguration.owner_id.is_(None)))
    session.execute(delete(Category).where(Category.owner_id.is_(None)))
    session.add_all(
        Category(
            id=cat[c.key],
            key=c.key,
            label=c.label,
            icon=c.icon,
            scope=c.scope,
            sort=c.sort,
            kind=c.kind,
        )
        for c in d.CATEGORIES
    )
    session.flush()

    for g in d.GROUPS:
        session.add(
            Group(
                id=gid[g.key],
                name=g.name,
                icon=g.icon,
                currency=CURRENCY,
                created_by=uid[g.created_by],
                created_at=g.created,
            )
        )
        session.flush()
        session.add_all(
            GroupMember(
                group_id=gid[g.key],
                user_id=uid[m.user],
                role=m.role,
                joined_at=m.joined or g.created,
                placeholder_name=m.placeholder_name,
            )
            for m in g.members
        )

    imported = [e for e in d.EXPENSES if e.imported]
    batch = d.IMPORT_BATCH
    session.add(
        ImportBatch(
            id=batch_id,
            source="tricount",
            file_name=batch["file_name"],
            group_id=gid[batch["group"]],
            created_by=uid[batch["created_by"]],
            created_at=batch["created"],
            stats_json={"expenses": len(imported), "people": 6, "flagged": 3},
        )
    )
    session.flush()

    for e in d.EXPENSES:
        created = e.created or (batch["created"] if e.imported else d.at(e.day))
        created_by = e.created_by or (batch["created_by"] if e.imported else e.payer)
        updated = d.ADMIN_SESSION["started"] if e.acting_admin else created
        session.add(
            Expense(
                id=eid[e.key],
                group_id=gid[e.group],
                description=e.description,
                amount_minor=rupees(e.amount),
                currency=CURRENCY,
                payer_id=uid[e.payer],
                date=e.day,
                category_id=cat[e.category],
                notes=e.notes,
                split_method=e.method,
                import_batch_id=batch_id if e.imported else None,
                created_by=uid[created_by],
                acting_admin_id=uid[e.acting_admin] if e.acting_admin else None,
                created_at=created,
                updated_at=updated,
                deleted_at=e.deleted,
                splits=[
                    ExpenseSplit(
                        user_id=uid[s.user_id], share_minor=s.share_minor, input_value=s.input_value
                    )
                    for s in compute_splits(e)
                ],
            )
        )

    session.add_all(
        Settlement(
            id=sid[s.key],
            group_id=gid[s.group],
            from_user=uid[s.from_user],
            to_user=uid[s.to_user],
            amount_minor=rupees(s.amount),
            currency=CURRENCY,
            date=s.day,
            method=s.method,
            note=s.note,
            created_by=uid[s.from_user],
            created_at=s.created,
        )
        for s in d.SETTLEMENTS
    )
    session.add_all(
        PersonalAccount(
            id=account_id(a),
            user_id=uid[a.user],
            name=a.name,
            type=a.type,
            currency=CURRENCY,
            opening_balance_minor=rupees(a.opening),
            sms_label=a.sms_label,
            created_at=a.created,
            updated_at=a.created,
        )
        for a in d.ACCOUNTS
    )
    pid = [seed_id("personal", f"{p.user}:{i}") for i, p in enumerate(d.PERSONAL)]
    # Holdings point at accounts, and entries at expenses, payments, accounts and holdings:
    # with no relationship() between them the flush doesn't know to insert those first.
    session.flush()
    session.add_all(
        PersonalHolding(
            id=seed_id("holding", f"{h.user}:{h.key}"),
            user_id=uid[h.user],
            account_id=_seed_account_id(h.user, h.account),
            name=h.name,
            asset_type=h.asset_type,
            quantity=None if h.quantity is None else Decimal(h.quantity),
            cost_basis_minor=None if h.cost_basis is None else rupees(h.cost_basis),
            market_value_minor=rupees(h.market_value),
            valuation_at=h.valuation_at,
            currency=CURRENCY,
            created_at=h.created,
            updated_at=h.created,
        )
        for h in d.HOLDINGS
    )
    session.flush()
    session.add_all(
        PersonalTransaction(
            # Deterministic ids, so captured fixtures don't change on every reseed.
            id=pid[i],
            user_id=uid[p.user],
            type=p.type,
            direction=p.direction or implied_direction(p.type),
            amount_minor=rupees(p.amount),
            currency=CURRENCY,
            category_id=cat[p.category] if p.category else None,
            date=p.day,
            description=p.description,
            notes=p.notes,
            channel=p.channel,
            created_at=p.created or d.at(p.day, 9, 0),
            **(
                {
                    "source": "sms",
                    "merchant": p.sms.merchant,
                    "account": p.sms.account,
                    "reference": p.sms.reference,
                    "balance_minor": None if p.sms.balance is None else rupees(p.sms.balance),
                    "sms_at": p.created or d.at(p.day, 9, 0),
                    "reviewed": p.sms.reviewed,
                }
                if p.sms
                else {}
            ),
            account_id=_account(p),
            transfer_group_id=seed_id("transfer", f"{p.user}:{p.transfer}") if p.transfer else None,
            refund_of_id=_refunded(pid, p) if p.refund_of else None,
            holding_id=seed_id("holding", f"{p.user}:{p.holding}") if p.holding else None,
            expense_id=eid[p.expense] if p.expense else None,
            settlement_id=sid[p.settlement] if p.settlement else None,
        )
        for i, p in enumerate(d.PERSONAL)
    )
    session.add_all(
        PersonalGoal(
            id=seed_id("goal", f"{g.user}:{g.key}"),
            user_id=uid[g.user],
            name=g.name,
            target_minor=rupees(g.target),
            currency=CURRENCY,
            target_date=g.target_date,
            tracking_mode=g.mode,
            linked_account_id=_seed_account_id(g.user, g.account) if g.account else None,
            manual_progress_minor=None if g.manual_progress is None else rupees(g.manual_progress),
            priority=g.priority,
            status=g.status,
            created_at=g.created,
            updated_at=g.created,
        )
        for g in d.GOALS
    )
    # Contributions point at goals and entries.
    session.flush()
    session.add_all(
        PersonalGoalContribution(
            id=seed_id("goal_contribution", f"{c.user}:{i}"),
            user_id=uid[c.user],
            goal_id=seed_id("goal", f"{c.user}:{c.goal}"),
            transaction_id=_entry(pid, c) if c.entry else None,
            amount_minor=rupees(c.amount),
            currency=CURRENCY,
            date=c.day,
            note=c.note,
            created_at=c.created,
        )
        for i, c in enumerate(d.CONTRIBUTIONS)
    )
    rules = {(r.user, r.key): r for r in d.RULES}
    session.add_all(
        PersonalAllocationRule(
            id=seed_id("allocation_rule", f"{r.user}:{r.key}"),
            user_id=uid[r.user],
            name=r.name,
            kind=r.kind,
            percent_bp=r.percent_bp,
            amount_minor=None if r.amount is None else rupees(r.amount),
            currency=CURRENCY,
            goal_id=seed_id("goal", f"{r.user}:{r.goal}") if r.goal else None,
            account_id=_seed_account_id(r.user, r.account) if r.account else None,
            priority=r.priority,
            created_at=r.created,
            updated_at=r.created,
        )
        for r in d.RULES
    )
    # Plans point at rules and incomes.
    session.flush()
    for p in d.PLANS:
        rule = rules[(p.user, p.rule)]
        rule_id = seed_id("allocation_rule", f"{p.user}:{p.rule}")
        income = _income(pid, p.user, p.source)
        source = next(
            x
            for x in d.PERSONAL
            if (x.user, x.type, x.description, x.day) == (p.user, "income", *p.source)
        )
        made = source.created or d.at(source.day, 9, 0)  # made with its income
        session.add(
            PersonalAllocationPlan(
                id=plan_id(income, rule_id),
                user_id=uid[p.user],
                source_transaction_id=income,
                rule_id=rule_id,
                snapshot_kind=rule.kind,
                snapshot_percent_bp=rule.percent_bp,
                snapshot_amount_minor=None if rule.amount is None else rupees(rule.amount),
                planned_minor=rupees(p.planned),
                currency=CURRENCY,
                goal_id=seed_id("goal", f"{p.user}:{rule.goal}") if rule.goal else None,
                account_id=_seed_account_id(p.user, rule.account) if rule.account else None,
                created_at=made,
                updated_at=made,
            )
        )
    session.add_all(
        PersonalReminderSchedule(
            id=seed_id("reminder_schedule", f"{r.user}:{r.key}"),
            user_id=uid[r.user],
            goal_id=seed_id("goal", f"{r.user}:{r.goal}") if r.goal else None,
            holding_id=seed_id("holding", f"{r.user}:{r.holding}") if r.holding else None,
            day_of_month=r.day_of_month,
            amount_minor=None if r.amount is None else rupees(r.amount),
            currency=CURRENCY,
            created_at=r.created,
            updated_at=r.created,
        )
        for r in d.SCHEDULES
    )
    for r in d.REMINDER_STATES:
        key = f"{r.kind}:{seed_id('goal', f'{r.user}:{r.goal}')}:{r.window}"
        session.add(
            PersonalReminderState(
                id=reminder_state_id(uid[r.user], key),
                user_id=uid[r.user],
                dedup_key=key,
                status=r.status,
                created_at=r.created,
                updated_at=r.created,
            )
        )
    session.add_all(
        AnalyticsConfiguration(
            id=seed_id("analytics", f"{a.scope}:{a.position}"),
            scope=a.scope,
            owner_id=None,
            position=a.position,
            type=a.type,
            title=a.title,
            period=a.period,
            source=a.source,
            params_json=a.params,
        )
        for a in d.ANALYTICS
    )

    s = d.ADMIN_SESSION
    session.add(
        AdminSession(
            admin_id=uid[s["admin"]],
            target_user_id=uid[s["target"]],
            mode=s["mode"],
            started_at=s["started"],
            ended_at=s["ended"],
        )
    )
    entity_ids = {
        "expense": eid,
        "settlement": sid,
        "group": gid,
        "import_batch": {"import": batch_id},
    }
    session.add_all(
        AuditLog(
            at=when,
            actor_id=uid[actor] if actor else None,
            acting_as_id=uid[acting_as] if acting_as else None,
            action=action,
            entity=entity,
            entity_id=entity_ids[entity][key],
            diff_json=diff,
        )
        for when, actor, acting_as, action, entity, key, diff in d.AUDIT
    )

    # Activity feed for group writes made inside Splitkit (imports are summarised by the batch).
    for e in d.EXPENSES:
        if e.imported and not e.acting_admin:
            continue
        created = e.created or d.at(e.day)
        actor = e.created_by or e.payer
        if e.acting_admin:
            session.add(
                ActivityEvent(
                    group_id=gid[e.group],
                    actor_id=uid[d.ADMIN_SESSION["target"]],
                    acting_admin_id=uid[e.acting_admin],
                    type="expense.update",
                    entity="expense",
                    entity_id=eid[e.key],
                    at=d.at(d.sep(23), 21, 15),
                )
            )
            continue
        session.add(
            ActivityEvent(
                group_id=gid[e.group],
                actor_id=uid[actor],
                type="expense.create",
                entity="expense",
                entity_id=eid[e.key],
                at=created,
            )
        )
        if e.deleted:
            session.add(
                ActivityEvent(
                    group_id=gid[e.group],
                    actor_id=uid[actor],
                    type="expense.delete",
                    entity="expense",
                    entity_id=eid[e.key],
                    at=e.deleted,
                )
            )
    for st in d.SETTLEMENTS:
        session.add(
            ActivityEvent(
                group_id=gid[st.group],
                actor_id=uid[st.from_user],
                type="settlement.create",
                entity="settlement",
                entity_id=sid[st.key],
                at=st.created,
            )
        )
    kabir = next(m for m in d.GROUPS[0].members if m.user == "kabir")
    session.add(
        ActivityEvent(
            group_id=gid["goa"],
            actor_id=uid["kabir"],
            type="member.join",
            entity="group",
            entity_id=gid["goa"],
            at=kabir.joined,
        )
    )

    session.flush()
    return {
        "users": len(d.USERS),
        "categories": len(d.CATEGORIES),
        "groups": len(d.GROUPS),
        "expenses": len(d.EXPENSES),
        "settlements": len(d.SETTLEMENTS),
        "personal_transactions": len(d.PERSONAL),
        "personal_accounts": len(d.ACCOUNTS),
        "personal_goals": len(d.GOALS),
        "goal_contributions": len(d.CONTRIBUTIONS),
        "allocation_rules": len(d.RULES),
        "allocation_plans": len(d.PLANS),
        "holdings": len(d.HOLDINGS),
        "reminder_schedules": len(d.SCHEDULES),
        "reminder_states": len(d.REMINDER_STATES),
        "analytics_cards": len(d.ANALYTICS),
    }
