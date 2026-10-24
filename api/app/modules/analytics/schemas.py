import uuid
from typing import Any, Literal

from pydantic import Field

from app.core.schemas import Schema


class ChartBar(Schema):
    label: str
    value_minor: int
    highlight: bool = False


class ChartRow(Schema):
    label: str
    value_minor: int


class ChartStat(Schema):
    value_minor: int
    note: str | None = None


class ChartAverage(Schema):
    label: str
    average_minor: int
    """What a usual week or month came to."""
    now_minor: int
    """The week or month under way, so far."""


class ChartAverages(Schema):
    """A breakdown's averages: each key's usual week or month next to the one under way."""

    label: str
    """What they're averaged over: "Average of 6 months", or "No full month yet" (no rows)."""
    now_label: str
    """What `now_minor` covers: "October so far", "Last 7 days"."""
    unit: Literal["week", "month"]
    rows: list[ChartAverage]
    """Largest average first. A key with nothing usual and nothing now is left out."""


class AnalyticsCardOut(Schema):
    """One dashboard card. The client picks a renderer by `type` and reads the matching field:
    trends use `bars`, breakdowns use `rows`, splits use two `rows`, stats use `stat`.
    Spending by category also has `averages`."""

    id: uuid.UUID
    type: str
    title: str
    period_label: str
    source: str
    headline: str | None = None
    bars: list[ChartBar] = []
    rows: list[ChartRow] = []
    stat: ChartStat | None = None
    averages: ChartAverages | None = None


class DashboardOut(Schema):
    scope: Literal["personal", "group"]
    currency: str
    subtitle: str | None = None
    """Group dashboards: "12 – 23 Sep · 6 members"."""
    cards: list[AnalyticsCardOut]


class LayoutCard(Schema):
    type: str = Field(min_length=1, max_length=40)
    title: str = Field(min_length=1, max_length=60)
    period: str = Field(min_length=1, max_length=40)
    source: str = Field(min_length=1, max_length=60)
    params: dict[str, Any] = {}


class LayoutOut(Schema):
    cards: list[LayoutCard]
    """Your current layout, in order."""
    available: list[LayoutCard]
    """The default cards for this scope, to add back ones you removed."""
    customised: bool


class LayoutIn(Schema):
    cards: list[LayoutCard] = Field(max_length=20)
