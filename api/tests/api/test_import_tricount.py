"""Tricount import: preview writes nothing, commit creates one tagged batch, undo removes it."""

import json
import uuid
from collections import Counter

import pytest
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.core.errors import ApiError
from app.modules.auth.deps import Actor
from app.modules.expenses.models import Expense
from app.modules.groups.models import Group, GroupMember
from app.modules.import_tricount import service
from app.modules.import_tricount.models import ImportBatch
from app.modules.import_tricount.schemas import ImportCommitIn
from app.modules.settlements.models import Settlement
from app.modules.sync.models import ChangeLog
from app.modules.users.models import User
from tests.api.conftest import gid, login, register, uid
from tests.tricount_files import goa_xlsx, read

API = "/api/v1"
CSV = ("tricount-goa-trip.csv", read("goa_trip.csv"), "text/csv")


def preview(client, h, file=CSV, **form):
    r = client.post(f"{API}/import/tricount/preview", headers=h, files={"file": file}, data=form)
    assert r.status_code == 200, r.text
    return r.json()


def commit(client, h, options, file=CSV, status=201):
    r = client.post(
        f"{API}/import/tricount/commit",
        headers=h,
        files={"file": file},
        data={"options": json.dumps(options)},
    )
    assert r.status_code == status, r.text
    return r.json()


def people_from(p):
    """The mapping the review screen sends when the user accepts every suggestion."""
    return [
        {"name": x["name"], "user_id": x["user"]["id"] if x["user"] else None} for x in p["people"]
    ]


def categories_from(p):
    return {c["name"]: c["key"] or "other" for c in p["categories"]}


def counts():
    with SessionLocal() as s:
        return {
            m.__name__: s.scalar(select(func.count()).select_from(m))
            for m in (Expense, Settlement, Group, GroupMember, User, ImportBatch, ChangeLog)
        }


def balances(client, h, group_id):
    r = client.get(f"{API}/groups/{group_id}/balances", headers=h)
    assert r.status_code == 200, r.text
    return {m["user"]["id"]: m["net_minor"] for m in r.json()["members"]}


# ---- preview ----


def test_preview_writes_nothing_and_suggests_a_mapping(client, seeded):
    h = login(client, "john")
    before = counts()
    p = preview(client, h)
    assert counts() == before

    assert (p["group_name"], p["currency"]) == ("Goa Trip", "INR")
    match = {x["name"]: (x["match"], x["user"]["name"] if x["user"] else None) for x in p["people"]}
    assert match == {
        "John": ("you", "John Doe"),
        "Rahul S": ("suggested", "Rahul Sharma"),
        "Aman": ("suggested", "Aman Verma"),
        "Priya": ("suggested", "Priya Nair"),
        "Vivek": ("suggested", "Vivek Iyer"),
        "Kabir M.": ("suggested", "Kabir Mehta"),
    }
    cats = {c["name"]: (c["key"], c["rows"]) for c in p["categories"]}
    assert cats == {
        "Transport": ("transport", 4),
        "Accommodation": ("stay", 2),
        "Food & drinks": ("food", 7),
        "Entertainment": ("entertainment", 3),
        "Parking": (None, 1),
        "Tips": (None, 1),
        "Shopping": ("shopping", 1),
    }
    assert {"food", "other"} <= {o["key"] for o in p["category_options"]}
    assert p["totals"] == {
        "expenses": 17,
        "expense_total_minor": 4_963_000,
        "transfers": 1,
        "transfer_total_minor": 100_000,
        "skipped": 2,
        "first_date": "2026-09-12",
        "last_date": "2026-09-20",
    }
    souvenirs = next(r for r in p["rows"] if r["title"] == "Souvenirs")
    assert souvenirs["issues"] == [
        {"level": "error", "code": "split_mismatch", "message": "₹100 still needs to be allocated"}
    ]
    dolphins = next(r for r in p["rows"] if r["title"] == "Dolphin trip")
    assert (dolphins["amount_minor"], dolphins["original"]) == (249000, "$30")


def test_preview_against_a_group_uses_its_members_and_currency(client, seeded):
    h = login(client, "john")
    p = preview(client, h, group_id=gid("goa"))
    kabir = next(x for x in p["people"] if x["name"] == "Kabir M.")
    # The seed's Goa Trip remembers Kabir's Tricount name as his placeholder name.
    assert (kabir["match"], kabir["user"]["id"]) == ("matched", uid("kabir"))
    assert p["group_name"] == "Goa Trip"


@pytest.mark.parametrize(
    "file",
    [
        ("goa.csv", read("goa_trip_semicolon.csv"), "text/csv"),
        ("goa.xlsx", goa_xlsx(), "application/octet-stream"),
    ],
)
def test_preview_other_formats(client, seeded, file):
    h = login(client, "john")
    assert preview(client, h, file=file)["totals"] == preview(client, h)["totals"]


def test_preview_errors(client, seeded):
    h = login(client, "john")
    r = client.post(
        f"{API}/import/tricount/preview",
        headers=h,
        files={"file": ("x.csv", b"name,email\n", "text/csv")},
    )
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "import_unreadable"
    assert "Settings → Export" in r.json()["error"]["message"]
    r = client.post(f"{API}/import/tricount/preview", files={"file": CSV})
    assert r.status_code == 401


