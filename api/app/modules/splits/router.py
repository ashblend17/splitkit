import uuid

from fastapi import APIRouter

from app.modules.auth.deps import CurrentActor
from app.modules.splits import service
from app.modules.splits.engine import registry
from app.modules.splits.schemas import ShareOut, SplitMethodOut, SplitPreviewIn, SplitPreviewOut

router = APIRouter(prefix="/splits", tags=["splits"])


@router.get("/methods", response_model=list[SplitMethodOut])
def list_methods(_: CurrentActor):
    """The registered split methods, in the order the selector shows them."""
    return [
        SplitMethodOut(key=m.key, label=m.label, symbol=m.symbol, hint=m.hint)
        for m in registry.all()
    ]


@router.post("/preview", response_model=SplitPreviewOut)
def preview(body: SplitPreviewIn, _: CurrentActor):
    """Validate and allocate without saving. Invalid splits return 200 with ok=false."""
    v = service.validate(body, body.total_minor, body.currency)
    shares = service.allocate(body, body.total_minor, body.currency) if v.ok else []
    return SplitPreviewOut(
        ok=v.ok,
        remaining_minor=v.remaining_minor,
        message=v.message,
        remaining_percent=v.remaining_percent,
        shares=[
            ShareOut(
                user_id=uuid.UUID(s.user_id), share_minor=s.share_minor, input_value=s.input_value
            )
            for s in shares
        ],
    )
