import pytest

from app.core.money import format_minor, parse_minor


@pytest.mark.parametrize(
    ("minor", "text"),
    [
        (0, "₹0"),
        (50, "₹0.50"),
        (45000, "₹450"),
        (155000, "₹1,550"),
        (153333, "₹1,533.33"),
        (4826000, "₹48,260"),
        (8500000, "₹85,000"),
        (15000000, "₹1,50,000"),
        (1234567890, "₹1,23,45,678.90"),
        (-85000, "−₹850"),
    ],
)
def test_format_minor(minor, text):
    assert format_minor(minor) == text


@pytest.mark.parametrize(
    ("text", "minor"),
    [
        ("600", 60000),
        ("600.5", 60050),
        ("₹1,800", 180000),
        (" 0.01 ", 1),
        ("1,50,000.00", 15000000),
    ],
)
def test_parse_minor(text, minor):
    assert parse_minor(text) == minor


@pytest.mark.parametrize("text", ["abc", "1.234", "", "NaN", "Infinity"])
def test_parse_minor_rejects(text):
    with pytest.raises(ValueError):
        parse_minor(text)


def test_other_currencies_group_in_thousands():
    assert format_minor(15000000, "USD") == "$150,000"
    assert format_minor(123456, "EUR") == "€1,234.56"


def test_unknown_currency():
    with pytest.raises(ValueError):
        format_minor(100, "XYZ")
