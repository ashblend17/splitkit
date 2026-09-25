from tests.api.conftest import gid, login, register, uid

API = "/api/v1"


def test_group_balances_match_group_balances_mockup(client, seeded):
    b = client.get(f"{API}/groups/{gid('goa')}/balances", headers=login(client, "ansh")).json()
    assert [(p["user"]["name"], p["net_minor"]) for p in b["people"]] == [
        ("Kabir Mehta", -75000),  # You owe ₹750
        ("Rahul Sharma", -50000),  # You owe ₹500
        ("Priya Nair", 155000),  # Owes you ₹1,550
        ("Aman Verma", 85000),  # Owes you ₹850
        ("Vivek Iyer", 0),  # All square
    ]
    assert (b["you_owe_minor"], b["you_are_owed_minor"], b["net_minor"]) == (125000, 240000, 115000)
    assert sum(m["net_minor"] for m in b["members"]) == 0


def test_suggested_payments_settle_the_group(client, seeded):
    b = client.get(f"{API}/groups/{gid('goa')}/balances", headers=login(client, "ansh")).json()
    nets = {m["user"]["id"]: m["net_minor"] for m in b["members"]}
    for p in b["suggested"]:
        nets[p["from_user"]["id"]] += p["amount_minor"]
        nets[p["to_user"]["id"]] -= p["amount_minor"]
    assert set(nets.values()) == {0}
    assert len(b["suggested"]) < len([n for n in nets if n])


def test_balances_are_seen_from_each_viewer(client, seeded):
    b = client.get(f"{API}/groups/{gid('goa')}/balances", headers=login(client, "rahul")).json()
    assert {p["user"]["name"]: p["net_minor"] for p in b["people"]}["Ansh C"] == 50000


def test_overall_balances_for_home(client, seeded):
    b = client.get(f"{API}/balances", headers=login(client, "ansh")).json()
    assert b["totals"] == [
        {
            "currency": "INR",
            "net_minor": 147000,
            "you_owe_minor": 125000,
            "you_are_owed_minor": 272000,
        }
    ]
    assert [(f["user"]["name"], f["net_minor"]) for f in b["friends"]] == [
        ("Kabir Mehta", -75000),
        ("Rahul Sharma", -50000),
        ("Priya Nair", 155000),
        ("Aman Verma", 117000),
        ("Vivek Iyer", 0),
    ]
    assert {g["name"]: g["net_minor"] for g in b["groups"]} == {
        "Goa Trip": 115000,
        "Flatmates": 32000,
    }


def test_new_user_has_empty_balances(client):
    headers, _ = register(client, "New", "new@example.com")
    assert client.get(f"{API}/balances", headers=headers).json() == {
        "totals": [],
        "friends": [],
        "groups": [],
    }


def test_feed_newest_first_with_my_perspective(client, seeded):
    items = client.get(f"{API}/feed?limit=5", headers=login(client, "ansh")).json()
    assert [(i["kind"], i["title"], i["group_name"]) for i in items] == [
        ("expense", "Dinner at Thalassa", "Goa Trip"),
        ("expense", "Groceries", "Flatmates"),
        ("expense", "Uber to airport", "Goa Trip"),
        ("settlement", None, "Goa Trip"),
        ("expense", "Electricity bill", "Flatmates"),
    ]
    dinner, groceries, uber, paid, electricity = items
    assert (dinner["my_net_minor"], dinner["participant_count"]) == (-45000, 4)  # you owe ₹450
    assert groceries["my_net_minor"] == 156000  # you are owed ₹1,560
    assert uber["my_net_minor"] == 31000  # Rahul owes you ₹310
    assert (paid["payer"]["name"], paid["to_user"]["name"], paid["amount_minor"]) == (
        "Ansh C",
        "Rahul Sharma",
        50000,
    )
    assert electricity["my_share_minor"] == 80000  # your share ₹800


def test_feed_pagination_and_group_filter(client, seeded):
    headers = login(client, "ansh")
    everything = client.get(f"{API}/feed?limit=100", headers=headers).json()
    assert len(everything) == 15 + 11 + 1  # live Goa + live Flatmates expenses + 1 payment
    page2 = client.get(f"{API}/feed?limit=5&offset=5", headers=headers).json()
    assert [i["id"] for i in page2] == [i["id"] for i in everything[5:10]]
    goa = client.get(f"{API}/feed?group_id={gid('goa')}&limit=100", headers=headers).json()
    assert {i["group_name"] for i in goa} == {"Goa Trip"}


def _titles(client, headers, query):
    items = client.get(f"{API}/feed?limit=100&{query}", headers=headers).json()
    return [(i["kind"], i["title"]) for i in items]


def test_feed_filters_by_category_dates_and_search(client, seeded):
    headers = login(client, "ansh")
    food = _titles(client, headers, "category=food")
    assert food[:3] == [
        ("expense", "Dinner at Thalassa"),
        ("expense", "Beach shack lunch"),
        ("expense", "Late-night pizza"),
    ]
    assert {k for k, _ in food} == {"expense"}  # payments have no category
    assert _titles(client, headers, "start=2026-09-21&end=2026-09-22") == [
        ("expense", "Uber to airport"),
        ("settlement", None),
        ("expense", "Electricity bill"),
    ]
    # Description, case-insensitive; and payer or payment names.
    assert _titles(client, headers, "q=THAL") == [
        ("expense", "Dinner at Thalassa"),
        ("expense", "Fish thali at Ritz Classic"),
    ]
    assert ("settlement", None) in _titles(client, headers, "q=rahul")
    assert _titles(client, headers, "q=%25") == []  # % is matched literally
    assert _titles(client, headers, "q=%20%20") == _titles(client, headers, "")


def test_feed_unsettled_only_keeps_open_expenses(client, seeded):
    headers = login(client, "ansh")
    items = client.get(f"{API}/feed?limit=100&unsettled=true", headers=headers).json()
    titles = [i["title"] for i in items]
    assert titles[:2] == ["Dinner at Thalassa", "Groceries"]  # you owe Rahul; flatmates owe you
    assert "Beach shack lunch" not in titles  # you are square with Aman in Goa
    assert "Uber to airport" not in titles  # you paid, but on balance you owe Rahul
    assert all(i["kind"] == "expense" and not i["settled"] for i in items)
    page = client.get(f"{API}/feed?limit=3&offset=2&unsettled=true", headers=headers).json()
    assert [i["title"] for i in page] == titles[2:5]


def test_admin_edits_are_flagged_in_the_feed(client, seeded):
    goa = client.get(
        f"{API}/feed?group_id={gid('goa')}&limit=100", headers=login(client, "ansh")
    ).json()
    assert [i["title"] for i in goa if i["by_admin"]] == ["Scooter rentals"]


def test_left_members_still_count_in_friend_balances(client, seeded):
    headers = login(client, "ansh")
    client.post(
        f"{API}/groups/{gid('goa')}/settlements",
        headers=headers,
        json={
            "from_user": uid("vivek"),
            "to_user": uid("ansh"),
            "amount_minor": 1,
            "date": "2026-09-24",
        },
    )
    friends = {
        f["user"]["name"]: f["net_minor"]
        for f in client.get(f"{API}/balances", headers=headers).json()["friends"]
    }
    assert friends["Vivek Iyer"] == -1
