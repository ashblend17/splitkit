from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, PlainSerializer, WithJsonSchema


class Schema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class ErrorBody(Schema):
    code: str
    message: str


class ErrorResponse(Schema):
    error: ErrorBody


def _plain_decimal(value: Decimal) -> str:
    return f"{value.normalize():f}"


DecimalStr = Annotated[Decimal, PlainSerializer(_plain_decimal, return_type=str, when_used="json")]
"""A Decimal sent as a normalized string: "33.33", "2" (never "33.3300" or "2E+1")."""


DecimalIn = Annotated[
    Decimal,
    WithJsonSchema({"type": "string", "pattern": r"^-?\d+(\.\d+)?$", "examples": ["33.34"]}),
]
"""A Decimal input documented as a string, so generated clients send "33.34" (never a
float). The server still accepts JSON numbers."""
