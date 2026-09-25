#!/usr/bin/env python3
"""Capture real API responses into app/test/fixtures/api for the Dart contract tests.

Needs the API running with freshly seeded data:
  docker compose exec api python -m app.seed --reset && python3 tool/capture_api_fixtures.py
Read-only except for one rejected (422) request.

Also writes app/test/fixtures/sync/<user>.json: every sync snapshot a seeded user can see plus the
API's own answers (groups, balances, feed, expenses, settle-up plans, personal) for the same data.
The app's parity test rebuilds each answer from the snapshots alone and compares.
"""

import json
import os
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("API", "http://localhost:8000") + "/api/v1"
OUT = Path(__file__).resolve().parents[1] / "app" / "test" / "fixtures" / "api"
SYNC_OUT = OUT.parent / "sync"
PARITY_USERS = {"john": "admin@example.com", "rahul": "rahul.sharma@example.com"}


def call(path, body=None, token=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body is not None else None,
        method="POST" if body is not None else "GET",
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())


def main():
    login = call("/auth/login", {"email": "admin@example.com", "password": "dev-password"})
    token = login["access_token"]
    login["access_token"] = "<token>"
    groups = call("/groups", token=token)
    goa = next(g for g in groups if g["name"] == "Goa Trip")
    members = {m["user"]["name"]: m["user"]["id"] for m in goa["members"]}
    feed = call("/feed?limit=8", token=token)
    dinner = next(i for i in feed if i["title"] == "Dinner at Thalassa")
    scooter = next(i for i in call(f"/feed?group_id={goa['id']}&limit=100", token=token) if i["title"] == "Scooter rentals")
    fixtures = {
        "login": login,
        "groups": groups,
        "balances": call("/balances", token=token),
        "group_balances": call(f"/groups/{goa['id']}/balances", token=token),
        "feed": feed,
        "expense": call(f"/expenses/{dinner['id']}", token=token),
        "expense_history": call(f"/expenses/{scooter['id']}/history", token=token),
        "split_methods": call("/splits/methods", token=token),
        "categories": call("/categories?scope=group", token=token),
        "settle_up_plan": call(f"/friends/{members['Aman Verma']}/settle-up", token=token),
        "personal_summary": call("/personal/summary?month=2026-09-23", token=token),
        "personal_list": call("/personal/transactions?start=2026-09-01&end=2026-09-23", token=token),
        "personal_categories": call("/categories?scope=personal", token=token),
        "analytics_personal": call("/analytics/personal?period=month&on=2026-09-23", token=token),
        "analytics_group": call(f"/analytics/groups/{goa['id']}?on=2026-09-23", token=token),
        "analytics_layout": call("/analytics/layout/personal", token=token),
        "error_split_invalid": call(
            f"/groups/{goa['id']}/expenses",
            {
                "description": "x", "amount_minor": 180000, "payer_id": members["John Doe"], "date": "2026-09-24",
                "split": {"method": "exact", "inputs": [{"user_id": members["John Doe"], "value": "170000"}]},
            },
            token,
        ),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in fixtures.items():
        (OUT / f"{name}.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    capture_sync()
    print(f"Wrote {len(fixtures)} fixtures to {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT}")


def capture_sync():
    SYNC_OUT.mkdir(parents=True, exist_ok=True)
    for key, email in PARITY_USERS.items():
        login = call("/auth/login", {"email": email, "password": "dev-password"})
        if "access_token" not in login:
            raise SystemExit(f"Can't log in as {email}: {login}")
        token = login["access_token"]
        streams = [s["stream"] for s in call("/sync", {"cursors": {}}, token)["streams"]]
        snapshots = {s: call(f"/sync/snapshot/{s}", token=token) for s in streams}
        groups = call("/groups", token=token)
        archived = call("/groups?archived=true", token=token)
        answers = {
            "me": call("/me", token=token),
            "groups": groups,
            "groups_archived": archived,
            "balances": call("/balances", token=token),
            "feed": call("/feed?limit=100", token=token),
            "feed_deleted": call("/feed?deleted=true&limit=100", token=token),
            "categories": call("/categories", token=token),
            "categories_group": call("/categories?scope=group", token=token),
            "categories_personal": call("/categories?scope=personal", token=token),
        }
        for g in groups + archived:
            gid = g["id"]
            answers[f"group:{gid}"] = call(f"/groups/{gid}", token=token)
            answers[f"group_balances:{gid}"] = call(f"/groups/{gid}/balances", token=token)
            answers[f"feed:{gid}"] = call(f"/feed?group_id={gid}&limit=100", token=token)
            for item in answers[f"feed:{gid}"]:
                if item["kind"] == "expense":
                    answers[f"expense:{item['id']}"] = call(f"/expenses/{item['id']}", token=token)
        for f in answers["balances"]["friends"]:
            answers[f"settle_up:{f['user']['id']}:{f['currency']}"] = call(
                f"/friends/{f['user']['id']}/settle-up?currency={f['currency']}", token=token
            )
        for month in ("2026-07-01", "2026-08-01", "2026-09-01"):
            answers[f"personal_summary:{month}"] = call(f"/personal/summary?month={month}", token=token)
        answers["personal_list"] = call("/personal/transactions?limit=500", token=token)
        answers["personal_list:sep_expense"] = call(
            "/personal/transactions?start=2026-09-01&end=2026-09-30&type=expense&limit=500", token=token
        )
        answers["personal_deleted"] = call("/personal/transactions?deleted=true&limit=500", token=token)
        out = {"user": key, "email": email, "snapshots": snapshots, "answers": answers}
        (SYNC_OUT / f"{key}.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
