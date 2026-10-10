"""Bad input gets a 422 in the usual error shape with human copy, never a 500."""

from datetime import date, timedelta

import pytest

from app.core.schemas import MAX_AMOUNT_MINOR
from tests.api.conftest import gid, login, uid

API = "/api/v1"
TODAY = date.today().isoformat()


def _expense(**changes):
    body = {
        "description": "Dinner",
        "amount_minor": 1000,
        "payer_id": uid("ansh"),
        "date": TODAY,
        "split": {
            "method": "equal",
            "inputs": [{"user_id": uid("ansh")}, {"user_id": uid("aman")}],
        },
    }
    return {**body, **changes}


def _error(r, status=422):
    assert r.status_code == status, r.text
    return r.json()["error"]


def test_validation_errors_use_the_error_shape(client):
    error = _error(client.post(f"{API}/auth/login", json={"email": "nope"}))
    assert error["code"] == "invalid_input"
    assert error["message"] == "Enter a valid email address"
    assert {"loc": ["body", "password"], "message": "Password is required"} in error["fields"]

    short = _error(
        client.post(
            f"{API}/auth/register", json={"name": "A", "email": "a@b.com", "password": "short"}
        )
    )
    assert short["message"] == "Password must be at least 8 characters"


def test_blank_text_is_refused(client, seeded):
    h = login(client, "ansh")
    blank = "   "
    reg = {"name": blank, "email": "new@example.com", "password": "password1"}
    assert _error(client.post(f"{API}/auth/register", json=reg))["message"] == (
        "Name can't be empty"
    )
    _error(client.post(f"{API}/groups", headers=h, json={"name": blank}))
    _error(client.patch(f"{API}/groups/{gid('goa')}", headers=h, json={"name": blank}))
    _error(client.post(f"{API}/groups/{gid('goa')}/members", headers=h, json={"name": blank}))
    _error(client.patch(f"{API}/me", headers=h, json={"name": blank}))
    _error(client.post(f"{API}/categories", headers=h, json={"label": blank}))
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses", headers=h, json=_expense(description=blank)
    )
    assert _error(r)["message"] == "Description can't be empty"
    personal = {"type": "expense", "amount_minor": 100, "description": blank, "date": TODAY}
    _error(client.post(f"{API}/personal/transactions", headers=h, json=personal))

    # Surrounding spaces are trimmed, not refused.
    r = client.post(f"{API}/groups", headers=h, json={"name": "  Trek  "})
    assert r.status_code == 201 and r.json()["name"] == "Trek"


def test_null_bytes_are_refused(client, seeded):
    h = login(client, "ansh")
    r = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=h, json=_expense(notes="a\x00b"))
    assert _error(r)["message"] == "Text can't contain a null character"


@pytest.mark.parametrize("amount", [MAX_AMOUNT_MINOR + 1, 10**19, 2**63])
def test_amounts_have_a_ceiling(client, seeded, amount):
    h = login(client, "ansh")
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses", headers=h, json=_expense(amount_minor=amount)
    )
    assert _error(r)["message"] == "That amount is too large"
    payment = {
        "from_user": uid("aman"),
        "to_user": uid("ansh"),
        "amount_minor": amount,
        "date": TODAY,
    }
    _error(client.post(f"{API}/groups/{gid('goa')}/settlements", headers=h, json=payment))
    personal = {"type": "expense", "amount_minor": amount, "description": "x", "date": TODAY}
    _error(client.post(f"{API}/personal/transactions", headers=h, json=personal))


def test_the_largest_amount_works(client, seeded):
    h = login(client, "ansh")
    exact = {
        "method": "exact",
        "inputs": [
            {"user_id": uid("ansh"), "value": str(MAX_AMOUNT_MINOR - 1)},
            {"user_id": uid("aman"), "value": "1"},
        ],
    }
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses",
        headers=h,
        json=_expense(amount_minor=MAX_AMOUNT_MINOR, split=exact),
    )
    assert r.status_code == 201, r.text


@pytest.mark.parametrize(
    "day,message",
    [
        ("1999-12-31", "Pick a date from 2000 onwards"),
        ((date.today() + timedelta(days=400)).isoformat(), "Pick a date less than a year ahead"),
        ("9999-12-31", "Pick a date less than a year ahead"),
    ],
)
def test_dates_stay_in_range(client, seeded, day, message):
    h = login(client, "ansh")
    r = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=h, json=_expense(date=day))
    assert _error(r)["message"] == message


@pytest.mark.parametrize("value", ["1e30", "1e999999", "0.00001"])
def test_split_values_fit_what_is_stored(client, seeded, value):
    h = login(client, "ansh")
    shares = {
        "method": "shares",
        "inputs": [
            {"user_id": uid("ansh"), "value": value},
            {"user_id": uid("aman"), "value": "1"},
        ],
    }
    r = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=h, json=_expense(split=shares))
    assert _error(r)["message"] == "Value has too many digits"
    preview = {"method": "percent", "total_minor": 100, "inputs": shares["inputs"]}
    _error(client.post(f"{API}/splits/preview", headers=h, json=preview))


def test_profile_nulls_leave_fields_alone(client, seeded):
    h = login(client, "ansh")
    # The generated client sends null for every field it leaves out.
    r = client.patch(f"{API}/me", headers=h, json={"name": None, "currency": None, "version": None})
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "Ansh C" and r.json()["currency"] == "INR"
    r = client.patch(f"{API}/me", headers=h, json={"name": "  Ansh  ", "currency": "USD"})
    assert r.json()["name"] == "Ansh" and r.json()["currency"] == "USD"


def test_profile_currency_must_be_one_the_app_shows(client, seeded):
    h = login(client, "ansh")
    _error(client.patch(f"{API}/me", headers=h, json={"currency": "XYZ"}))
    assert client.get(f"{API}/me", headers=h).json()["currency"] == "INR"
