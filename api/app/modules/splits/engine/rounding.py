from decimal import Decimal
from fractions import Fraction


def distribute(total_minor: int, weights: list[Decimal]) -> list[int]:
    """Split `total_minor` in proportion to `weights` so the parts sum exactly to the total.

    Largest-remainder method on exact fractions: everyone gets the floor of their exact
    share, then the leftover paise go one each to the largest fractional remainders.
    Ties go to the earlier input, so the result depends only on the inputs and their order.
    A zero weight never receives a paisa.
    """
    if total_minor < 0:
        raise ValueError("total_minor must not be negative")
    if any(w < 0 for w in weights):
        raise ValueError("weights must not be negative")
    weight_sum = sum((Fraction(w) for w in weights), Fraction(0))
    if weight_sum == 0:
        raise ValueError("weights must not all be zero")

    exact = [total_minor * Fraction(w) / weight_sum for w in weights]
    parts = [q.numerator // q.denominator for q in exact]
    leftover = total_minor - sum(parts)
    by_remainder = sorted(range(len(weights)), key=lambda i: (-(exact[i] - parts[i]), i))
    for i in by_remainder[:leftover]:
        parts[i] += 1
    return parts
