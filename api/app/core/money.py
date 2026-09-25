"""Money helpers. Amounts are always integer minor units (paise) plus a currency code."""

from decimal import Decimal, InvalidOperation

# Minor-unit exponent and display symbol per currency. INR is the only MVP currency;
# the table exists so adding one later is a data change, not a code change.
_CURRENCIES: dict[str, tuple[int, str]] = {
    "INR": (2, "₹"),
    "USD": (2, "$"),
    "EUR": (2, "€"),
}
SUPPORTED_CURRENCIES = tuple(_CURRENCIES)

MINUS = "−"  # typographic minus, as used in the designs ("−₹850")


def _currency(code: str) -> tuple[int, str]:
    try:
        return _CURRENCIES[code]
    except KeyError:
        raise ValueError(f"Unsupported currency: {code}") from None


def _group_western(digits: str) -> str:
    """1234567 -> 1,234,567."""
    return f"{int(digits):,}"


def _group_indian(digits: str) -> str:
    """1234567 -> 12,34,567 (lakh/crore grouping, as en-IN formats it)."""
    if len(digits) <= 3:
        return digits
    head, tail = digits[:-3], digits[-3:]
    pairs = []
    while len(head) > 2:
        pairs.insert(0, head[-2:])
        head = head[:-2]
    return ",".join([head, *pairs, tail])


def format_minor(amount_minor: int, currency: str = "INR") -> str:
    """Human display: 155000 -> "₹1,550", 153333 -> "₹1,533.33", -85000 -> "−₹850".

    Whole amounts drop the decimals; anything else always shows two places. INR uses lakh
    grouping (₹1,50,000); other currencies group in thousands ($150,000).
    """
    exponent, symbol = _currency(currency)
    sign = MINUS if amount_minor < 0 else ""
    major, minor = divmod(abs(amount_minor), 10**exponent)
    text = (_group_indian if currency == "INR" else _group_western)(str(major))
    if minor:
        text += "." + str(minor).zfill(exponent)
    return f"{sign}{symbol}{text}"


def parse_minor(text: str, currency: str = "INR") -> int:
    """User-entered major units -> minor units: "600.5" -> 60050. Rejects sub-paise precision."""
    exponent, _ = _currency(currency)
    cleaned = text.strip().replace(",", "").removeprefix(_currency(currency)[1])
    try:
        value = Decimal(cleaned)
    except InvalidOperation:
        raise ValueError(f"Not an amount: {text!r}") from None
    if not value.is_finite():
        raise ValueError(f"Not an amount: {text!r}")
    scaled = value.scaleb(exponent)
    if scaled != scaled.to_integral_value():
        raise ValueError(f"Too many decimal places: {text!r}")
    return int(scaled)
