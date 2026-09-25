import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.balances import repository as ledger
from app.modules.balances.engine import positions
from app.modules.groups import repository as repo
from app.modules.groups.models import Group, GroupMember
from app.modules.groups.schemas import AddMemberIn, GroupIn, GroupOut, GroupUpdate, MemberOut
from app.modules.users import repository as users
from app.modules.users.models import User
from app.modules.users.schemas import brief


def require_member(session: Session, group_id: uuid.UUID, user_id: uuid.UUID) -> Group:
    """The group, if `user_id` is a current member. Otherwise 404, so ids don't leak."""
    member = repo.membership(session, group_id, user_id)
    if member is None or member.left_at is not None:
        raise not_found("Group")
    return session.get(Group, group_id)


def active_member_ids(session: Session, group_id: uuid.UUID) -> set[uuid.UUID]:
    return {m.user_id for m, _ in repo.active_members(session, group_id)}


def _to_out(session: Session, groups: list[Group], me: uuid.UUID) -> list[GroupOut]:
    ids = [g.id for g in groups]
    spent = repo.total_spent(session, ids)
    last = repo.last_activity(session, ids)
    flows = ledger.flows_by_group(session, ids)
    return [
        GroupOut(
            id=g.id,
            name=g.name,
            icon=g.icon,
            currency=g.currency,
            created_at=g.created_at,
            archived_at=g.archived_at,
            members=[
                MemberOut(
                    user=brief(u),
                    role=m.role,
                    joined_at=m.joined_at,
                    placeholder_name=m.placeholder_name,
                )
                for m, u in repo.active_members(session, g.id)
            ],
            total_spent_minor=spent.get(g.id, 0),
            my_net_minor=positions(flows.get(g.id, [])).get(me, 0),
            last_activity_at=last.get(g.id),
            version=g.version,
        )
        for g in groups
    ]


def list_groups(session: Session, actor: Actor, archived: bool) -> list[GroupOut]:
    groups = [
        g
        for g in repo.groups_for_user(session, actor.user_id)
        if (g.archived_at is not None) == archived
    ]
    return _to_out(session, groups, actor.user_id)


def get_group(session: Session, actor: Actor, group_id: uuid.UUID) -> GroupOut:
    return _to_out(session, [require_member(session, group_id, actor.user_id)], actor.user_id)[0]


def create_group(session: Session, actor: Actor, body: GroupIn) -> GroupOut:
    actor.require_write()
    replay = replayed_create(session, Group, body.id, lambda g: g.created_by == actor.user_id)
    if replay is not None:
        return get_group(session, actor, replay.id)
    group = Group(
        **client_id(body.id),
        name=body.name.strip(),
        icon=body.icon,
        currency=body.currency,
        created_by=actor.user_id,
    )
    session.add(group)
    session.flush()
    owner = GroupMember(group_id=group.id, user_id=actor.user_id, role="owner")
    session.add(owner)
    record(
        session,
        actor,
        "group.create",
        "group",
        group.id,
        group.id,
        {"name": group.name},
        obj=[group, owner],
    )
    session.commit()
    return get_group(session, actor, group.id)


def update_group(
    session: Session, actor: Actor, group_id: uuid.UUID, body: GroupUpdate
) -> GroupOut:
    actor.require_write()
    group = require_member(session, group_id, actor.user_id)
    check_version(group, body.version)
    diff = {}
    if body.name is not None and body.name.strip() != group.name:
        diff["name"] = {"from": group.name, "to": body.name.strip()}
        group.name = body.name.strip()
    if body.icon is not None and body.icon != group.icon:
        diff["icon"] = {"from": group.icon, "to": body.icon}
        group.icon = body.icon
    if body.archived is not None and body.archived != (group.archived_at is not None):
        diff["archived"] = {"from": not body.archived, "to": body.archived}
        group.archived_at = datetime.now(UTC) if body.archived else None
    if diff:
        record(session, actor, "group.update", "group", group.id, group.id, diff, obj=group)
    session.commit()
    return get_group(session, actor, group_id)


def add_member(session: Session, actor: Actor, group_id: uuid.UUID, body: AddMemberIn) -> GroupOut:
    actor.require_write()
    require_member(session, group_id, actor.user_id)
    if body.email is not None:
        user = users.get_by_email(session, body.email)
        if user is None:
            raise ApiError(404, "no_account", "There's no Splitkit account with that email yet")
        placeholder_name = None
    else:
        user = User(name=body.name.strip())
        session.add(user)
        session.flush()
        record(session, actor, "user.create_placeholder", "user", user.id, diff={"name": user.name})
        placeholder_name = user.name

    existing = repo.membership(session, group_id, user.id)
    if existing is not None and existing.left_at is None:
        raise ApiError(409, "already_member", f"{user.name} is already in this group")
    if existing is not None:
        existing.left_at = None  # rejoining keeps their history
        member = existing
    else:
        member = GroupMember(group_id=group_id, user_id=user.id, placeholder_name=placeholder_name)
        session.add(member)
    record(
        session,
        actor,
        "member.add",
        "group",
        group_id,
        group_id,
        {"user_id": str(user.id)},
        obj=member,
    )
    session.commit()
    return get_group(session, actor, group_id)


def remove_member(session: Session, actor: Actor, group_id: uuid.UUID, user_id: uuid.UUID) -> None:
    actor.require_write()
    require_member(session, group_id, actor.user_id)
    me = repo.membership(session, group_id, actor.user_id)
    target = repo.membership(session, group_id, user_id)
    if target is None or target.left_at is not None:
        raise not_found("Member")
    if user_id != actor.user_id and me.role != "owner":
        raise ApiError(403, "not_owner", "Only the group owner can remove other people")
    net = positions(ledger.flows_by_group(session, [group_id]).get(group_id, [])).get(user_id, 0)
    if net != 0:
        who = "You need" if user_id == actor.user_id else "They need"
        raise ApiError(409, "unsettled", f"{who} to settle up before leaving the group")
    target.left_at = datetime.now(UTC)
    action = "member.leave" if user_id == actor.user_id else "member.remove"
    record(
        session, actor, action, "group", group_id, group_id, {"user_id": str(user_id)}, obj=target
    )
    session.commit()