# ---- commit ----


def new_group_options(p, name="Goa Trip (Tricount)"):
    people = people_from(p)
    for x in people:
        if x["name"] == "Kabir M.":
            x["user_id"] = None  # keep him a placeholder, as in the mockup
    return {
        "new_group": {"name": name, "currency": "INR"},
        "people": people,
        "categories": categories_from(p),
    }


def test_commit_into_a_new_group_creates_everything_tagged(client, seeded):
    h = login(client, "john")
    p = preview(client, h)
    batch = commit(client, h, new_group_options(p))
    stats = batch["stats"]
    assert {
        k: stats[k] for k in ("expenses", "transfers", "people", "placeholders", "skipped")
    } == {
        "expenses": 17,
        "transfers": 1,
        "people": 6,
        "placeholders": 1,
        "skipped": 2,
    }
    assert stats["expense_total_minor"] == 4_963_000 and stats["created_group"] is True
    why = {i["title"]: i["why"] for i in stats["review"]}
    assert why["Parasailing"] == "paid by placeholder “Kabir M.” — link to a real account"
    assert why["Parking at Baga"] == "category set to Other"
    assert why["Tip for driver"] == "category set to Other"
    assert "converted from $30" in why["Dolphin trip"]
    assert stats["skipped_rows"] == [
        "Row 19 · Souvenirs: ₹100 still needs to be allocated",
        "Row 20 · Villa deposit back: Income isn't supported yet, so this row is skipped",
    ]

    group_id = batch["group_id"]
    with SessionLocal() as s:
        group = s.get(Group, group_id)
        assert (group.name, str(group.import_batch_id)) == ("Goa Trip (Tricount)", batch["id"])
        members = s.scalars(select(GroupMember).where(GroupMember.group_id == group.id)).all()
        assert len(members) == 6 and all(str(m.import_batch_id) == batch["id"] for m in members)
        kabir = next(m for m in members if m.placeholder_name == "Kabir M.")
        assert s.get(User, kabir.user_id).email is None
        expenses = s.scalars(select(Expense).where(Expense.group_id == group.id)).all()
        assert len(expenses) == 17
        assert all(str(e.import_batch_id) == batch["id"] for e in expenses)
        assert all(sum(x.share_minor for x in e.splits) == e.amount_minor for e in expenses)
        [pay] = s.scalars(select(Settlement).where(Settlement.group_id == group.id)).all()
        assert (pay.from_user, pay.to_user, pay.amount_minor) == (
            uuid.UUID(uid("aman")),
            uuid.UUID(uid("rahul")),
            100000,
        )
        assert str(pay.import_batch_id) == batch["id"]
        parking = next(e for e in expenses if e.description == "Parking at Baga")
        food = next(e for e in expenses if e.description == "Late-night pizza")
        assert parking.category_id != food.category_id

        log = s.scalars(select(ChangeLog).where(ChangeLog.stream_id == f"group:{group_id}")).all()
    entities = [r.entity for r in log]
    assert entities.count("expense") == 17 and entities.count("settlement") == 1
    assert entities.count("group") == 1 and entities.count("member") == 6

    # Balances match the file: payers are owed the amount, everyone owes their share.
    ids = {x["name"]: x["user_id"] for x in new_group_options(p)["people"]}
    ids["Kabir M."] = str(kabir.user_id)
    expected: Counter = Counter()
    for r in p["rows"]:
        if r["issues"] and any(i["level"] == "error" for i in r["issues"]):
            continue
        expected[ids[r["payer"]]] += r["amount_minor"]
        for share in r["shares"]:
            expected[ids[share["name"]]] -= share["share_minor"]
    nets = balances(client, h, group_id)
    assert sum(nets.values()) == 0
    assert nets == {k: v for k, v in expected.items()}


def test_commit_and_undo_restore_balances_of_an_existing_group(client, seeded):
    h = login(client, "john")
    before = balances(client, h, gid("goa"))
    p = preview(client, h, group_id=gid("goa"))
    options = {"group_id": gid("goa"), "people": people_from(p), "categories": categories_from(p)}
    batch = commit(client, h, options)
    assert batch["stats"]["created_group"] is False and batch["stats"]["placeholders"] == 0
    assert balances(client, h, gid("goa")) != before

    # Someone edits an imported expense afterwards: undo still takes it out.
    with SessionLocal() as s:
        edited = s.scalar(
            select(Expense).where(
                Expense.import_batch_id == uuid.UUID(batch["id"]),
                Expense.description == "Train to Goa",
            )
        )
    r = client.put(
        f"{API}/expenses/{edited.id}",
        headers=h,
        json={
            "description": "Train to Goa (edited)",
            "amount_minor": 700000,
            "payer_id": uid("aman"),
            "date": "2026-09-12",
            "split": {
                "method": "equal",
                "inputs": [{"user_id": uid("john")}, {"user_id": uid("aman")}],
            },
            "version": edited.version,
        },
    )
    assert r.status_code == 200, r.text

    undone = client.post(f"{API}/import/batches/{batch['id']}/undo", headers=h)
    assert undone.status_code == 200, undone.text
    assert undone.json()["undone_at"] is not None
    assert balances(client, h, gid("goa")) == before
    with SessionLocal() as s:
        assert s.get(Expense, edited.id).deleted_at is not None
        # The group existed before, so it stays; its original members stay too.
        assert s.get(Group, uuid.UUID(gid("goa"))).archived_at is None

    # Idempotent: nothing more is written.
    before_again = counts()
    again = client.post(f"{API}/import/batches/{batch['id']}/undo", headers=h)
    assert again.status_code == 200 and counts() == before_again


