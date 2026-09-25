"""Optimistic concurrency and client-made ids, for clients that write while offline.

- Updates and deletes may send the `version` they were editing. If the row has moved on, the
  write is refused with 409 `version_conflict` instead of overwriting someone else's change.
  Two writes racing on the same row are caught by SQLAlchemy's version counter as well
  (StaleDataError), which becomes the same 409.
- Creates may send their own `id` (a UUID the device made). Sending the same create again
  returns the existing row, so a retry after a dropped connection never makes a duplicate.
"""

from collections.abc import Callable
from typing import Any

from sqlalchemy.orm import Session

from app.core.errors import ApiError

CONFLICT_MESSAGE = "Someone changed this while you were editing it. Check the latest version."


def version_conflict(current: int | None = None) -> ApiError:
    return ApiError(409, "version_conflict", CONFLICT_MESSAGE, current_version=current)


def check_version(obj: Any, expected: int | None) -> None:
    if expected is not None and expected != obj.version:
        raise version_conflict(obj.version)


def replayed_create[T](
    session: Session, model: type[T], client_id: Any, is_mine: Callable[[T], bool]
) -> T | None:
    """The row a repeated create already made, or None for a fresh create. An id that belongs
    to someone else's row is refused."""
    if client_id is None:
        return None
    existing = session.get(model, client_id)
    if existing is None:
        return None
    if not is_mine(existing):
        raise ApiError(409, "id_taken", "That id is already used by something else")
    return existing


def client_id(value: Any) -> dict[str, Any]:
    """Constructor kwargs for a client-made id: `Model(**client_id(body.id), ...)`. Leaves the
    id out when there is none, so the database default makes one."""
    return {} if value is None else {"id": value}
