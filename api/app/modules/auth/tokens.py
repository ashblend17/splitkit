import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt

from app.core.config import get_settings

ALGORITHM = "HS256"


def create_access_token(user_id: uuid.UUID) -> tuple[str, int]:
    """Returns (token, lifetime in seconds)."""
    settings = get_settings()
    lifetime = timedelta(minutes=settings.jwt_ttl_minutes)
    now = datetime.now(UTC)
    claims = {"sub": str(user_id), "iat": now, "exp": now + lifetime}
    return jwt.encode(claims, settings.jwt_secret, algorithm=ALGORITHM), int(
        lifetime.total_seconds()
    )


def create_impersonation_token(
    target_id: uuid.UUID,
    admin_id: uuid.UUID,
    session_id: uuid.UUID,
    mode: str,
    expires_at: datetime,
) -> str:
    """A token for `target_id` that also names the admin and their admin session.

    `sub` is the target, so every route sees the target as the current user. `adm` and `sid`
    say who is really acting. `mode` is informational: `get_actor` reads the mode from the
    session row, so switching mode or ending the session takes effect at once."""
    claims = {
        "sub": str(target_id),
        "adm": str(admin_id),
        "sid": str(session_id),
        "mode": mode,
        "iat": datetime.now(UTC),
        "exp": expires_at,
    }
    return jwt.encode(claims, get_settings().jwt_secret, algorithm=ALGORITHM)


def decode_claims(token: str) -> dict[str, Any] | None:
    """The verified claims (signature and expiry checked), or None."""
    try:
        claims = jwt.decode(token, get_settings().jwt_secret, algorithms=[ALGORITHM])
        uuid.UUID(claims["sub"])
        return claims
    except (jwt.PyJWTError, KeyError, ValueError, TypeError):
        return None


def decode_access_token(token: str) -> uuid.UUID | None:
    claims = decode_claims(token)
    return uuid.UUID(claims["sub"]) if claims else None
