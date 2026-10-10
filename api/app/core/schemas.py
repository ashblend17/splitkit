from datetime import date, timedelta
from decimal import Decimal
from typing import Annotated, Any, Literal

from pydantic import (
    AfterValidator,
    BaseModel,
    ConfigDict,
    Field,
    PlainSerializer,
    StringConstraints,
    WithJsonSchema,
    model_validator,
)


def _reject_nul(value: Any) -> None:
    if isinstance(value, str):
        if "\x00" in value:
            raise ValueError("Text can't contain a null character")
    elif isinstance(value, dict):
        for v in value.values():
            _reject_nul(v)
    elif isinstance(value, list):
        for v in value:
            _reject_nul(v)


class Schema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def _no_nul_bytes(cls, data: Any) -> Any:
        # PostgreSQL text can't hold NUL, so it would fail at the database as a 500.
        _reject_nul(data)
        return data


class ErrorBody(Schema):
    code: str
    message: str


class ErrorResponse(Schema):
    error: ErrorBody


def Text(max_length: int):  # noqa: N802 (used like a type: `name: Text(80)`)
    """A required string with surrounding spaces removed, so "   " is refused as empty."""
    return Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=max_length)
    ]


MAX_AMOUNT_MINOR = 9_999_999_999
"""₹9,99,99,999.99: the most one expense, payment or entry can be. An exact split stores each
share in `expense_splits.input_value` (numeric(14, 4)), and totals stay well inside the 2^53 a
web client holds exactly."""

AmountMinor = Annotated[int, Field(gt=0, le=MAX_AMOUNT_MINOR)]

Currency = Literal["INR", "USD", "EUR"]
"""The currencies the app can show (app/lib/core/money/money.dart)."""

FIRST_DATE = date(2000, 1, 1)


def _in_range(day: date) -> date:
    # The app's date pickers allow 2000 up to a year ahead; a day of slack for time zones.
    if day < FIRST_DATE:
        raise ValueError("Pick a date from 2000 onwards")
    if day > date.today() + timedelta(days=366):
        raise ValueError("Pick a date less than a year ahead")
    return day


EntryDate = Annotated[date, AfterValidator(_in_range)]
"""The date of an expense, payment or personal entry."""


def _plain_decimal(value: Decimal) -> str:
    return f"{value.normalize():f}"


DecimalStr = Annotated[Decimal, PlainSerializer(_plain_decimal, return_type=str, when_used="json")]
"""A Decimal sent as a normalized string: "33.33", "2" (never "33.3300" or "2E+1")."""


DecimalIn = Annotated[
    Decimal,
    # What the database keeps (numeric(14, 4)); bigger or finer values would fail or be rounded.
    Field(max_digits=14, decimal_places=4),
    WithJsonSchema({"type": "string", "pattern": r"^-?\d+(\.\d+)?$", "examples": ["33.34"]}),
]
"""A Decimal input documented as a string, so generated clients send "33.34" (never a
float). The server still accepts JSON numbers."""
