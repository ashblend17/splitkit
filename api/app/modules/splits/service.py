"""Adapter between the API and the pure split engine: turns engine errors into API errors."""

from app.core.errors import ApiError
from app.modules.splits.engine import (
    Share,
    SplitInput,
    SplitMethod,
    UnknownSplitMethod,
    Validation,
    registry,
)
from app.modules.splits.schemas import SplitIn


def method(key: str) -> SplitMethod:
    try:
        return registry.get(key)
    except UnknownSplitMethod:
        raise ApiError(422, "unknown_split_method", f"Unknown split method: {key}") from None


def _inputs(split: SplitIn) -> list[SplitInput]:
    return [SplitInput(str(i.user_id), i.value) for i in split.inputs]


def validate(split: SplitIn, total_minor: int, currency: str) -> Validation:
    try:
        return method(split.method).validate(total_minor, _inputs(split), currency)
    except (TypeError, ValueError) as e:
        raise ApiError(422, "split_input_invalid", str(e)) from None


def allocate(split: SplitIn, total_minor: int, currency: str) -> list[Share]:
    """Shares for a valid split, or a 422 carrying the human validation message."""
    v = validate(split, total_minor, currency)
    if not v.ok:
        raise ApiError(422, "split_invalid", v.message, remaining_minor=v.remaining_minor)
    return method(split.method).allocate(total_minor, _inputs(split), currency)