def test_undo_of_a_new_group_archives_it_and_ends_the_memberships(client, seeded):
    h = login(client, "john")
    batch = commit(client, h, new_group_options(preview(client, h)))
    group_id = batch["group_id"]
    r = client.post(f"{API}/import/batches/{batch['id']}/undo", headers=h)
    assert r.status_code == 200
    with SessionLocal() as s:
        group = s.get(Group, uuid.UUID(group_id))
        assert group.archived_at is not None
        members = s.scalars(select(GroupMember).where(GroupMember.group_id == group.id)).all()
        assert all(m.left_at is not None for m in members)
        assert (
            s.scalar(
                select(func.count())
                .select_from(Expense)
                .where(Expense.group_id == group.id, Expense.deleted_at.is_(None))
            )
            == 0
        )
        ops = s.scalars(
            select(ChangeLog.action).where(ChangeLog.stream_id == f"group:{group_id}")
        ).all()
    assert ops.count("expense.delete") == 17 and ops.count("settlement.delete") == 1
    assert "member.remove" in ops and "group.update" in ops
    ids = [g["id"] for g in client.get(f"{API}/groups", headers=h).json()]
    assert group_id not in ids

    listed = client.get(f"{API}/import/batches", headers=h).json()
    mine = next(b for b in listed if b["id"] == batch["id"])
    assert mine["undone_at"] is not None and mine["group_name"] == "Goa Trip (Tricount)"
    # The seed's own Goa import lists too, with its older stats filled in.
    assert any(b["file_name"] == "tricount-goa-trip.xlsx" for b in listed)


def test_two_tricount_names_for_one_person_merge_their_shares(client, seeded):
    h = login(client, "john")
    p = preview(client, h)
    options = new_group_options(p)
    for x in options["people"]:
        if x["name"] == "Kabir M.":
            x["user_id"] = uid("john")  # "that was me, on my other phone"
    batch = commit(client, h, options)
    with SessionLocal() as s:
        pizza = s.scalar(
            select(Expense).where(
                Expense.group_id == uuid.UUID(batch["group_id"]),
                Expense.description == "Late-night pizza",
            )
        )
        mine = next(x.share_minor for x in pizza.splits if str(x.user_id) == uid("john"))
    assert mine == 20300 + 12500 and len(pizza.splits) == 5


# ---- permissions and bad input ----


def test_only_members_can_import_into_a_group(client, seeded):
    outsider, _ = register(client, "Neha", "neha@example.com")
    r = client.post(
        f"{API}/import/tricount/commit",
        headers=outsider,
        files={"file": CSV},
        data={"options": json.dumps({"group_id": gid("goa")})},
    )
    assert r.status_code == 404
    r = client.post(
        f"{API}/import/tricount/preview",
        headers=outsider,
        files={"file": CSV},
        data={"group_id": gid("goa")},
    )
    assert r.status_code == 404


def test_people_can_only_be_mapped_to_people_you_know(client, seeded):
    h = login(client, "john")
    _, stranger = register(client, "Neha", "neha@example.com")
    p = preview(client, h)
    options = new_group_options(p)
    options["people"][0]["user_id"] = stranger["id"]
    before = counts()
    r = commit(client, h, options, status=422)
    assert r["error"]["code"] == "import_unknown_person"
    assert counts() == before


def test_only_the_importer_can_see_and_undo_a_batch(client, seeded):
    h = login(client, "john")
    batch = commit(client, h, new_group_options(preview(client, h)))
    other = login(client, "aman")
    assert client.post(f"{API}/import/batches/{batch['id']}/undo", headers=other).status_code == 404
    assert all(
        b["id"] != batch["id"] for b in client.get(f"{API}/import/batches", headers=other).json()
    )


def test_bad_options(client, seeded):
    h = login(client, "john")
    r = commit(client, h, {"people": []}, status=422)
    assert r["error"]["code"] == "import_options_invalid"
    r = client.post(
        f"{API}/import/tricount/commit",
        headers=h,
        files={"file": CSV},
        data={"options": "not json"},
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "import_options_invalid"


def test_read_only_actors_cannot_import(seeded):
    with SessionLocal() as s:
        actor = Actor(user=s.get(User, uuid.UUID(uid("john"))), read_only=True)
        options = ImportCommitIn(new_group={"name": "X"})
        with pytest.raises(ApiError) as e:
            service.commit(s, actor, "x.csv", read("goa_trip.csv"), options)
        assert e.value.code == "read_only"
