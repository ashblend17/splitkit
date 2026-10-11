"""One sync pass for a linked group: Tricount and Splitkit end up the same, or a conflict is
recorded for someone to resolve.

A pass reads the whole tricount (Tricount has no change feed), then:

1. People: Tricount members Splitkit doesn't know become placeholder members (or are matched
   by name); Splitkit members Tricount doesn't know are added to the tricount.
2. The group's name.
3. Entries, compared three ways (see mapping.py): Splitkit's version L, Tricount's R, and the
   base B both last agreed on. Only R moved: Tricount's change is applied here. Only L moved:
   it is sent to Tricount. Both moved differently: a TricountConflict. Deletions count as
   changes, and new entries on either side are created on the other.

Nothing needs a separate retry queue: what still has to be sent is whatever differs from its
base, so a pass that fails half way (Tricount down, a crash) just leaves work for the next.
Creates on both sides use ids derived from the other side's, so redoing one never duplicates.
Every Splitkit write goes through record() as the "Tricount" system user, so devices get it
through the sync log and history says "by Tricount".
"""

import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from sqlalchemy import select, text, update
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.orm.exc import StaleDataError

from app.core.db import SessionLocal
from app.core.events import record
from app.core.money import format_minor
from app.modules.admin.models import AuditLog
from app.modules.auth.deps import Actor
from app.modules.categories.models import Category
from app.modules.expenses import repository as expenses_repo
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups import repository as groups_repo
from app.modules.groups.models import Group, GroupMember
from app.modules.import_tricount.matching import _norm as norm_name
from app.modules.settlements.models import Settlement
from app.modules.tricount_sync import mapping, wire
from app.modules.tricount_sync.client import Client, TricountError
from app.modules.tricount_sync.models import (
    TricountConflict,
    TricountEntry,
    TricountLink,
    TricountMember,
)
from app.modules.users.models import User

log = logging.getLogger("tricount_sync")

SYSTEM_USER_ID = uuid.uuid5(mapping.NAMESPACE, "system-user")
"""The "Tricount" user that changes pulled from Tricount are recorded as (same id everywhere,
so the app can name it without a lookup)."""

LEASE = timedelta(minutes=5)
MASS_DELETE = 0.5
"""A pass that would delete more than half the synced entries (and at least 5) stops short:
that's more likely a broken read than a real cleanup."""


def system_actor(session: Session) -> Actor:
    user = session.get(User, SYSTEM_USER_ID)
    if user is None:
        user = User(id=SYSTEM_USER_ID, name="Tricount", role="system")
        session.add(user)
        session.flush()
    return Actor(user=user)


# ---- the pass ----


class Busy(Exception):
    """Another process is running a pass for this link."""


@dataclass
class Outcome:
    pulled: int = 0
    pushed: int = 0
    conflicts: int = 0
    warnings: list[str] = field(default_factory=list)


def human_error(e: Exception) -> str:
    if isinstance(e, TricountError):
        if e.status == 404:
            return "The tricount can't be found. It may have been deleted, or its link changed."
        if e.status in (401, 403):
            return f"Tricount refused the request: {e.message}"
        if e.status == 429:
            return "Tricount asked us to slow down. Trying again later."
        if e.status >= 500:
            return "Tricount isn't working right now. Trying again later."
        return f"Tricount refused a change: {e.message}"
    if isinstance(e, httpx.HTTPError):
        return "Can't reach Tricount right now. Trying again later."
    if isinstance(e, wire.WireError):
        return f"Tricount sent something unexpected: {e}"
    return "Something went wrong while syncing. Trying again later."


def backoff(failures: int) -> timedelta:
    """1, 2, 4 … minutes, at most an hour."""
    return timedelta(minutes=min(60, 2 ** max(0, failures - 1)))


def _lease(group_id: uuid.UUID) -> bool:
    with SessionLocal.begin() as session:
        now = datetime.now(UTC)
        taken = session.execute(
            update(TricountLink)
            .where(
                TricountLink.group_id == group_id,
                (TricountLink.lease_until.is_(None)) | (TricountLink.lease_until < now),
            )
            .values(lease_until=now + LEASE)
            .returning(TricountLink.group_id)
        ).first()
    return taken is not None


