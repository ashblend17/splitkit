"""POST /personal/transactions/batch: the app sends bank SMS it read this way."""

import uuid

from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.modules.sync.models import ChangeLog
from tests.api.conftest import cat, login

API = "/api/v1/personal/transactions"


def sms(n: int, **overrides):
    return {
        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"sms-{n}")),
        "type": "expense",
        "amount_minor": 1000 + n,
        "description": f"Shop {n}",
        "date": "2026-10-12",
        "source": "sms",
        "merchant": f"SHOP {n}",
        "account": "HDFC ··4821",
        "channel": "upi",
        "reviewed": False,
        **overrides,
    }


def log_count() -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(ChangeLog))


def test_a_batch_makes_each_entry_and_a_repeat_makes_none(client, seeded):
    h = login(client, "john")
    logs = log_count()
    r = client.post(f"{API}/batch", headers=h, json={"items": [sms(1), sms(2), sms(3)]})
    assert r.status_code == 201, r.text
    assert [i["description"] for i in r.json()["items"]] == ["Shop 1", "Shop 2", "Shop 3"]
    assert log_count() == logs + 3  # one sync entry each
    again = client.post(f"{API}/batch", headers=h, json={"items": [sms(2), sms(3), sms(4)]})
    assert [i["id"] for i in again.json()["items"]] == [sms(n)["id"] for n in (2, 3, 4)]
    assert log_count() == logs + 4
    listed = client.get(f"{API}?source=sms&reviewed=false", headers=h).json()
    assert listed["count"] == 5  # the seed's Swiggy order and these four


def test_a_deleted_entry_stays_deleted(client, seeded):
    h = login(client, "john")
    made = client.post(f"{API}/batch", headers=h, json={"items": [sms(1)]}).json()["items"][0]
    client.delete(f"{API}/{made['id']}?version={made['version']}", headers=h)
    again = client.post(f"{API}/batch", headers=h, json={"items": [sms(1)]}).json()["items"][0]
    assert again["deleted_at"] is not None


def test_all_or_none(client, seeded):
    h = login(client, "john")
    logs = log_count()
    bad = sms(2, category_id=cat("travel"))  # a group-only category
    r = client.post(f"{API}/batch", headers=h, json={"items": [sms(1), bad]})
    assert (r.status_code, r.json()["error"]["code"]) == (422, "unknown_category")
    assert log_count() == logs
    assert client.get(f"{API}/{sms(1)['id']}", headers=h).status_code == 404


def test_at_most_100_and_at_least_one(client, seeded):
    h = login(client, "john")
    assert client.post(f"{API}/batch", headers=h, json={"items": []}).status_code == 422
    many = [sms(n) for n in range(101)]
    assert client.post(f"{API}/batch", headers=h, json={"items": many}).status_code == 422
    assert client.post(f"{API}/batch", headers=h, json={"items": many[:100]}).status_code == 201
