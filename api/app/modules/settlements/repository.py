import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.settlements.models import Settlement


def for_group(session: Session, group_id: uuid.UUID) -> list[Settlement]:
    return list(
        session.scalars(
            select(Settlement)
            .where(Settlement.group_id == group_id, Settlement.deleted_at.is_(None))
            .order_by(Settlement.date.desc(), Settlement.created_at.desc(), Settlement.id.desc())
        )
    )
