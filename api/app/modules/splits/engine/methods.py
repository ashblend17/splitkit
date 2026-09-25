"""The four built-in split methods. Pure: no I/O, no clock, no globals."""

from decimal import ROUND_HALF_UP, Decimal

from app.core.money import format_minor

from .rounding import distribute
from .types import Share, SplitInput, SplitValidationError, Validation

VALID = "Split is valid"
HUNDRED = Decimal(100)


def _format_percent(value: Decimal) -> str:
    return f"{value.normalize():f}%"


def _check_common(total_minor: int, inputs: list[SplitInput], currency: str) -> Validation | None:
    """Checks shared by every method. Returns a failed Validation, or None if all is well."""
    if isinstance(total_minor, bool) or not isinstance(total_minor, int):
        raise TypeError("total_minor must be an int (minor units)")
    ids = [i.user_id for i in inputs]
    if len(ids) != len(set(ids)):
        raise ValueError("Each person can appear only once in a split")
    if total_minor <= 0:
        return Validation(False, total_minor, f"Enter an amount above {format_minor(0, currency)}")
    return None


def _values(inputs: list[SplitInput]) -> list[Decimal]:
    values = []
    for i in inputs:
        if i.value is None:
            raise ValueError(f"Missing value for {i.user_id}")
        if isinstance(i.value, float):
            raise TypeError("Split values must be Decimal or int, never float")
        values.append(Decimal(i.value))
    return values


def _over_or_under(remaining_minor: int, currency: str) -> str:
    if remaining_minor > 0:
        return f"{format_minor(remaining_minor, currency)} still needs to be allocated"
    return f"{format_minor(-remaining_minor, currency)} over the total — reduce someone"


class _Base:
    key: str

    def allocate(
        self, total_minor: int, inputs: list[SplitInput], currency: str = "INR"
    ) -> list[Share]:
        validation = self.validate(total_minor, inputs, currency)
        if not validation.ok:
            raise SplitValidationError(validation)
        parts = self._parts(total_minor, inputs)
        return [
            Share(i.user_id, part, None if i.value is None else Decimal(i.value))
            for i, part in zip(inputs, parts, strict=True)
        ]

    def validate(
        self, total_minor: int, inputs: list[SplitInput], currency: str = "INR"
    ) -> Validation:
        raise NotImplementedError

    def _parts(self, total_minor: int, inputs: list[SplitInput]) -> list[int]:
        raise NotImplementedError


class EqualSplit(_Base):
    key = "equal"
    label = "Equal"
    symbol = "="
    hint = "Everyone ticked pays the same. Untick anyone who is not involved."

    def validate(self, total_minor, inputs, currency="INR"):
        if failed := _check_common(total_minor, inputs, currency):
            return failed
        if not inputs:
            return Validation(False, total_minor, "Pick at least one person")
        return Validation(True, 0, VALID)

    def allocate(self, total_minor, inputs, currency="INR"):
        # Equal ignores values; don't echo them into input_value.
        return super().allocate(total_minor, [SplitInput(i.user_id) for i in inputs], currency)

    def _parts(self, total_minor, inputs):
        return distribute(total_minor, [Decimal(1)] * len(inputs))


class ExactSplit(_Base):
    key = "exact"
    label = "Exact"
    symbol = "₹"
    hint = "Enter exactly what each person owes. It must add up to the total."

    def validate(self, total_minor, inputs, currency="INR"):
        if failed := _check_common(total_minor, inputs, currency):
            return failed
        values = _values(inputs)
        if any(v != v.to_integral_value() for v in values):
            raise ValueError("Exact amounts must be whole minor units")
        if any(v < 0 for v in values):
            return Validation(False, total_minor - int(sum(values)), "Amounts can't be negative")
        remaining = total_minor - int(sum(values))
        if remaining != 0:
            return Validation(False, remaining, _over_or_under(remaining, currency))
        return Validation(True, 0, VALID)

    def _parts(self, total_minor, inputs):
        return [int(v) for v in _values(inputs)]


class PercentSplit(_Base):
    key = "percent"
    label = "Percent"
    symbol = "%"
    hint = "Give each person a percentage. It must add up to 100%."

    def validate(self, total_minor, inputs, currency="INR"):
        if failed := _check_common(total_minor, inputs, currency):
            return failed
        values = _values(inputs)
        remaining_pct = HUNDRED - sum(values, Decimal(0))
        remaining = int(
            (Decimal(total_minor) * remaining_pct / HUNDRED).to_integral_value(ROUND_HALF_UP)
        )
        if any(v < 0 for v in values):
            return Validation(False, remaining, "Percentages can't be negative", remaining_pct)
        if remaining_pct > 0:
            message = (
                f"{_format_percent(remaining_pct)} ({format_minor(remaining, currency)})"
                " still needs to be allocated"
            )
            return Validation(False, remaining, message, remaining_pct)
        if remaining_pct < 0:
            message = f"{_format_percent(-remaining_pct)} over the total — reduce someone"
            return Validation(False, remaining, message, remaining_pct)
        return Validation(True, 0, VALID, Decimal(0))

    def _parts(self, total_minor, inputs):
        return distribute(total_minor, _values(inputs))


class SharesSplit(_Base):
    key = "shares"
    label = "Shares"
    symbol = "×"
    hint = "Give each person shares, e.g. 2 for a couple. The total is divided by shares."

    def validate(self, total_minor, inputs, currency="INR"):
        if failed := _check_common(total_minor, inputs, currency):
            return failed
        values = _values(inputs)
        if any(v < 0 for v in values):
            return Validation(False, total_minor, "Shares can't be negative")
        if sum(values, Decimal(0)) == 0:
            return Validation(False, total_minor, _over_or_under(total_minor, currency))
        return Validation(True, 0, VALID)

    def _parts(self, total_minor, inputs):
        return distribute(total_minor, _values(inputs))
