"""Records every write: in audit_logs (the permanent admin audit trail), in activity_events for
group writes (activity lists and the V2 notifier), and in the sync change log (full state for
offline clients, see app/modules/sync/log.py). Called inside the writing transaction."""

import uuid
from typing import TYPE_CHECKING, Any

from sqlalchemy.orm import Session

from app.modules.admin.models import AuditLog
from app.modules.groups.models import ActivityEvent
from app.modules.sync import log as sync_log

if TYPE_CHECKING:
    from app.modules.auth.deps import Actor


def record(
    session: Session,
    actor: "Actor",
    action: str,
    entity: str,
    entity_id: uuid.UUID,
    group_id: uuid.UUID | None = None,
    diff: dict[str, Any] | None = None,
    obj: Any = None,
    deleted: bool = False,
) -> None:
    """`obj` is what changed (a model instance, or a list of them) and goes to the sync log.
    Pass `deleted=True` before a hard delete so clients get a tombstone."""
    admin_id = actor.admin_id
    session.add(
        AuditLog(
            actor_id=admin_id or actor.user_id,
            acting_as_id=actor.user_id if admin_id else None,
            action=action,
            entity=entity,
            entity_id=entity_id,
            diff_json=diff or {},
        )
    )
    if group_id is not None:
        session.add(
            ActivityEvent(
                group_id=group_id,
                actor_id=actor.user_id,
                acting_admin_id=admin_id,
                type=action,
                entity=entity,
                entity_id=entity_id,
            )
        )
    changed = obj if isinstance(obj, list | tuple) else [] if obj is None else [obj]
    for o in changed:
        sync_log.track(session, actor, action, o, deleted)
