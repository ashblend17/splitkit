"""Suggestions for the review step: which Splitkit person and category each Tricount name
probably is. Pure; the user confirms or changes every suggestion before anything is saved."""

import re
import unicodedata
import uuid
from dataclasses import dataclass


def _norm(text: str) -> str:
    s = unicodedata.normalize("NFKD", text.replace("_", " "))
    s = "".join(c for c in s if not unicodedata.combining(c)).casefold()
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s&]", " ", s)).strip()


@dataclass(frozen=True)
class Candidate:
    id: uuid.UUID
    name: str
    placeholder_name: str | None = None
    is_me: bool = False


@dataclass(frozen=True)
class PersonMatch:
    candidate: Candidate | None
    state: str
    """you | matched (same name) | suggested (looks like them) | unmatched"""


def _exact(name: str, c: Candidate) -> bool:
    n = _norm(name)
    return n == _norm(c.name) or (c.placeholder_name is not None and n == _norm(c.placeholder_name))


def _looks_like(name: str, c: Candidate) -> bool:
    """ "Rahul S" looks like "Rahul Sharma": every word starts the matching word of theirs."""
    words, theirs = _norm(name).split(), _norm(c.name).split()
    return (
        bool(words)
        and len(words) <= len(theirs)
        and all(t.startswith(w) for w, t in zip(words, theirs, strict=False))
    )


def match_people(names: list[str], candidates: list[Candidate]) -> dict[str, PersonMatch]:
    """Same names first, then look-alikes; each person is used once, and a look-alike that
    fits more than one person is left for the user to choose."""
    taken: set[uuid.UUID] = set()
    result: dict[str, PersonMatch] = {}

    def state(c: Candidate, default: str) -> str:
        return "you" if c.is_me else default

    for name in names:
        hit = next((c for c in candidates if c.id not in taken and _exact(name, c)), None)
        if hit:
            taken.add(hit.id)
            result[name] = PersonMatch(hit, state(hit, "matched"))
    for name in names:
        if name in result:
            continue
        fits = [c for c in candidates if c.id not in taken and _looks_like(name, c)]
        if len(fits) == 1:
            taken.add(fits[0].id)
            result[name] = PersonMatch(fits[0], state(fits[0], "suggested"))
        else:
            result[name] = PersonMatch(None, "unmatched")
    return result


# Tricount's built-in categories (and common custom ones) -> Splitkit category keys.
_CATEGORY_ALIASES: dict[str, set[str]] = {
    "food": {
        "food",
        "food & drinks",
        "food & drink",
        "food and drink",
        "food and drinks",
        "restaurants",
        "restaurant",
        "restaurants & bars",
        "restaurants and bars",
        "bars",
        "drinks",
        "groceries",
        "supermarket",
        "dining",
        "meals",
        "snacks",
        "coffee",
    },
    "transport": {
        "transport",
        "transportation",
        "taxi",
        "car",
        "fuel",
        "gas",
        "petrol",
        "public transport",
    },
    "stay": {"accommodation", "accomodation", "lodging", "hotel", "hotels", "stay", "airbnb"},
    "entertainment": {
        "entertainment",
        "activities",
        "activity",
        "leisure",
        "fun",
        "nightlife",
        "sport",
        "sports",
        "culture",
    },
    "shopping": {"shopping", "gifts", "clothes", "souvenirs"},
    "travel": {"travel", "trip", "flights", "flight", "plane"},
    "rent": {"rent", "housing"},
    "bills": {"bills", "utilities", "internet", "phone", "electricity"},
    "other": {"other", "others", "misc", "miscellaneous", "general"},
}


def suggest_category(name: str, available: dict[str, str]) -> str | None:
    """A category key for a Tricount category, or None if the user has to choose.
    `available` is key -> label of the categories this group can use."""
    n = _norm(name)
    for key, label in available.items():
        if n in (_norm(key), _norm(label)):
            return key
    for key, names in _CATEGORY_ALIASES.items():
        if key in available and n in names:
            return key
    return None
