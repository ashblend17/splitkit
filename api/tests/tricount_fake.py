"""An in-memory Tricount (api.tricount.bunq.com) for tests, behind httpx.MockTransport.

It follows the wire format the open-source clients document (see
app/modules/tricount_sync/wire.py): {"Response": [...]} envelopes, one-key wrappers around list
items, negative expense amounts, flat uuids in requests and nested ones in responses. It also
copies the behaviours the sync relies on: writes only from the Android app's User-Agent,
sessions that expire, creates that are idempotent by uuid, updates that replace the whole
entry, and members dropped when they're left out of a membership update. As the real one does
(seen on a real tricount, 2026-10-24), it keeps an entry's "date" as sent, stamps "created" in
UTC, and credits each write to the member the device counts as (`membership_uuid_active`: the
lowest id when it joins, then whoever a registry PUT names); `added_by` says who that was.

Tests act as someone using Tricount through `add_expense`, `edit`, `remove`, and can make the
service fail (`down`, `fail_next`).
"""

import itertools
import json
import re
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

import httpx

ANDROID = "com.bunq.tricount.android"
TIME = "%Y-%m-%d %H:%M:%S.%f"


class FakeTricount:
    def __init__(self) -> None:
        self.ids = itertools.count(1000)
        self.tokens: dict[str, int] = {}
        """session token -> user id"""
        self.devices: dict[str, int] = {}
        """installation id -> user id"""
        self.joined: dict[int, set[int]] = {}
        """user id -> registry ids it follows"""
        self.active: dict[tuple[int, int], str] = {}
        """(user id, registry id) -> the member that device counts as"""
        self.registries: dict[int, dict[str, Any]] = {}
        self.down = False
        self.fail_next: list[tuple[int, str]] = []
        """(status, message) answers to give, in order, before working normally again."""
        self.calls: list[tuple[str, str]] = []
        self.writes: list[tuple[str, str, Any]] = []
        self.refuse_active = False
        """Refuse to switch whom a device counts as (a registry PUT naming a member)."""

    @property
    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self.handle)

    # ---- setting the scene (as someone using the Tricount app) ----

    def make(self, title: str, currency: str, people: list[str]) -> dict[str, Any]:
        rid = next(self.ids)
        reg = {
            "id": rid,
            "uuid": str(uuid.uuid4()),
            "title": title,
            "description": "",
            "currency": currency,
            "category": "OTHER",
            "status": "READ_WRITE",
            "created": "2026-09-01 10:00:00.000000",
            "public_identifier_token": f"tFAKE{rid}",
            "members": [self._member(name) for name in people],
            "entries": [],
        }
        self.registries[rid] = reg
        return reg

    def _member(self, name: str, member_uuid: str | None = None) -> dict[str, Any]:
        return {
            "id": next(self.ids),
            "uuid": member_uuid or str(uuid.uuid4()),
            "status": "ACTIVE",
            "name": name,
        }

    def member(self, reg: dict[str, Any], name: str) -> str:
        return next(
            m["uuid"] for m in reg["members"] if m["name"] == name and m["status"] == "ACTIVE"
        )

    def add_expense(
        self,
        reg: dict[str, Any],
        description: str,
        amount: str,
        payer: str,
        shares: dict[str, str],
        day: str = "2026-09-20",
        category: str = "FOOD_AND_DRINK",
        kind: str = "NORMAL",
        ratios: dict[str, int] | None = None,
        at: str | None = None,
    ) -> dict[str, Any]:
        """As someone does in the app, which dates it the moment it's made (UTC): midday in
        India on `day` unless `at` says when."""
        negative = kind == "NORMAL"
        sign = "-" if negative else ""
        entry = {
            "id": next(self.ids),
            "uuid": str(uuid.uuid4()),
            "date": at or f"{day} 06:30:00.000000",
            "description": description,
            "type": "MANUAL",
            "type_transaction": kind,
            "status": "ACTIVE",
            "amount": {"value": f"{sign}{amount}", "currency": reg["currency"]},
            "category": category,
            "payer": self.member(reg, payer),
            "allocations": [
                {
                    "member": self.member(reg, who),
                    "amount": {"value": f"{sign}{value}", "currency": reg["currency"]},
                    "type": "RATIO" if ratios else "AMOUNT",
                    "share_ratio": ratios[who] if ratios else None,
                }
                for who, value in shares.items()
            ],
            "attachment": [],
        }
        reg["entries"].append(entry)
        return entry

    def add_transfer(
        self, reg, amount: str, frm: str, to: str, day="2026-09-21", note="Reimbursement"
    ):
        return self.add_expense(
            reg,
            note,
            amount,
            frm,
            {to: amount, frm: "0"},
            day=day,
            category="UNCATEGORIZED",
            kind="BALANCE",
        )

    def entry(self, reg: dict[str, Any], entry_id: int) -> dict[str, Any]:
        return next(e for e in reg["entries"] if e["id"] == entry_id)

    def edit(self, reg: dict[str, Any], entry_id: int, **changes: Any) -> None:
        e = self.entry(reg, entry_id)
        for key, value in changes.items():
            if key == "amount":
                sign = "-" if e["type_transaction"] == "NORMAL" else ""
                e["amount"] = {"value": f"{sign}{value}", "currency": reg["currency"]}
            else:
                e[key] = value

    def remove(self, reg: dict[str, Any], entry_id: int) -> None:
        reg["entries"] = [e for e in reg["entries"] if e["id"] != entry_id]

    def by_description(self, reg: dict[str, Any], description: str) -> dict[str, Any]:
        return next(e for e in reg["entries"] if e["description"] == description)

    def added_by(self, reg: dict[str, Any], entry: dict[str, Any]) -> str | None:
        """The name Tricount shows as having added (or last changed) `entry`."""
        return next((m["name"] for m in reg["members"] if m["uuid"] == entry.get("_by")), None)

    def _join(self, user: int, reg: dict[str, Any]) -> None:
        self.joined[user].add(reg["id"])
        active = sorted(
            (m for m in reg["members"] if m["status"] == "ACTIVE"), key=lambda m: m["id"]
        )
        if active:
            self.active.setdefault((user, reg["id"]), active[0]["uuid"])

    # ---- the API ----

    def handle(self, request: httpx.Request) -> httpx.Response:
        self.calls.append((request.method, request.url.path))
        if self.down:
            raise httpx.ConnectError("Tricount is down", request=request)
        if self.fail_next:
            status, message = self.fail_next.pop(0)
            return self._error(status, message)
        body = json.loads(request.content) if request.content else None
        if request.method != "GET":
            self.writes.append((request.method, request.url.path, body))
            if not request.headers.get("User-Agent", "").startswith(ANDROID):
                return self._error(400, "Group Expenses is no longer available in the bunq app")
        path = request.url.path
        if path == "/v1/session-registry-installation":
            return self._register(body)
        m = re.fullmatch(r"/v1/user/(\d+)(/.*)", path)
        if not m:
            return self._error(404, "Route not found")
        user = int(m.group(1))
        if self.tokens.get(request.headers.get("X-Bunq-Client-Authentication", "")) != user:
            return self._error(401, "Insufficient authorisation")
        return self._route(user, request.method, m.group(2), body, request.url.params)

    def expire_sessions(self) -> None:
        self.tokens.clear()

    def _register(self, body: dict[str, Any]) -> httpx.Response:
        if not body or not body.get("client_public_key", "").startswith(
            "-----BEGIN RSA PUBLIC KEY"
        ):
            return self._error(400, "A public key is required")
        user = self.devices.setdefault(body["app_installation_uuid"], next(self.ids))
        token = uuid.uuid4().hex
        self.tokens[token] = user
        self.joined.setdefault(user, set())
        return self._ok(
            [{"Id": {"id": 1}}, {"Token": {"token": token}}, {"UserPerson": {"id": user}}]
        )

    def _route(self, user: int, method: str, path: str, body: Any, params) -> httpx.Response:
        if path == "/registry" and method == "GET":
            token = params.get("public_identifier_token")
            found = [
                r
                for r in self.registries.values()
                if (token and r["public_identifier_token"] == token)
                or (not token and r["id"] in self.joined[user])
            ]
            return self._ok([{"Registry": self._registry_out(r, user=user)} for r in found])
        if path == "/registry" and method == "POST":
            reg = self.make(body["title"], body["currency"], [])
            reg["members"].append(self._member(""))  # the device that made it
            self._join(user, reg)
            return self._ok([{"Id": {"id": reg["id"]}}])
        if path == "/registry-synchronization" and method == "POST":
            for ref in body["all_registry_active"]:
                reg = self._by_token(ref["public_identifier_token"])
                if reg is None:
                    return self._error(404, "Registry not found")
                self._join(user, reg)
            active = [
                self._registry_out(self.registries[i], entries=False, user=user)
                for i in sorted(self.joined[user])
            ]
            return self._ok(
                [
                    {
                        "RegistrySynchronization": {
                            "all_registry_active": active,
                            "all_registry_archived": [],
                        }
                    }
                ]
            )
        m = re.fullmatch(r"/registry/(\d+)(?:/registry-entry(?:/(\d+))?)?", path)
        if not m:
            return self._error(404, "Route not found")
        rid = int(m.group(1))
        reg = self.registries.get(rid)
        if reg is None or rid not in self.joined[user]:
            return self._error(404, "Registry not found")
        if "/registry-entry" not in path:
            if method == "GET":
                return self._ok([{"Registry": self._registry_out(reg, user=user)}])
            if method == "PUT":
                return self._update_registry(reg, body, user)
            return self._error(405, "Method not allowed")
        eid = int(m.group(2)) if m.group(2) else None
        if eid is None and method == "POST":
            return self._create_entry(reg, body, user)
        entry = next((e for e in reg["entries"] if e["id"] == eid), None)
        if entry is None:
            return self._error(404, "Entry not found")
        if method == "PUT":
            problem = self._check_entry(reg, body)
            if problem:
                return self._error(400, problem)
            new = self._entry_in(reg, body, eid, user)
            new["created"] = entry.get("created", new["created"])
            reg["entries"][reg["entries"].index(entry)] = new
            return self._ok([{"Id": {"id": eid}}])
        if method == "DELETE":
            self.remove(reg, eid)
            return self._ok([])
        return self._error(405, "Method not allowed")

    def _by_token(self, token: str) -> dict[str, Any] | None:
        return next(
            (r for r in self.registries.values() if r["public_identifier_token"] == token), None
        )

    def _update_registry(
        self, reg: dict[str, Any], body: dict[str, Any], user: int
    ) -> httpx.Response:
        if "currency" in body:
            return self._error(400, "The currency can't be changed")
        if "membership_uuid_active" in body:
            if self.refuse_active:
                return self._error(400, "Field membership_uuid_active is superfluous")
            wanted = body["membership_uuid_active"]
            if not any(m["uuid"] == wanted and m["status"] == "ACTIVE" for m in reg["members"]):
                return self._error(400, "Unknown membership")
            self.active[(user, reg["id"])] = wanted
        if "title" in body:
            reg["title"] = body["title"]
        if "memberships" in body:
            sent = {m["uuid"]: m for m in body["memberships"]}
            for m in reg["members"]:
                if m["status"] == "ACTIVE" and m["uuid"] not in sent:
                    m["status"] = "DELETED"  # left out: dropped
                elif m["uuid"] in sent:
                    m["name"] = sent[m["uuid"]]["alias"]["name"]
            known = {m["uuid"] for m in reg["members"]}
            for u, m in sent.items():
                if u not in known:
                    reg["members"].append(self._member(m["alias"]["name"], u))
        return self._ok([{"Id": {"id": reg["id"]}}])

    def _check_entry(self, reg: dict[str, Any], body: dict[str, Any]) -> str | None:
        if "type" in body:
            return "Field type is superfluous"
        active = {m["uuid"] for m in reg["members"] if m["status"] == "ACTIVE"}
        if body["membership_uuid_owner"] not in active:
            return "Unknown owner"
        kind = body["type_transaction"]
        total = Decimal(body["amount"]["value"])
        if (kind == "NORMAL") != (total < 0):
            return "Expenses are negative, other entries positive"
        parts = [Decimal(a["amount"]["value"]) for a in body["allocations"]]
        if sum(parts) != total:
            return "Allocations don't add up to the amount"
        if any(a["membership_uuid"] not in active for a in body["allocations"]):
            return "Unknown member in allocations"
        datetime.strptime(body["date"], "%Y-%m-%d %H:%M:%S.%f")
        return None

    def _entry_in(
        self, reg: dict[str, Any], body: dict[str, Any], eid: int, user: int
    ) -> dict[str, Any]:
        now = datetime.now(UTC).strftime(TIME)
        return {
            "_by": self.active.get((user, reg["id"])),
            "created": now,
            "updated": now,
            "id": eid,
            "uuid": body["uuid"],
            "date": body["date"],
            "description": body["description"],
            "type": "MANUAL",
            "type_transaction": body["type_transaction"],
            "status": body.get("status", "ACTIVE"),
            "amount": body["amount"],
            "category": body.get("category", "UNCATEGORIZED"),
            "category_custom": body.get("category_custom"),
            "payer": body["membership_uuid_owner"],
            "allocations": [
                {
                    "member": a["membership_uuid"],
                    "amount": a["amount"],
                    "type": a["type"],
                    "share_ratio": a.get("share_ratio"),
                }
                for a in body["allocations"]
            ],
            "attachment": body.get("attachment", []),
        }

    def _create_entry(self, reg: dict[str, Any], body: dict[str, Any], user: int) -> httpx.Response:
        for e in reg["entries"]:
            if e["uuid"] == body.get("uuid"):
                return self._ok([{"Id": {"id": e["id"]}}])  # the first write wins
        problem = self._check_entry(reg, body)
        if problem:
            return self._error(400, problem)
        entry = self._entry_in(reg, body, next(self.ids), user)
        reg["entries"].append(entry)
        return self._ok([{"Id": {"id": entry["id"]}}])

    # ---- response shapes ----

    def _registry_out(
        self, reg: dict[str, Any], entries: bool = True, user: int | None = None
    ) -> dict[str, Any]:
        out = {k: v for k, v in reg.items() if k not in ("members", "entries")}
        out["membership_uuid_active"] = self.active.get((user, reg["id"]))
        out["memberships"] = [
            {
                "RegistryMembershipNonUser": {
                    "id": m["id"],
                    "uuid": m["uuid"],
                    "status": m["status"],
                    "alias": {
                        "display_name": m["name"],
                        "pointer": {"type": "UUID", "value": m["uuid"], "name": m["name"]},
                    },
                }
            }
            for m in reg["members"]
        ]
        if entries:
            out["all_registry_entry"] = [
                {"RegistryEntry": self._entry_out(e)} for e in reg["entries"]
            ]
        return out

    def _entry_out(self, e: dict[str, Any]) -> dict[str, Any]:
        out = {k: v for k, v in e.items() if k not in ("payer", "allocations") and k[0] != "_"}
        out["membership_owned"] = {"RegistryMembershipNonUser": {"uuid": e["payer"], "alias": {}}}
        out["allocations"] = [
            {
                "amount": a["amount"],
                "type": a["type"],
                "share_ratio": a["share_ratio"],
                "membership": {"RegistryMembershipNonUser": {"uuid": a["member"]}},
            }
            for a in e["allocations"]
        ]
        return out

    def _ok(self, items: list[Any]) -> httpx.Response:
        return httpx.Response(200, json={"Response": items})

    def _error(self, status: int, message: str) -> httpx.Response:
        return httpx.Response(status, json={"Error": [{"error_description": message}]})
