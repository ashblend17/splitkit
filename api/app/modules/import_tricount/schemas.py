import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import Field, model_validator

from app.core.schemas import Schema
from app.modules.groups.schemas import Icon
from app.modules.users.schemas import UserBrief


class RowIssueOut(Schema):
    level: Literal["error", "warning"]
    """error: the row is skipped · warning: imported, but worth a look"""
    code: str
    message: str


class RowShareOut(Schema):
    name: str
    """The Tricount name; map it with `people`."""
    share_minor: int


class ImportRowOut(Schema):
    line: int
    """Row number in the file."""
    date: date | None
    title: str
    kind: Literal["expense", "transfer", "income"]
    """A transfer becomes one payment per recipient; income is skipped for now."""
    payer: str | None
    amount_minor: int
    currency: str
    original: str | None
    """The amount as written in the file, when it was converted ("$12.50")."""
    shares: list[RowShareOut]
    category: str | None
    """The Tricount category; map it with `categories`."""
    issues: list[RowIssueOut]


class PersonOut(Schema):
    name: str
    rows: int
    """How many rows this person is in (paying or sharing)."""
    match: Literal["you", "matched", "suggested", "unmatched"]
    user: UserBrief | None
    """The suggested Splitkit person. None: suggest a new placeholder member."""


class CategoryMatchOut(Schema):
    name: str
    rows: int
    key: str | None
    """The suggested category key. None: the user should choose (it falls back to Other)."""


class CategoryOptionOut(Schema):
    key: str
    label: str
    icon: str


class ImportTotalsOut(Schema):
    expenses: int
    expense_total_minor: int
    transfers: int
    transfer_total_minor: int
    skipped: int
    """Rows with an error; they are not imported."""
    first_date: date | None
    last_date: date | None


class ImportPreviewOut(Schema):
    file_name: str
    group_name: str
    """A name for a new group: the tricount's name if the file has it, else from the file name."""
    currency: str
    """The target group's currency, or the file's main currency for a new group."""
    people: list[PersonOut]
    candidates: list[UserBrief]
    """Everyone a Tricount person can be matched to: you, the group's members, and people you
    share a group with."""
    categories: list[CategoryMatchOut]
    category_options: list[CategoryOptionOut]
    rows: list[ImportRowOut]
    totals: ImportTotalsOut


class NewGroupIn(Schema):
    name: str = Field(min_length=1, max_length=80)
    currency: Literal["INR", "USD", "EUR"] = "INR"
    icon: Icon = "travel"


class PersonMapIn(Schema):
    name: str
    """The Tricount name, as in the preview."""
    user_id: uuid.UUID | None = None
    """An existing person (from `candidates`). None: create a placeholder member."""
    placeholder_name: str | None = Field(default=None, max_length=80)
    """The placeholder's name; defaults to the Tricount name."""


class ImportCommitIn(Schema):
    """Sent as the `options` form field (JSON) next to the file."""

    group_id: uuid.UUID | None = None
    new_group: NewGroupIn | None = None
    people: list[PersonMapIn] = []
    categories: dict[str, str] = {}
    """Tricount category -> Splitkit category key. Missing or unknown: Other."""

    @model_validator(mode="after")
    def _one_target(self):
        if (self.group_id is None) == (self.new_group is None):
            raise ValueError("Give either group_id or new_group")
        return self


class ReviewItemOut(Schema):
    title: str
    why: str
    expense_id: uuid.UUID | None


class ImportStatsOut(Schema):
    expenses: int
    expense_total_minor: int
    transfers: int
    transfer_total_minor: int
    people: int
    placeholders: int
    skipped: int
    currency: str
    created_group: bool
    review: list[ReviewItemOut]
    """Imported, but worth a look: placeholder payers, categories set to Other, conversions."""
    skipped_rows: list[str]
    """ "Row 12 · Hotel refund: Income isn't supported yet…" """


class ImportBatchOut(Schema):
    id: uuid.UUID
    source: str
    file_name: str
    group_id: uuid.UUID | None
    group_name: str | None
    created_at: datetime
    undone_at: datetime | None
    stats: ImportStatsOut
