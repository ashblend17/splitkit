from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol, runtime_checkable


@dataclass(frozen=True)
class SplitInput:
    """One participant's input to a split.

    `value` depends on the method:
      equal   -> ignored (pass only the people who are included)
      exact   -> the amount they owe, in minor units (a whole number)
      percent -> their percentage, e.g. Decimal("33.34")
      shares  -> their number of shares, e.g. Decimal("2")
    """

    user_id: str
    value: Decimal | None = None


@dataclass(frozen=True)
class Share:
    user_id: str
    share_minor: int
    input_value: Decimal | None


@dataclass(frozen=True)
class Validation:
    ok: bool
    remaining_minor: int
    """Total minus what is allocated. Negative means over-allocated."""
    message: str
    """Human copy for the status line, e.g. "₹100 still needs to be allocated"."""
    remaining_percent: Decimal | None = None
    """Percent method only: 100 minus the percentages entered."""


class SplitValidationError(ValueError):
    def __init__(self, validation: Validation):
        super().__init__(validation.message)
        self.validation = validation


@runtime_checkable
class SplitMethod(Protocol):
    key: str
    label: str
    symbol: str
    hint: str

    def validate(
        self, total_minor: int, inputs: list[SplitInput], currency: str = "INR"
    ) -> Validation: ...

    def allocate(
        self, total_minor: int, inputs: list[SplitInput], currency: str = "INR"
    ) -> list[Share]: ...
