"""Writes app.seed.data into the database. Ids are deterministic (uuid5) so they are stable
across reseeds, which keeps client fixtures and bookmarks working."""

import uuid
from decimal import Decimal

from sqlalchemy import text
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
    PersonalTransaction,
    Settlement,
    User,
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
    session.add_all(
        Category(id=cat[c.key], key=c.key, label=c.label, icon=c.icon, scope=c.scope, sort=c.sort)
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
        PersonalTransaction(
            user_id=uid[p.user],
            type=p.type,
            amount_minor=rupees(p.amount),
            currency=CURRENCY,
            category_id=cat[p.category],
            date=p.day,
            description=p.description,
            notes=p.notes,
            created_at=p.created or d.at(p.day, 9, 0),
        )
        for p in d.PERSONAL
    )
    session.add_all(
        AnalyticsConfiguration(
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
        "analytics_cards": len(d.ANALYTICS),
    }
