import uuid

from pydantic import Field

from app.core.schemas import DecimalIn, DecimalStr, Schema


class SplitMethodOut(Schema):
    key: str
    label: str
    symbol: str
    hint: str


class SplitInputIn(Schema):
    user_id: uuid.UUID
    value: DecimalIn | None = None
    """equal: omit · exact: minor units · percent: e.g. "33.34" · shares: e.g. "2"."""


class SplitIn(Schema):
    method: str
    inputs: list[SplitInputIn]


class SplitPreviewIn(SplitIn):
    total_minor: int = Field(gt=0)
    currency: str = "INR"


class ShareOut(Schema):
    user_id: uuid.UUID
    share_minor: int
    input_value: DecimalStr | None


class SplitPreviewOut(Schema):
    ok: bool
    remaining_minor: int
    message: str
    remaining_percent: DecimalStr | None
    shares: list[ShareOut]
    """Empty unless ok."""
