import uuid
from typing import Annotated

from fastapi import APIRouter, File, Form, UploadFile

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.import_tricount import service
from app.modules.import_tricount.parser import MAX_BYTES
from app.modules.import_tricount.schemas import ImportBatchOut, ImportPreviewOut

router = APIRouter(tags=["import"])


def _read(file: UploadFile) -> tuple[str, bytes]:
    # One byte over the limit is enough to refuse the file without reading all of it.
    return file.filename or "tricount.csv", file.file.read(MAX_BYTES + 1)


@router.post("/import/tricount/preview", response_model=ImportPreviewOut)
def preview_tricount(
    file: Annotated[UploadFile, File(description="Tricount export, CSV or XLSX")],
    actor: CurrentActor,
    session: DbSession,
    group_id: Annotated[uuid.UUID | None, Form()] = None,
    currency: Annotated[str | None, Form()] = None,
):
    """Read a Tricount export and suggest how to map it. Saves nothing.

    `group_id`: import into this group (people are matched against its members).
    Otherwise a new group is assumed; `currency` sets its currency (default: the file's).
    """
    name, content = _read(file)
    return service.preview(session, actor, name, content, group_id, currency)


@router.post("/import/tricount/commit", response_model=ImportBatchOut, status_code=201)
def commit_tricount(
    file: Annotated[UploadFile, File(description="The same file that was previewed")],
    options: Annotated[str, Form(description="ImportCommitIn as JSON")],
    actor: CurrentActor,
    session: DbSession,
):
    """Import the file in one go, as one batch that can be undone.

    `options` is JSON: `{"group_id": …}` or `{"new_group": {"name", "currency", "icon"}}`,
    plus `people` (`[{"name", "user_id"}]`; no `user_id` makes a placeholder member) and
    `categories` (`{"Tricount category": "key"}`; anything unmapped becomes Other).
    """
    name, content = _read(file)
    return service.commit(session, actor, name, content, service.parse_options(options))


@router.get("/import/batches", response_model=list[ImportBatchOut])
def list_import_batches(actor: CurrentActor, session: DbSession):
    """Your imports, newest first."""
    return service.list_batches(session, actor)


@router.get("/import/batches/{batch_id}", response_model=ImportBatchOut)
def get_import_batch(batch_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.get_batch(session, actor, batch_id)


@router.post("/import/batches/{batch_id}/undo", response_model=ImportBatchOut)
def undo_import_batch(batch_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    """Remove everything this import created (soft deletes, so items can be restored one by
    one). Calling it again changes nothing."""
    return service.undo(session, actor, batch_id)
