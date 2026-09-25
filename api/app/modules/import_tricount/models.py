import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import ForeignKey, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, now_default, uuid_pk


class ImportBatch(Base):
    """Everything an import creates carries this batch's id, so the batch can be undone."""

    __tablename__ = "import_batches"

    id: Mapped[uuid.UUID] = uuid_pk()
    source: Mapped[str] = mapped_column(server_default="tricount")
    file_name: Mapped[str]
    group_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("groups.id"))
    stats_json: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
    created_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = now_default()
    undone_at: Mapped[datetime | None]
