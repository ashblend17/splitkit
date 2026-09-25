from datetime import date

from app.modules.analytics.periods import (
    adaptive_buckets,
    current,
    previous,
    range_label,
    trend_buckets,
)

ON = date(2026, 9, 23)


def test_range_labels():
    assert range_label(date(2026, 9, 1), date(2026, 9, 23)) == "1 – 23 Sep"
    assert range_label(date(2026, 8, 28), date(2026, 9, 3)) == "28 Aug – 3 Sep"
    assert range_label(date(2025, 12, 12), date(2026, 1, 3)) == "12 Dec 2025 – 3 Jan 2026"
    assert range_label(ON, ON) == "23 Sep"


def test_current_and_previous():
    assert (current("month", ON).start, current("month", ON).label, current("month", ON).days) == (
        date(2026, 9, 1),
        "September",
        23,
    )
    assert current("week", ON).label == "17 – 23 Sep"
    assert current("year", ON).label == "2026"
    assert (previous("month", ON).label, previous("month", ON).days) == ("August", 31)
    assert previous("year", ON).days == 365


def test_trend_buckets():
    months = trend_buckets("month", ON)
    assert [b.label for b in months] == ["Apr", "May", "Jun", "Jul", "Aug", "Sep"]
    assert months[-1].end == ON and months[0].start == date(2026, 4, 1)
    assert len(trend_buckets("year", ON)) == 12
    week = trend_buckets("week", ON)
    assert [b.start for b in week][-1] == ON and len(week) == 7


def test_adaptive_buckets():
    assert [b.label for b in adaptive_buckets(date(2026, 9, 12), date(2026, 9, 20))] == [
        str(d) for d in range(12, 21)
    ]
    weeks = adaptive_buckets(date(2026, 7, 1), date(2026, 9, 23))
    assert weeks[0].label == "1 Jul" and weeks[-1].end == date(2026, 9, 23)
    months = adaptive_buckets(date(2026, 1, 15), date(2026, 9, 23))
    assert months[0].start == date(2026, 1, 15) and months[-1].label == "Sep"