def head_seq(session: Session, group_id: uuid.UUID) -> int:
    return (
        session.scalar(
            text("SELECT head_seq FROM sync_streams WHERE id = :s"), {"s": f"group:{group_id}"}
        )
        or 0
    )


def run(group_id: uuid.UUID) -> Outcome:
    """One pass. Raises Busy if another is running; failures are stored on the link (and
    re-raised) so the app can show them and the worker backs off."""
    if not _lease(group_id):
        raise Busy()
    try:
        with SessionLocal() as session:
            start_head = head_seq(session, group_id)
            outcome = _Pass(session, group_id).run()
            link = session.get(TricountLink, group_id)
            if link is not None:
                link.state, link.last_error, link.failures = "ok", None, 0
                link.warnings = outcome.warnings
                link.last_synced_at = datetime.now(UTC)
                link.next_attempt_at = None
                link.seen_seq = start_head
                link.lease_until = None
                session.commit()
            return outcome
    except Exception as e:
        with SessionLocal.begin() as session:
            link = session.get(TricountLink, group_id)
            if link is not None:
                link.failures += 1
                link.state = "error"
                link.last_error = human_error(e)
                retry = getattr(e, "retry_after", None)
                wait = timedelta(seconds=retry) if retry else backoff(link.failures)
                link.next_attempt_at = datetime.now(UTC) + wait
                link.lease_until = None
        if not isinstance(e, TricountError | httpx.HTTPError):
            log.exception("Tricount sync for group %s failed", group_id)
        raise


