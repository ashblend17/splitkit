import uuid
from collections import defaultdict

from sqlalchemy.orm import Session

from app.modules.auth.deps import Actor
from app.modules.balances import repository as ledger
from app.modules.balances.engine import pairwise, positions, simplify
from app.modules.balances.schemas import (
    CurrencyTotals,
    FriendBalance,
    GroupBalancesOut,
    GroupNet,
    OverallBalancesOut,
    PersonBalance,
    SuggestedPayment,
)
from app.modules.groups import repository as groups
from app.modules.groups.service import require_member
from app.modules.users import repository as users
from app.modules.users.schemas import brief


def _order(net: int, name: str) -> tuple:
    """You owe first, then owed to you (largest first), then settled up, then by name."""
    return (0 if net < 0 else 1 if net > 0 else 2, -abs(net), name)


def _split_totals(nets: list[int]) -> tuple[int, int]:
    return sum(-n for n in nets if n < 0), sum(n for n in nets if n > 0)


def group_balances(session: Session, actor: Actor, group_id: uuid.UUID) -> GroupBalancesOut:
    group = require_member(session, group_id, actor.user_id)
    me = actor.user_id
    flows = ledger.flows_by_group(session, [group_id]).get(group_id, [])
    pair = pairwise(me, flows)
    pos = positions(flows)
    active = {m.user_id for m, _ in groups.active_members(session, group_id)}

    people_ids = (active | {p for p, n in pair.items() if n}) - {me}
    member_ids = active | {p for p, n in pos.items() if n}
    people = users.get_many(session, people_ids | member_ids)

    you_owe, owed = _split_totals([pair.get(p, 0) for p in people_ids])
    return GroupBalancesOut(
        group_id=group_id,
        currency=group.currency,
        net_minor=pos.get(me, 0),
        you_owe_minor=you_owe,
        you_are_owed_minor=owed,
        people=sorted(
            (PersonBalance(user=brief(people[p]), net_minor=pair.get(p, 0)) for p in people_ids),
            key=lambda b: _order(b.net_minor, b.user.name),
        ),
        members=sorted(
            (PersonBalance(user=brief(people[p]), net_minor=pos.get(p, 0)) for p in member_ids),
            key=lambda b: _order(b.net_minor, b.user.name),
        ),
        suggested=[
            SuggestedPayment(
                from_user=brief(people[f.debtor]),
                to_user=brief(people[f.creditor]),
                amount_minor=f.amount,
            )
            for f in simplify({p: n for p, n in pos.items() if n})
        ],
    )


def overall_balances(session: Session, actor: Actor) -> OverallBalancesOut:
    me = actor.user_id
    all_groups = groups.groups_for_user(session, me, include_left=True)
    current = {g.id for g in groups.groups_for_user(session, me)}
    flows = ledger.flows_by_group(session, [g.id for g in all_groups])

    friend_nets: dict[tuple[uuid.UUID, str], int] = defaultdict(int)
    group_nets = []
    for g in all_groups:
        for person, net in pairwise(me, flows.get(g.id, [])).items():
            friend_nets[(person, g.currency)] += net
        if g.id in current:
            for m, _ in groups.active_members(session, g.id):
                if m.user_id != me:
                    friend_nets.setdefault((m.user_id, g.currency), 0)
            group_nets.append(
                GroupNet(
                    group_id=g.id,
                    name=g.name,
                    currency=g.currency,
                    net_minor=positions(flows.get(g.id, [])).get(me, 0),
                )
            )

    people = users.get_many(session, [p for p, _ in friend_nets])
    by_currency: dict[str, list[int]] = defaultdict(list)
    for (_, currency), net in friend_nets.items():
        by_currency[currency].append(net)
    totals = []
    for currency, nets in sorted(by_currency.items()):
        you_owe, owed = _split_totals(nets)
        totals.append(
            CurrencyTotals(
                currency=currency,
                net_minor=sum(nets),
                you_owe_minor=you_owe,
                you_are_owed_minor=owed,
            )
        )
    return OverallBalancesOut(
        totals=totals,
        friends=sorted(
            (
                FriendBalance(user=brief(people[p]), currency=c, net_minor=n)
                for (p, c), n in friend_nets.items()
            ),
            key=lambda f: _order(f.net_minor, f.user.name),
        ),
        groups=group_nets,
    )
