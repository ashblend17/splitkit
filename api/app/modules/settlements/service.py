import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.balances import repository as ledger
from app.modules.balances.engine import pairwise
from app.modules.groups import repository as groups
from app.modules.groups.models import Group
from app.modules.groups.service import active_member_ids, require_member
from app.modules.settlements import repository as repo
from app.modules.settlements.models import Settlement
from app.modules.settlements.planner import GroupBalance, SettleUpError, plan_settle_up
from app.modules.settlements.schemas import (
    FriendGroupBalance,
    SettlementIn,
    SettlementOut,
    SettleUpIn,
    SettleUpOut,
    SettleUpPlanOut,
)
from app.modules.users import repository as users
from app.modules.users.models import User
from app.modules.users.schemas import brief


def to_out_many(session: Session, rows: list[Settlement]) -> list[SettlementOut]:
    people = users.get_many(
        session, [u for s in rows for u in (s.from_user, s.to_user, s.created_by)]
    )
    return [
        SettlementOut(
            id=s.id,
            group_id=s.group_id,
            from_user=brief(people[s.from_user]),
            to_user=brief(people[s.to_user]),
            amount_minor=s.amount_minor,
            currency=s.currency,
            date=s.date,
            method=s.method,
            note=s.note,
            created_by=brief(people[s.created_by]),
            acting_admin_id=s.acting_admin_id,
            created_at=s.created_at,
            deleted_at=s.deleted_at,
            version=s.version,
        )
        for s in rows
    ]


def _load(session: Session, actor: Actor, settlement_id: uuid.UUID) -> Settlement:
    settlement = session.get(Settlement, settlement_id)
    if settlement is None:
        raise not_found("Payment")
    require_member(session, settlement.group_id, actor.user_id)
    return settlement


def list_settlements(session: Session, actor: Actor, group_id: uuid.UUID) -> list[SettlementOut]:
    require_member(session, group_id, actor.user_id)
    return to_out_many(session, repo.for_group(session, group_id))


def get_settlement(session: Session, actor: Actor, settlement_id: uuid.UUID) -> SettlementOut:
    return to_out_many(session, [_load(session, actor, settlement_id)])[0]


def create_settlement(
    session: Session, actor: Actor, group_id: uuid.UUID, body: SettlementIn
) -> SettlementOut:
    actor.require_write()
    group = require_member(session, group_id, actor.user_id)
    replay = replayed_create(
        session,
        Settlement,
        body.id,
        lambda s: s.group_id == group_id and s.created_by == actor.user_id,
    )
    if replay is not None:
        return get_settlement(session, actor, replay.id)
    if body.from_user == body.to_user:
        raise ApiError(422, "same_person", "A payment needs two different people")
    members = active_member_ids(session, group_id)
    if body.from_user not in members or body.to_user not in members:
        raise ApiError(422, "not_member", "Both people have to be in this group")
    settlement = Settlement(
        **client_id(body.id),
        group_id=group_id,
        from_user=body.from_user,
        to_user=body.to_user,
        amount_minor=body.amount_minor,
        currency=group.currency,
        date=body.date,
        method=body.method,
        note=body.note,
        created_by=actor.user_id,
        acting_admin_id=actor.admin_id,
    )
    session.add(settlement)
    session.flush()
    record(
        session,
        actor,
        "settlement.create",
        "settlement",
        settlement.id,
        group_id,
        {
            "amount_minor": settlement.amount_minor,
            "from_user": str(body.from_user),
            "to_user": str(body.to_user),
        },
        obj=settlement,
    )
    session.commit()
    return get_settlement(session, actor, settlement.id)


def set_deleted(
    session: Session,
    actor: Actor,
    settlement_id: uuid.UUID,
    deleted: bool,
    version: int | None = None,
) -> SettlementOut:
    actor.require_write()
    settlement = _load(session, actor, settlement_id)
    if (settlement.deleted_at is not None) != deleted:
        check_version(settlement, version)
        settlement.deleted_at = datetime.now(UTC) if deleted else None
        action = "settlement.delete" if deleted else "settlement.restore"
        record(
            session, actor, action, "settlement", settlement.id, settlement.group_id, obj=settlement
        )
        session.commit()
    return get_settlement(session, actor, settlement_id)


def _shared_balances(
    session: Session, actor: Actor, friend_id: uuid.UUID, currency: str
) -> tuple[User, list[tuple[Group, int]]]:
    """Your pairwise balance with a friend in each group you are both current members of,
    oldest group first. Positive: they owe you."""
    friend = session.get(User, friend_id)
    if friend is None or friend_id == actor.user_id:
        raise not_found("Person")
    mine = {g.id: g for g in groups.groups_for_user(session, actor.user_id)}
    shared = [
        g
        for g in groups.groups_for_user(session, friend_id)
        if g.id in mine and g.currency == currency
    ]
    if not shared:
        raise not_found("Person")
    shared.sort(key=lambda g: g.created_at)
    flows = ledger.flows_by_group(session, [g.id for g in shared])
    return friend, [
        (g, pairwise(actor.user_id, flows.get(g.id, [])).get(friend_id, 0)) for g in shared
    ]


def settle_up_plan(
    session: Session, actor: Actor, friend_id: uuid.UUID, currency: str | None
) -> SettleUpPlanOut:
    currency = currency or actor.user.currency
    friend, balances = _shared_balances(session, actor, friend_id, currency)
    return SettleUpPlanOut(
        friend=brief(friend),
        currency=currency,
        net_minor=sum(net for _, net in balances),
        groups=[
            FriendGroupBalance(group_id=g.id, name=g.name, net_minor=net)
            for g, net in balances
            if net
        ],
    )


def settle_up(
    session: Session, actor: Actor, friend_id: uuid.UUID, body: SettleUpIn
) -> SettleUpOut:
    """Record a payment with a friend as one settlement per group, in one transaction."""
    actor.require_write()
    currency = body.currency or actor.user.currency
    _, balances = _shared_balances(session, actor, friend_id, currency)
    try:
        plan = plan_settle_up([GroupBalance(g.id, net) for g, net in balances], body.amount_minor)
    except SettleUpError as e:
        raise ApiError(422, "settle_up_invalid", str(e)) from None

    created = []
    for p in plan:
        frm, to = (friend_id, actor.user_id) if p.friend_pays else (actor.user_id, friend_id)
        settlement = Settlement(
            group_id=p.group_id,
            from_user=frm,
            to_user=to,
            amount_minor=p.amount_minor,
            currency=currency,
            date=body.date,
            method=body.method,
            note=body.note,
            created_by=actor.user_id,
            acting_admin_id=actor.admin_id,
        )
        session.add(settlement)
        session.flush()
        record(
            session,
            actor,
            "settlement.create",
            "settlement",
            settlement.id,
            p.group_id,
            {
                "amount_minor": p.amount_minor,
                "from_user": str(frm),
                "to_user": str(to),
                "via": "settle_up",
            },
            obj=settlement,
        )
        created.append(settlement)
    session.commit()

    remaining = settle_up_plan(session, actor, friend_id, currency).net_minor
    return SettleUpOut(settlements=to_out_many(session, created), remaining_net_minor=remaining)
