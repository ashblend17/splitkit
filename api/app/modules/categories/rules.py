"""Learning categories from what you choose.

When you put an entry or a split under a category yourself, the merchant (or, without one, the
description) and that category become a rule, so the app suggests it next time. Only real
choices teach: a manual entry, a category changed on an edit, a split. Categories the app
guessed for bank SMS don't, and neither do the Tricount sync, imports or an admin acting as you.

The device does the matching (app/lib/core/categorise/category_guesser.dart): it compares
readable merchant names, so a rule for "ZOMATO LIMITED" also covers "Zomato" and "ZOMATO CYBS".
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.modules.auth.deps import Actor
from app.modules.categories.models import CategoryRule
from app.modules.sync import log as sync_log


def pattern_of(text: str | None) -> str:
    """Lowercase, with spaces collapsed (rule.dart rulePattern)."""
    return " ".join((text or "").lower().split())


def rule_id(user_id: uuid.UUID, income: bool, pattern: str) -> uuid.UUID:
    """The same on the device (rule.dart ruleId)."""
    kind = "income" if income else "spend"
    return uuid.uuid5(uuid.NAMESPACE_URL, f"splitkit:category-rule:{user_id}:{kind}:{pattern}")


def learn(
    session: Session,
    actor: Actor,
    text: str | None,
    category_id: uuid.UUID | None,
    *,
    income: bool = False,
) -> None:
    """Remember that the actor put `text` under `category_id`. Choosing the same category again
    still counts: the newest matching rule wins on the device."""
    if category_id is None or actor.admin_id is not None or actor.user.role == "system":
        return
    pattern = pattern_of(text)
    if not pattern:
        return
    rid = rule_id(actor.user_id, income, pattern)
    now = datetime.now(UTC)
    # One statement, so two writes learning the same rule at once don't collide on its id.
    session.execute(
        insert(CategoryRule)
        .values(
            id=rid,
            user_id=actor.user_id,
            pattern=pattern,
            income=income,
            category_id=category_id,
            updated_at=now,
        )
        .on_conflict_do_update(
            index_elements=[CategoryRule.id],
            set_={"category_id": category_id, "updated_at": now},
        )
    )
    rule = session.get(CategoryRule, rid, populate_existing=True)
    # Derived from a write that is already audited, so only the sync log hears of it.
    sync_log.track(session, actor, "category_rule.learn", rule, deleted=False)


def forget_category(session: Session, actor: Actor, category_id: uuid.UUID) -> None:
    """Drops the rules that lead to a category about to be deleted."""
    for rule in session.scalars(
        select(CategoryRule).where(CategoryRule.category_id == category_id)
    ):
        sync_log.track(session, actor, "category_rule.forget", rule, deleted=True)
        session.delete(rule)
    session.flush()  # before the category's own delete: no relationship orders them