class _Pass:
    def __init__(self, session: Session, group_id: uuid.UUID):
        self.s = session
        self.group_id = group_id
        self.out = Outcome()

    def run(self) -> Outcome:
        s = self.s
        self.link = s.get(TricountLink, self.group_id)
        self.group = s.get(Group, self.group_id)
        if self.link is None or self.group is None:
            return self.out
        self.actor = system_actor(s)
        self.client = Client.for_device(s)
        try:
            self.remote = self._read()
            s.commit()  # keep the device's session token
            if self.remote.currency != self.link.currency:
                raise wire.WireError(
                    f"The tricount is in {self.remote.currency} and the group in "
                    f"{self.link.currency}"
                )
            self._people()
            self._title()
            self._entries()
        finally:
            self.client.close()
        return self.out

    def _read(self) -> wire.Registry:
        try:
            return self.client.registry(self.link.registry_id)
        except TricountError as e:
            if not e.gone:
                raise
            # This device may have lost the tricount (a new device row): join it again.
            return self.client.join(self.link.public_token)

    # ---- people ----

    def _people(self) -> None:
        s, gid = self.s, self.group_id
        rows = list(s.scalars(select(TricountMember).where(TricountMember.group_id == gid)))
        local = {u.id: (m, u) for m, u in groups_repo.active_members(s, gid)}
        self._follow_merges(rows, local)
        self.member_of: dict[uuid.UUID, str] = {r.user_id: r.membership_uuid for r in rows}
        self.user_of: dict[str, uuid.UUID] = {r.membership_uuid: r.user_id for r in rows}

        for rm in self.remote.active_members():
            if rm.uuid in self.user_of:
                continue
            free = [(m, u) for uid, (m, u) in local.items() if uid not in self.member_of]
            same = [
                u.id
                for m, u in free
                if norm_name(rm.name) in (norm_name(u.name), norm_name(m.placeholder_name or ""))
            ]
            user_id = same[0] if len(same) == 1 else self._new_placeholder(rm.name)
            self._map_member(rm.uuid, user_id)

        missing = [(m, u) for uid, (m, u) in local.items() if uid not in self.member_of]
        if missing:
            keep = [wire.membership(m.uuid, m.name) for m in self.remote.active_members()]
            added = [
                (mapping.member_uuid(gid, u.id), m.placeholder_name or u.name, u.id)
                for m, u in missing
            ]
            self.client.update_registry(
                self.link.registry_id,
                {"memberships": keep + [wire.membership(muid, name) for muid, name, _ in added]},
            )
            for muid, name, user_id in added:
                self._map_member(muid, user_id)
                self.remote.members.append(wire.Member(muid, None, name))
        s.commit()

    def _follow_merges(self, rows: list[TricountMember], local: dict) -> None:
        """A placeholder from Tricount that was linked to an account (groups/linking.py) is
        that account now: the Tricount member stays the same person, not a new one."""
        mapped = {r.user_id for r in rows}
        for r in rows:
            if r.user_id in local:
                continue
            link = self.s.scalar(
                select(AuditLog)
                .where(
                    AuditLog.action == "member.link",
                    AuditLog.entity_id == self.group_id,
                    AuditLog.diff_json["placeholder_id"].astext == str(r.user_id),
                )
                .order_by(AuditLog.at.desc())
                .limit(1)
            )
            account = uuid.UUID(link.diff_json["user_id"]) if link else None
            if account in local and account not in mapped:
                mapped.discard(r.user_id)
                r.user_id = account
                mapped.add(account)

    def _map_member(self, membership_uuid: str, user_id: uuid.UUID) -> None:
        self.s.add(
            TricountMember(group_id=self.group_id, membership_uuid=membership_uuid, user_id=user_id)
        )
        self.member_of[user_id] = membership_uuid
        self.user_of[membership_uuid] = user_id

    def _new_placeholder(self, name: str) -> uuid.UUID:
        user = User(name=name[:80] or "Someone")
        self.s.add(user)
        self.s.flush()
        record(self.s, self.actor, "user.create_placeholder", "user", user.id, diff={"name": name})
        member = GroupMember(group_id=self.group_id, user_id=user.id, placeholder_name=user.name)
        self.s.add(member)
        record(
            self.s,
            self.actor,
            "member.add",
            "group",
            self.group_id,
            self.group_id,
            {"user_id": str(user.id), "via": "tricount"},
            obj=member,
        )
        return user.id

    # ---- group name ----

    def _title(self) -> None:
        here, there, base = self.group.name, self.remote.title, self.link.title_base
        if here == there:
            self.link.title_base = here
        elif here == base:
            if there:
                before = self.group.name
                self.group.name = there[:80]
                record(
                    self.s,
                    self.actor,
                    "group.update",
                    "group",
                    self.group_id,
                    self.group_id,
                    {"name": {"from": before, "to": self.group.name}, "via": "tricount"},
                    obj=self.group,
                )
                self.link.title_base = self.group.name
        else:
            # Renamed here (or on both sides: Splitkit's name wins, no need to ask).
            self.client.update_registry(self.link.registry_id, {"title": here})
            self.link.title_base = here
        self.s.commit()

    # ---- entries ----

    def _entries(self) -> None:
        s, gid = self.s, self.group_id
        self.categories = {c.id: c for c in s.scalars(select(Category))}
        self.system_categories = {
            c.key: c.id
            for c in self.categories.values()
            if c.owner_id is None and c.scope in ("group", "all")
        }
        maps = list(s.scalars(select(TricountEntry).where(TricountEntry.group_id == gid)))
        blocked = set(
            s.scalars(
                select(TricountConflict.entry_id).where(
                    TricountConflict.group_id == gid, TricountConflict.resolved_at.is_(None)
                )
            )
        )
        expenses = {
            e.id: e
            for e in s.scalars(
                select(Expense).where(Expense.group_id == gid).options(selectinload(Expense.splits))
            )
        }
        settlements = {
            x.id: x for x in s.scalars(select(Settlement).where(Settlement.group_id == gid))
        }
        self.locals: dict[tuple[str, uuid.UUID], Any] = {
            **{("expense", k): v for k, v in expenses.items()},
            **{("settlement", k): v for k, v in settlements.items()},
        }
        remotes = {e.id: e for e in self.remote.entries}

        unsupported: dict[str, list[wire.Entry]] = {}
        remote_canon: dict[int, mapping.Canon] = {}
        for e in remotes.values():
            c = mapping.remote_canon(e)
            if isinstance(c, mapping.Unsupported):
                unsupported.setdefault(c.reason, []).append(e)
            elif not self._known(c):
                unsupported.setdefault("someone who isn't in the group", []).append(e)
            else:
                remote_canon[e.id] = c

        plan = plan_entries(
            maps=[
                MapRow(m.id, m.entity, m.entity_id, m.remote_id, m.base, m.id in blocked, m.force)
                for m in maps
            ],
            locals_={k: self._local_state(v) for k, v in self.locals.items()},
            remotes={i: RemoteState(e.uuid, remote_canon.get(i)) for i, e in remotes.items()},
            derived=lambda key, gen: mapping.remote_uuid(key[1], gen),
        )
        by_id = {m.id: m for m in maps}
        if plan.deletes_held:
            self.out.warnings.append(
                f"Tricount no longer has {plan.deletes_held} entries. They were kept here in "
                "case Tricount sent an incomplete list; delete them by hand if that's right."
            )
        refused: list[TricountError] = []
        sent = 0
        for action in plan.actions:
            row = by_id.get(action.map_id) if action.map_id else None
            try:
                self._do(action, row, remotes, remote_canon)
                s.commit()
                sent += action.kind in ("push", "push_delete")
            except StaleDataError:
                s.rollback()  # someone changed it meanwhile: the next pass looks again
            except TricountError as e:
                s.rollback()
                if e.status not in (400, 404, 409, 422):
                    raise
                refused.append(e)
                self.out.warnings.append(f"Tricount refused a change: {e.message}")
        if refused and not sent:
            # Not one change got through: more likely Tricount blocking us than bad entries.
            raise refused[-1]
        for reason, entries in unsupported.items():
            total = sum(e.amount_minor for e in entries)
            amount = format_minor(total, self.link.currency)
            self.out.warnings.append(
                f"{len(entries)} {'entry' if len(entries) == 1 else 'entries'} in Tricount "
                f"with {reason} ({amount}) can't be shown in Splitkit, so balances can differ."
            )

    def _known(self, canon: mapping.Canon) -> bool:
        people = [canon.get("payer"), canon.get("from"), canon.get("to")]
        people += [who for who, _ in canon.get("shares", [])]
        return all(p in self.user_of for p in people if p)

    # Splitkit's side, as (deleted, comparable form or None if someone isn't in the tricount).
    def _local_state(self, row: Expense | Settlement) -> "LocalState":
        m = self.member_of.get
        day = row.date.isoformat()
        if isinstance(row, Expense):
            people = [m(row.payer_id)] + [m(x.user_id) for x in row.splits]
            canon = None
            if all(people):
                category = self.categories.get(row.category_id) if row.category_id else None
                key = (
                    None
                    if category is None
                    else (category.key if category.owner_id is None else "custom")
                )
                canon = mapping.expense_canon(
                    description=row.description,
                    amount_minor=row.amount_minor,
                    day=day,
                    payer=m(row.payer_id),
                    shares=[(m(x.user_id), x.share_minor) for x in row.splits],
                    category=key,
                )
        else:
            canon = None
            if m(row.from_user) and m(row.to_user):
                canon = mapping.payment_canon(
                    amount_minor=row.amount_minor,
                    day=day,
                    frm=m(row.from_user),
                    to=m(row.to_user),
                    note=row.note,
                )
        return LocalState(row.deleted_at is not None, canon)

    # ---- doing it ----

    def _do(self, a: "Action", row: TricountEntry | None, remotes, remote_canon) -> None:
        s = self.s
        if row is None and a.kind in ("pull", "push", "agree") and a.local_key is not None:
            row = TricountEntry(
                group_id=self.group_id,
                entity=a.local_key[0],
                entity_id=a.local_key[1],
                remote_id=a.remote_id,
            )
            s.add(row)
        elif row is None and a.kind == "pull":
            entity = "expense" if remote_canon[a.remote_id]["kind"] == "expense" else "settlement"
            local = mapping.local_id(self.link.registry_id, remotes[a.remote_id])
            row = TricountEntry(
                group_id=self.group_id, entity=entity, entity_id=local, remote_id=a.remote_id
            )
            s.add(row)

        if row is not None and a.kind != "conflict":
            row.force = None
        if a.kind == "agree":
            row.base, row.remote_id = a.canon, a.remote_id if a.remote_id else row.remote_id
        elif a.kind == "forget":
            s.delete(row)
        elif a.kind == "conflict":
            s.add(
                TricountConflict(
                    group_id=self.group_id, entry_id=row.id, local=a.local, remote=a.remote
                )
            )
            self.out.conflicts += 1
        elif a.kind == "pull":
            entry = remotes[a.remote_id]
            self._pull(row, entry, remote_canon[a.remote_id])
            row.remote_id, row.base = entry.id, remote_canon[a.remote_id]
            self.out.pulled += 1
        elif a.kind == "pull_delete":
            self._set_deleted(row, True)
            row.remote_id, row.base = None, None
            row.generation += 1  # if it comes back, it is created in Tricount afresh
            self.out.pulled += 1
        elif a.kind == "push":
            local = self.locals[(row.entity, row.entity_id)]
            remote = remotes.get(row.remote_id) if row.remote_id is not None else None
            if remote is None and row.remote_id is not None:
                row.generation += 1  # deleted in Tricount: create it there afresh
            body = self._body(row, local, a.local, remote)
            if remote is None:
                row.remote_id = self.client.create_entry(self.link.registry_id, body)
            else:
                self.client.update_entry(self.link.registry_id, remote.id, body)
            row.base = a.local
            self.out.pushed += 1
        elif a.kind == "push_delete":
            try:
                self.client.delete_entry(self.link.registry_id, row.remote_id)
            except TricountError as e:
                if not e.gone:
                    raise
            row.remote_id, row.base = None, None
            row.generation += 1
            self.out.pushed += 1

    def _body(self, row: TricountEntry, local, canon: mapping.Canon, remote: wire.Entry | None):
        m = self.member_of
        common = {
            "uuid": mapping.remote_uuid(row.entity_id, row.generation),
            "amount_minor": local.amount_minor,
            "currency": self.link.currency,
            "day": local.date,
            "attachment_ids": remote.attachment_ids if remote else None,
        }
        if row.entity == "settlement":
            return wire.entry_body(
                **common,
                kind=wire.TRANSFER,
                description=local.note or "Reimbursement",
                payer_uuid=m[local.from_user],
                allocations=mapping.payment_allocations(
                    m[local.from_user], m[local.to_user], local.amount_minor
                ),
                category=None,
            )
        category = self.categories.get(local.category_id) if local.category_id else None
        key = None if category is None else (category.key if category.owner_id is None else None)
        if mapping.keep_remote_category(canon["category"], remote):
            tc_category, custom = remote.category, remote.category_custom
        elif category is not None and category.owner_id is not None:
            tc_category, custom = "OTHER", category.label
        else:
            tc_category, custom = mapping.TO_TRICOUNT.get(key, "OTHER"), None
        return wire.entry_body(
            **common,
            kind=wire.EXPENSE,
            description=local.description,
            payer_uuid=m[local.payer_id],
            allocations=mapping.expense_allocations(
                local.split_method,
                [(m[x.user_id], x.share_minor, x.input_value) for x in local.splits],
            ),
            category=tc_category,
            category_custom=custom,
        )

    def _pull(self, row: TricountEntry, entry: wire.Entry, canon: mapping.Canon) -> None:
        s, users = self.s, self.user_of
        existing = self.locals.get((row.entity, row.entity_id))
        if existing is None:
            existing = s.get(Expense if row.entity == "expense" else Settlement, row.entity_id)
        restored = existing is not None and existing.deleted_at is not None
        if row.entity == "settlement":
            x = existing or Settlement(
                id=row.entity_id,
                group_id=self.group_id,
                currency=self.group.currency,
                method="other",
                created_by=SYSTEM_USER_ID,
            )
            x.from_user, x.to_user = users[canon["from"]], users[canon["to"]]
            x.amount_minor, x.date = canon["amount"], entry.day
            x.note = canon["note"] or None
            x.deleted_at, x.acting_admin_id = None, None
            if existing is None:
                s.add(x)
                s.flush()
            action = "settlement.create" if existing is None else "settlement.update"
            if restored:
                action = "settlement.restore"
            record(
                s, self.actor, action, "settlement", x.id, self.group_id, {"via": "tricount"}, obj=x
            )
            self.locals[(row.entity, row.entity_id)] = x
            return

        split = mapping.local_split(entry)
        amounts = {a.member_uuid: a.amount_minor for a in entry.allocations}
        rows = [
            ExpenseSplit(user_id=users[who], share_minor=amounts[who], input_value=value)
            for who, value in split.inputs
        ]
        keep_category = (
            existing is not None and mapping.norm(self._key(existing)) == canon["category"]
        )
        category_id = (
            existing.category_id
            if keep_category
            else self.system_categories.get(mapping.from_tricount(entry.category))
        )
        fields = {
            "description": canon["description"],
            "amount_minor": entry.amount_minor,
            "payer_id": users[entry.payer_uuid],
            "date": entry.day,
            "category_id": category_id,
            "split_method": split.method,
        }
        if existing is None:
            e = Expense(
                id=row.entity_id,
                group_id=self.group_id,
                currency=self.group.currency,
                created_by=SYSTEM_USER_ID,
                splits=rows,
                **fields,
            )
            s.add(e)
            s.flush()
            action = "expense.create"
        else:
            e = existing
            for k, v in fields.items():
                setattr(e, k, v)
            e.deleted_at, e.acting_admin_id = None, None
            e.updated_at = datetime.now(UTC)
            expenses_repo.replace_splits(s, e, rows)
            s.flush()
            action = "expense.restore" if restored else "expense.update"
        record(
            s,
            self.actor,
            action,
            "expense",
            e.id,
            self.group_id,
            {"via": "tricount", "amount_minor": e.amount_minor},
            obj=e,
        )
        self.locals[(row.entity, row.entity_id)] = e

    def _key(self, e: Expense) -> str | None:
        c = self.categories.get(e.category_id) if e.category_id else None
        return None if c is None else (c.key if c.owner_id is None else "custom")

    def _set_deleted(self, row: TricountEntry, deleted: bool) -> None:
        x = self.locals.get((row.entity, row.entity_id))
        if x is None or (x.deleted_at is not None) == deleted:
            return
        x.deleted_at = datetime.now(UTC) if deleted else None
        x.acting_admin_id = None
        action = f"{row.entity}.{'delete' if deleted else 'restore'}"
        record(
            self.s, self.actor, action, row.entity, x.id, self.group_id, {"via": "tricount"}, obj=x
        )


