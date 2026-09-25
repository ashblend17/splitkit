import uuid
from collections.abc import Iterator
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    TIMESTAMP,
    UUID,
    Date,
    MetaData,
    Numeric,
    Text,
    create_engine,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

from app.core.config import get_settings

NAMING = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING)
    type_annotation_map = {
        uuid.UUID: UUID(as_uuid=True),
        str: Text(),
        datetime: TIMESTAMP(timezone=True),
        date: Date(),
        Decimal: Numeric(14, 4),
        dict[str, Any]: JSONB(),
    }


def uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(primary_key=True, server_default=text("gen_random_uuid()"))


def now_default() -> Mapped[datetime]:
    return mapped_column(server_default=text("now()"))


engine = create_engine(get_settings().database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(engine, expire_on_commit=False)


def get_session() -> Iterator[Session]:
    with SessionLocal() as session:
        yield session
