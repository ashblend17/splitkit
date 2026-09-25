#!/usr/bin/env python3
"""Capture real API responses into app/test/fixtures/api for the Dart contract tests.

Needs the API running with freshly seeded data:
  docker compose exec api python -m app.seed --reset && python3 tool/capture_api_fixtures.py
Read-only except for one rejected (422) request.
"""

import json
import os
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("API", "http://localhost:8000") + "/api/v1"
OUT = Path(__file__).resolve().parents[1] / "app" / "test" / "fixtures" / "api"


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
    login = call("/auth/login", {"email": "ansh.c@cyware.com", "password": "splitkit-dev"})
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
                "description": "x", "amount_minor": 180000, "payer_id": members["Ansh C"], "date": "2026-09-24",
                "split": {"method": "exact", "inputs": [{"user_id": members["Ansh C"], "value": "170000"}]},
            },
            token,
        ),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in fixtures.items():
        (OUT / f"{name}.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(fixtures)} fixtures to {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT}")


if __name__ == "__main__":
    main()