# ---- the plan (pure) ----


@dataclass(frozen=True)
class MapRow:
    id: uuid.UUID
    entity: str
    entity_id: uuid.UUID
    remote_id: int | None
    base: mapping.Canon | None
    blocked: bool = False
    """An open conflict: left alone until someone resolves it."""
    force: str | None = None
    """"push" or "pull": a resolved conflict, done once whatever the base says."""


@dataclass(frozen=True)
class LocalState:
    deleted: bool
    canon: mapping.Canon | None
    """None when someone in it isn't in the tricount yet: it waits."""


@dataclass(frozen=True)
class RemoteState:
    uuid: str
    canon: mapping.Canon | None
    """None for an entry Splitkit can't hold (income, …): never synced."""


@dataclass
class Action:
    kind: str
    """agree · forget · pull · pull_delete · push · push_delete · conflict"""
    map_id: uuid.UUID | None = None
    local_key: tuple[str, uuid.UUID] | None = None
    remote_id: int | None = None
    canon: mapping.Canon | None = None
    local: mapping.Canon | None = None
    remote: mapping.Canon | None = None


@dataclass
class Plan:
    actions: list[Action]
    deletes_held: int = 0


def plan_entries(
    maps: list[MapRow],
    locals_: dict[tuple[str, uuid.UUID], LocalState],
    remotes: dict[int, RemoteState],
    derived,
) -> Plan:
    """What to do with every entry. `derived(local_key, generation)` is the Tricount id a
    Splitkit entry is created with, used to recognise our own creates after a crash."""
    actions: list[Action] = []
    used_remote: set[int] = set()
    mapped_local: set[tuple[str, uuid.UUID]] = set()

    for m in maps:
        key = (m.entity, m.entity_id)
        mapped_local.add(key)
        if m.remote_id is not None:
            used_remote.add(m.remote_id)
        if m.blocked:
            continue
        local = locals_.get(key)
        if local is not None and not local.deleted and local.canon is None:
            continue  # waits for its people to reach the tricount
        remote = remotes.get(m.remote_id) if m.remote_id is not None else None
        if remote is not None and remote.canon is None:
            continue  # turned into something Splitkit can't hold; leave it be
        lc = None if local is None or local.deleted else local.canon
        rc = None if remote is None else remote.canon
        b = m.base
        if m.force == "pull":
            b = lc  # as if only Tricount had changed
        elif m.force == "push":
            b = rc  # as if only Splitkit had changed
        if lc == rc:
            if lc is None:
                actions.append(Action("forget", m.id))
            elif b != lc:
                actions.append(Action("agree", m.id, remote_id=m.remote_id, canon=lc))
        elif lc == b:
            if rc is None:
                actions.append(Action("pull_delete", m.id))
            else:
                actions.append(Action("pull", m.id, remote_id=m.remote_id))
        elif rc == b:
            if lc is None:
                actions.append(Action("push_delete", m.id))
            else:
                actions.append(Action("push", m.id, local=lc))
        else:
            actions.append(Action("conflict", m.id, local=lc, remote=rc))

    # Held back if Tricount suddenly lost most of what it had.
    live = sum(1 for m in maps if m.remote_id is not None)
    drops = [a for a in actions if a.kind == "pull_delete"]
    held = 0
    if len(drops) >= 5 and len(drops) > live * MASS_DELETE:
        held = len(drops)
        actions = [a for a in actions if a.kind != "pull_delete"]

    # New on both sides: first our own creates (same derived id), then look-alikes.
    new_remote = {i: r for i, r in remotes.items() if i not in used_remote and r.canon is not None}
    by_uuid = {r.uuid: i for i, r in new_remote.items() if r.uuid}
    new_local = [
        (k, v)
        for k, v in sorted(locals_.items(), key=lambda kv: str(kv[0][1]))
        if k not in mapped_local and not v.deleted and v.canon is not None
    ]
    unpaired = []
    for key, local in new_local:
        mine = by_uuid.get(derived(key, 0))
        if mine is not None and mine in new_remote:
            remote = new_remote.pop(mine)
            actions.append(_paired(key, mine, local.canon, remote.canon))
        else:
            unpaired.append((key, local))
    for key, local in unpaired:
        same = _lookalike(local.canon, new_remote)
        if same is None:
            actions.append(Action("push", local_key=key, local=local.canon))
        else:
            remote = new_remote.pop(same)
            actions.append(_paired(key, same, local.canon, remote.canon))
    for remote_id in sorted(new_remote):
        actions.append(Action("pull", remote_id=remote_id))
    return Plan(actions, held)


def _paired(key, remote_id: int, local: mapping.Canon, remote: mapping.Canon) -> Action:
    # The same entry on both sides (linking a group imported from this tricount). Where they
    # differ (a category, a title), Tricount's version is taken.
    if local == remote:
        return Action("agree", local_key=key, remote_id=remote_id, canon=local)
    return Action("pull", local_key=key, remote_id=remote_id)


def _identity(c: mapping.Canon) -> tuple:
    """What makes two entries the same one: everything but the words and the category."""
    return tuple(
        (k, repr(v)) for k, v in sorted(c.items()) if k not in ("description", "category", "note")
    )


def _lookalike(local: mapping.Canon, candidates: dict[int, RemoteState]) -> int | None:
    same = [i for i, r in candidates.items() if _identity(r.canon) == _identity(local)]
    if not same:
        return None
    exact = [i for i in same if candidates[i].canon == local]
    words = [
        i
        for i in same
        if norm_name(candidates[i].canon.get("description", candidates[i].canon.get("note", "")))
        == norm_name(local.get("description", local.get("note", "")))
    ]
    return (exact or words or same)[0]
