"""Catching clients up: changes after their cursors, or a full snapshot of one stream."""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.db import engine
from app.core.errors import not_found
from app.modules.analytics.models import AnalyticsConfiguration
from app.modules.auth.deps import Actor
from app.modules.categories.models import Category
from app.modules.expenses.models import Expense
from app.modules.groups.models import Group, GroupMember
from app.modules.personal.models import PersonalTransaction
from app.modules.settlements.models import Settlement
from app.modules.sync import log
from app.modules.sync.models import ChangeLog, SyncStream
from app.modules.sync.schemas import (
    SyncChange,
    SyncEntity,
    SyncIn,
    SyncOut,
    SyncSnapshotOut,
    SyncStreamOut,
)
from app.modules.users.models import User

# Snapshots read every table of a stream plus its head in one consistent view.
_snapshot_engine = engine.execution_options(isolation_level="REPEATABLE READ")


def visible_streams(session: Session, user_id: uuid.UUID) -> list[str]:
    groups = session.scalars(
        select(GroupMember.group_id).where(
            GroupMember.user_id == user_id, GroupMember.left_at.is_(None)
        )
    )
    return [log.GLOBAL, log.user_stream(user_id), *sorted(log.group_stream(g) for g in groups)]


def sync(session: Session, actor: Actor, body: SyncIn) -> SyncOut:
    streams = visible_streams(session, actor.user_id)
    heads = {s.id: s for s in session.scalars(select(SyncStream).where(SyncStream.id.in_(streams)))}
    out = []
    for stream in streams:
        head = heads[stream].head_seq if stream in heads else 0
        oldest = heads[stream].oldest_seq if stream in heads else 0
        cursor = body.cursors.get(stream)
        # Unknown, trimmed away, or ahead of the server (the database was reset).
        if cursor is None or cursor < oldest or cursor > head:
            out.append(
                SyncStreamOut(
                    stream=stream,
                    status="snapshot_required",
                    head_seq=head,
                    changes=[],
                    has_more=False,
                )
            )
            continue
        rows = list(
            session.scalars(
                select(ChangeLog)
                .where(ChangeLog.stream_id == stream, ChangeLog.seq > cursor)
                .order_by(ChangeLog.seq)
                .limit(body.limit + 1)
            )
        )
        out.append(
            SyncStreamOut(
                stream=stream,
                status="ok",
                head_seq=head,
                changes=[SyncChange.model_validate(r) for r in rows[: body.limit]],
                has_more=len(rows) > body.limit,
            )
        )
    for stream in sorted(set(body.cursors) - set(streams)):
        out.append(
            SyncStreamOut(stream=stream, status="gone", head_seq=0, changes=[], has_more=False)
        )
    return SyncOut(streams=out)


def snapshot(session: Session, actor: Actor, stream: str) -> SyncSnapshotOut:
    if stream not in visible_streams(session, actor.user_id):
        raise not_found("Stream")
    with Session(_snapshot_engine) as snap:
        head = snap.scalar(select(SyncStream.head_seq).where(SyncStream.id == stream)) or 0
        entries = [e for obj in _objects(snap, stream) for e in log.entries_for(snap, obj)]
        layouts = _layouts(snap, stream)
    entities = [
        SyncEntity(entity=e.entity, entity_id=e.entity_id, version=e.version, data=e.data)
        for e in [*entries, *layouts]
        if e.stream == stream and e.op == "upsert"
    ]
    return SyncSnapshotOut(stream=stream, head_seq=head, entities=entities)


def _objects(snap: Session, stream: str) -> list:
    kind, _, raw_id = stream.partition(":")
    if kind == "group":
        gid = uuid.UUID(raw_id)
        return [
            snap.get(Group, gid),
            *snap.scalars(select(GroupMember).where(GroupMember.group_id == gid)),
            *snap.scalars(
                select(Expense).options(selectinload(Expense.splits)).where(Expense.group_id == gid)
            ),
            *snap.scalars(select(Settlement).where(Settlement.group_id == gid)),
        ]
    if kind == "user":
        uid = uuid.UUID(raw_id)
        return [
            snap.get(User, uid),  # its member entries belong to group streams and are dropped
            *snap.scalars(select(GroupMember).where(GroupMember.user_id == uid)),
            *snap.scalars(select(PersonalTransaction).where(PersonalTransaction.user_id == uid)),
            *snap.scalars(select(Category).where(Category.owner_id == uid)),
        ]
    return list(snap.scalars(select(Category).where(Category.owner_id.is_(None))))


def _layouts(snap: Session, stream: str) -> list[log.Entry]:
    kind, _, raw_id = stream.partition(":")
    if kind == "group":
        return []
    owner = uuid.UUID(raw_id) if kind == "user" else None
    rows = snap.scalars(
        select(AnalyticsConfiguration).where(
            AnalyticsConfiguration.owner_id.is_(None)
            if owner is None
            else AnalyticsConfiguration.owner_id == owner
        )
    )
    by_scope: dict[str, list] = {}
    for r in rows:
        by_scope.setdefault(r.scope, []).append(r)
    return [log.layout_entry(owner, scope, rs) for scope, rs in sorted(by_scope.items())]
