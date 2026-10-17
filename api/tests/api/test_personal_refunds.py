"""Refunds: money back for one of your spends. They come off spending (and off the spend's
category), never more than the spend, and a refund of a split spend belongs to the group."""

from tests.api.conftest import cat, login, register

API = "/api/v1"
TXNS = f"{API}/personal/transactions"


def find(client, h, description: str, deleted: bool = False) -> dict:
    items = client.get(f"{TXNS}?limit=500&deleted={str(deleted).lower()}", headers=h).json()
    [found] = [i for i in items["items"] if i["description"] == description]
    return found


def refund(of: str | None, amount: int, category: str = "shopping", **extra) -> dict:
    return {
        "type": "refund",
        "amount_minor": amount,
        "description": "Refund",
        "date": "2026-09-24",
        "category_id": cat(category),
        "refund_of_id": of,
        **extra,
    }


def summary(client, h, month: str) -> dict:
    return client.get(f"{API}/personal/summary?month={month}", headers=h).json()


def test_the_seeded_refund_comes_off_july(client, seeded):
    h = login(client, "john")
    s = summary(client, h, "2026-07-15")
    # ₹35,920 spent in July (PersonalAnalytics), less the ₹1,490 price-drop refund.
    assert (s["spent_minor"], s["refunds_minor"], s["income_minor"], s["left_over_minor"]) == (
        3_443_000,
        149_000,
        8_500_000,
        5_057_000,
    )
    assert [(c["label"], c["amount_minor"]) for c in s["by_category"][:2]] == [
        ("Rent", 1_800_000),
        ("Shopping", 849_000 - 149_000),
    ]
    listed = client.get(f"{TXNS}?start=2026-07-01&end=2026-07-31", headers=h).json()
    assert (listed["spent_minor"], listed["refunds_minor"]) == (3_443_000, 149_000)
    seeded_refund = find(client, h, "Price drop refund")
    assert seeded_refund["refund_of_id"] == find(client, h, "New headphones")["id"]
    assert seeded_refund["direction"] == "in"


def test_a_category_refunded_in_full_drops_out(client, seeded):
    h = login(client, "john")
    before = summary(client, h, "2026-09-23")
    pharmacy = find(client, h, "Pharmacy")
    r = client.post(TXNS, headers=h, json=refund(pharmacy["id"], 61100, "health"))
    assert r.status_code == 201, r.text
    after = summary(client, h, "2026-09-23")
    assert after["spent_minor"] == before["spent_minor"] - 61100
    assert "Health" in {c["label"] for c in before["by_category"]}
    assert "Health" not in {c["label"] for c in after["by_category"]}
    # A refund doesn't have to name the spend.
    r = client.post(TXNS, headers=h, json=refund(None, 5000))
    assert r.status_code == 201 and r.json()["refund_of_id"] is None


def test_a_refund_is_of_one_of_your_spends(client, seeded):
    h = login(client, "john")
    other, _ = register(client, "Zoya", "zoya@example.com")
    theirs = client.post(
        TXNS,
        headers=other,
        json={"type": "expense", "amount_minor": 1000, "description": "Hers", "date": "2026-09-24"},
    ).json()
    pharmacy = find(client, h, "Pharmacy")
    client.delete(f"{TXNS}/{pharmacy['id']}", headers=h)
    salary = client.get(f"{TXNS}?type=income&limit=1", headers=h).json()["items"][0]
    for target in (theirs["id"], salary["id"], pharmacy["id"]):
        r = client.post(TXNS, headers=h, json=refund(target, 100))
        assert r.status_code == 422, target
        assert r.json()["error"] == {
            "code": "unknown_refund_target",
            "message": "That spend isn't available",
        }


def test_a_refund_is_at_most_the_spend(client, seeded):
    h = login(client, "john")
    headphones = find(client, h, "New headphones")
    r = client.post(TXNS, headers=h, json=refund(headphones["id"], 849_100))
    assert r.json()["error"] == {
        "code": "refund_too_large",
        "message": "A refund can't be more than the spend",
    }
    seeded_refund = find(client, h, "Price drop refund")
    body = {
        k: seeded_refund[k] for k in ("type", "description", "date", "refund_of_id", "version")
    } | {"category_id": cat("shopping")}
    r = client.put(
        f"{TXNS}/{seeded_refund['id']}", headers=h, json={**body, "amount_minor": 849_000}
    )
    assert r.status_code == 200, r.text
    body["version"] = r.json()["version"]
    r = client.put(
        f"{TXNS}/{seeded_refund['id']}", headers=h, json={**body, "amount_minor": 849_100}
    )
    assert r.json()["error"]["code"] == "refund_too_large"


def test_a_refund_of_a_split_spend_isnt_counted(client, seeded):
    """The Uber ride became a split in Goa Trip, so its refund belongs to the group too."""
    h = login(client, "john")
    before = summary(client, h, "2026-09-23")
    uber = find(client, h, "Uber to airport")
    assert not uber["counted"]
    r = client.post(TXNS, headers=h, json=refund(uber["id"], 31000, "transport"))
    assert r.status_code == 201 and r.json()["counted"] is False
    after = summary(client, h, "2026-09-23")
    assert (after["spent_minor"], after["refunds_minor"]) == (before["spent_minor"], 0)
