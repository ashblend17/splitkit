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


class AnalyticsCardOut(Schema):
    """One dashboard card. The client picks a renderer by `type` and reads the matching field:
    trends use `bars`, breakdowns use `rows`, splits use two `rows`, stats use `stat`."""

    id: uuid.UUID
    type: str
    title: str
    period_label: str
    source: str
    headline: str | None = None
    bars: list[ChartBar] = []
    rows: list[ChartRow] = []
    stat: ChartStat | None = None


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
