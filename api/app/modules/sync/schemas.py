import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import Field

from app.core.schemas import Schema


class SyncIn(Schema):
    cursors: dict[str, int] = Field(default_factory=dict)
    """The last seq you applied, per stream (`group:<id>`, `user:<id>`, `global`). Leave a
    stream out to be told it needs a snapshot."""
    limit: int = Field(default=500, ge=1, le=1000)
    """Most changes per stream in one response. Call again while `has_more` is true."""


class SyncChange(Schema):
    seq: int
    action: str
    """What happened, e.g. expense.update, member.leave."""
    entity: str
    """expense, settlement, group, member, membership, personal_transaction, category, profile
    or layout."""
    entity_id: uuid.UUID
    """Unique per entity type within the stream. For members it is the user's id; for
    memberships, the group's id."""
    op: Literal["upsert", "delete"]
    """upsert: replace your copy with `data`. delete: remove it (soft deletes are upserts with
    `deleted_at` set)."""
    version: int | None
    data: dict[str, Any] | None
    actor_id: uuid.UUID | None
    acting_admin_id: uuid.UUID | None
    at: datetime


class SyncStreamOut(Schema):
    stream: str
    status: Literal["ok", "snapshot_required", "gone"]
    """ok: apply `changes` in order, then store the last seq. snapshot_required: load
    GET /sync/snapshot/{stream} instead (new stream, or your cursor is too old or unknown).
    gone: you no longer have access; delete your local copy."""
    head_seq: int
    changes: list[SyncChange]
    has_more: bool


class SyncOut(Schema):
    streams: list[SyncStreamOut]
    """Every stream you can see, plus any cursor you sent that is now gone."""


class SyncEntity(Schema):
    entity: str
    entity_id: uuid.UUID
    version: int | None
    data: dict[str, Any]


class SyncSnapshotOut(Schema):
    stream: str
    head_seq: int
    """Store this as your cursor after replacing your copy of the stream with `entities`."""
    entities: list[SyncEntity]
