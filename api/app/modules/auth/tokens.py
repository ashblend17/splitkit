import uuid
from datetime import UTC, datetime, timedelta

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


def decode_access_token(token: str) -> uuid.UUID | None:
    try:
        claims = jwt.decode(token, get_settings().jwt_secret, algorithms=[ALGORITHM])
        return uuid.UUID(claims["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
