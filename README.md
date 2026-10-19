# Splitkit

Group expense splitting with a personal-finance area. The spec is in
[splitkit-design/HANDOFF.md](splitkit-design/HANDOFF.md).

| Path | What |
|---|---|
| `api/` | FastAPI modular monolith, `/api/v1`. One folder per module under `app/modules/` |
| `api/migrations/` | Alembic migrations (PostgreSQL 16) |
| `api/app/seed/` | Sample data from the mockups (Goa Trip, Flatmates, personal finances) |
| `app/` | Flutter client (Android, iOS, Web) |
| `shared/split_vectors.json` | Split-engine test cases shared by the Python engine and the Dart port |
| `tool/` | `gen_tokens.py` (tokens.json → Dart), `gen_api_client.sh` (OpenAPI → Dart client), `capture_api_fixtures.py` |
| `splitkit-design/` | Design handoff: mockups, tokens |

Checking the data and recovering from problems (server, devices, backups): [validation.md](validation.md).
Running it on a server: [deploy.md](deploy.md).

## Run everything

```sh
cp .env.example .env
docker compose up -d --build          # db :5433, api :8000, web :8080
docker compose exec api python -m app.seed --reset
```

- Web app: http://localhost:8080 (log in as a seeded user; the component gallery is at `/gallery`)
- API docs: http://localhost:8000/api/v1/docs (OpenAPI JSON at `/api/v1/openapi.json`)
- Seeded logins: any seeded email with password `dev-password`, e.g. `admin@example.com` (admin)

The API container runs `alembic upgrade head` on start. Seeding never runs automatically.
The system categories and default dashboards are reference data, added by migration 0009 to
every database (the seed has the same rows; `tests/api/test_reference_data.py` keeps them equal).

## Building

`tool/build.sh` builds any part, or all of it, in one go (`tool/build.sh --help` lists every
option):

```sh
tool/build.sh apk --api-origin https://splitkit.example.com     # Android APK to install
tool/build.sh aab --api-origin https://splitkit.example.com     # App Bundle for Google Play
tool/build.sh web                                               # static web bundle
tool/build.sh images                                            # api, tricount and web images
tool/build.sh ios --api-origin https://…                        # on a Mac
tool/build.sh all --api-origin https://splitkit.example.com --check
```

- Files land in `dist/` (gitignored) as `splitkit-<version>-<build>-<commit>-<mode>.<ext>`, with
  `dist/SHA256SUMS`. A build with uncommitted changes in `app/` or `api/` is marked `-dirty`.
- The build number is the number of commits, so every build is newer than the one before
  (Android won't install an "update" with a lower one). `--build-name` / `--build-number`
  override it.
- Images are tagged `:latest` (what `docker compose up -d --no-build` runs) and
  `:<version>-<build>-<commit>`. The image `:latest` pointed at before keeps a tag of its own,
  so going back is `docker tag splitkit-api:<old tag> splitkit-api:latest` (and the same for
  `tricount` and `web`). `--push <user>/<repo>` also pushes them as the `split-*` tags
  `docker-compose.prod.yml` pulls, plus one tag per version.
- Phone builds need `--api-origin` (or `--dev-tools`, to type the server on the phone). `--check`
  runs analyze and the tests first.

## Deploy

The server (EC2) pulls images instead of building them: `tool/push_images.sh <user>/<repo>`
pushes them, and the server runs `docker-compose.prod.yml`. Setting up a server, shipping a
version, passwords, backups and troubleshooting: [deploy.md](deploy.md).

## API development

```sh
cd api
uv sync
docker compose up -d db                 # from the repo root
uv run alembic upgrade head
uv run python -m app.seed --reset
uv run uvicorn app.main:app --reload
uv run pytest                           # API tests use the compose db (a separate splitkit_test database)
uv run ruff check . && uv run ruff format --check .
```

After changing any route or schema, regenerate the spec the Dart client is built from:
`uv run python -m app.openapi` (a test fails if `api/openapi.json` is stale).

New migration: edit models, then `uv run alembic revision --autogenerate -m "..."`, review the
file, and confirm with `uv run alembic check`.

## API conventions

- JSON under `/api/v1`, `Authorization: Bearer <token>` from `POST /auth/login` or `/auth/register`.
  Tokens last 7 days; `POST /auth/refresh` swaps a working one for a fresh one (the app does
  this on every online launch). View-as tokens can't be refreshed.
- Errors always look like `{"error": {"code": "split_invalid", "message": "₹100 still needs to be allocated", ...}}`.
  `message` is human copy the app can show as-is. Request validation errors are 422
  `invalid_input` with the first problem as `message` ("Name can't be empty") and every problem
  in `fields`.
- Text fields are trimmed, and blank ones are refused. Amounts go up to ₹9,99,99,999.99
  (`MAX_AMOUNT_MINOR`), dates from 2000 to a year ahead, the same limits as the app's inputs.
- Balances are per group. `GET /groups/{id}/balances` returns `suggested`, the fewest payments
  that would settle the whole group, and `people`, the one-to-one balances ("You owe Rahul
  ₹500"). Home adds up, per friend, the payments between you in each group's `suggested`
  (`planned()` in `balances/engine.py`), so it says what the groups' own Settle up says. An
  expense's shares follow the plan too: a share is `settled` (feed) and its split `status` is
  `settled` once its person pays nobody in that group's `suggested`.
- Placeholder members (people with no account, e.g. from a Tricount import) are linked with
  `POST /groups/{id}/members/{user_id}/link {email}` (`groups/linking.py`). If that email has an
  account, the placeholder's membership, expenses, shares and payments in all its groups move to
  it; where both were in one split the shares add up and the split becomes exact, and payments
  between the two are deleted. Otherwise the email is saved as the member's `invite_email`, and
  signing up with it turns the placeholder into the new account. Balances never move. The
  placeholder is kept with its memberships ended; the account's membership says `placeholder_name`.
- Settling with a friend across groups (`POST /friends/{id}/settle-up`) records one settlement
  per group, each the payment that group's `suggested` has between you, so every group's own
  balance stays right. With no amount every shared group's payment between you is made; a part
  payment pays down the oldest group first.
- `GET /feed` lists expenses and payments newest first, from the viewer's point of view
  (`my_net_minor`); `?deleted=true` lists deleted items for restoring. The desktop filters map to
  `group_id`, `category` (key), `start`/`end`, `unsettled` (by the group's fewest payments: you
  still pay someone there and have a share, or someone still pays you and you paid) and
  `q` (description or a person's name). `category` and `unsettled` leave payments out.
- Personal finance (`/personal/...`) is private to its owner: accounts, entries with filters and
  totals, plus a monthly summary that includes your share of group spending.
  - Accounts (`GET`/`POST /personal/accounts`, `GET`/`PUT`/`DELETE /personal/accounts/{id}`,
    `POST …/restore`) are cash, bank, credit_card, loan, investment or other_asset, in your
    currency, with an `opening_balance_minor`. The server never computes a balance: the app
    derives it from the opening balance and the entries in the account (`account_id`). A closed
    account (`status: closed`) takes no new entries; one with entries can't be deleted (409
    `account_in_use`). An account's `sms_label` ("HDFC ··4821") is unique per person, deleted
    accounts included. Making an account, labelling it or reopening it moves in your entries
    with that label and no account yet.
  - An account can be linked to another of yours (`linked_account_id`): the same account under
    a second label ("HDFC ··787778" and "HDFC ··7778"), or a debit card on a bank account.
    Nothing moves: the app counts its entries in the other account's balance, as that
    account's type, and leaves its own opening out. The other account must be open, in the same
    currency and not linked itself; neither can be an investment account, nor can one a goal
    follows or one others are linked to be linked. An account others are linked to can't be
    deleted, no entry goes through a link to a closed account, a goal can't follow a linked
    account, and one restored after its account was deleted comes back unlinked. Its entries
    come with the other account's in `GET /personal/transactions?account_id=`.
  - `account_number` is an account's (or card's) full number, 4–20 digits (spaces and dashes are
    dropped). The app puts a bank SMS label whose digits end it in that account. An account a
    live rule filters incomes on can't be deleted either (`rule_points_here`).
  - Entry types: income, expense, refund, investment_contribution and investment_withdrawal
    each imply their `direction` (in or out); transfer and adjustment say theirs. A transfer is
    two legs, one out and one in, of the same amount between two of your accounts, sharing a
    `transfer_group_id`. Both legs are made or changed in one `POST /personal/batch`, and
    deleting or restoring a leg takes the other with it (a deferred trigger backs this up). An
    adjustment corrects an account's balance. A refund may name the spend it's for
    (`refund_of_id`: one of yours, at most its amount). Transfers and adjustments have no
    category and no Split link.
  - Goals (`/personal/goals`: list, create, get, PUT, DELETE, `…/restore`) have a target, an
    optional target date, a priority and a status (active, paused, completed, archived). Their
    `tracking_mode` says where progress comes from: `contribution` (the goal's contributions),
    `linked_balance` (the balance of `linked_account_id`, an account of yours no other goal
    follows) or `manual` (`manual_progress_minor`, typed in). Each mode's field is required in
    that mode and empty in the others; switching keeps old contributions. The server never
    computes progress, what's left, the monthly amount needed or whether a goal is behind: the
    app does. A followed account can't be deleted.
  - Contributions (`/personal/goal-contributions`, `?goal_id=` to filter) put money towards a
    `contribution` goal that isn't archived, optionally with the entry that moved it
    (`transaction_id`: yours, live, at least the amount). An entry counts towards one goal at
    most, and never both as a contribution and through an account a goal follows (either leg
    of a transfer; 422 `counted_by_balance`, or `counted_by_contribution` when the goal is the
    change). Deleting an entry or a goal deletes its contributions, and restoring it brings
    back the ones that went with it.
  - Allocation rules (`/personal/allocation-rules`) set aside a percentage (`percent_bp`, basis
    points; over 100% is allowed, the app warns and never rescales) or a fixed amount of each
    income, optionally only incomes in a category or into an account, for a `contribution`
    goal or an open account. While a live rule points at a goal or account, it can't be
    deleted, archived, switched to another mode or closed (409 `rule_points_here`).
  - Allocation plans (`/personal/allocation-plans`, filter by `source_transaction_id`,
    `rule_id`, `goal_id`, `account_id`) are what a rule set aside from one income: intentions,
    never money. The app makes them with the income, with id
    `uuid5(plan namespace, "<income>|<rule>")` (`ledger_rules.plan_id`, pinned in
    `shared/ledger_vectors.json`), snapshots the rule's kind and value, and recomputes them
    when the income changes; the server doesn't redo the maths. One plan per income and rule,
    ever (409 `plan_exists`). Deleting an income cancels its plans and restoring it brings them
    back; an income with plans can't become another type until they're deleted; deleting a
    rule leaves its plans. Planned, partial, fulfilled and cancelled are worked out on the
    device.
  - Holdings (`/personal/holdings`, `?account_id=`) are what an investment account of yours
    holds: a fund, shares, a deposit, gold, with a quantity (a decimal string), an optional
    cost basis and the latest value you typed (`market_value_minor`, `valuation_at`; only the
    latest is kept). Gains and whether a value is stale (over 30 days) are worked out on the
    device. An investment or a withdrawal entry can name the holding it bought into or sold
    from (`holding_id`). A holding named by a live entry can't be deleted (409
    `holding_in_use`), nor can an investment account with holdings, or be made another type.
  - Reminders are worked out on each device. Only your decisions sync:
    `/personal/reminder-states` keeps one per dedup key (`type:entity:window`), dismissed,
    snoozed until a time, or done. `POST` makes it (201) or replaces it (200); its id is
    `uuid5(reminder namespace, "<user>|<key>")` (`ledger_rules.reminder_state_id`, pinned in
    `shared/ledger_vectors.json`), so every device writes the same row. Pending and shown stay
    on the device. `/personal/reminder-schedules` are monthly SIP reminders (day 1–28, an
    optional amount) for a goal or a holding; they never record an entry, and they're deleted
    and restored with their goal or holding. The app doesn't use either yet: reminders on the
    device were cut from the finance revamp (ISS-104).
  - `POST /personal/batch` applies up to 100 creates, updates and deletes (not of accounts) of
    accounts, entries, goals, contributions, allocation rules and plans, holdings, reminder
    decisions and schedules, in order, all or none. An item can use what an earlier one made,
    so a transfer and its contribution, or an income and its plans, go in one request. A
    refusal says which `item` (counting from 0).
  - An entry can say how it was paid (`channel`: upi, card, bank, atm, cash, other), who was paid
    (`merchant`) and the `account` ("HDFC ··4821"). Entries the app read from a bank SMS on the
    phone have `source: sms`, the bank's `reference`, the `balance_minor` it reported, `sms_at`,
    and `reviewed: false` until looked at. The message itself never leaves the phone.
  - An entry can be linked to the group expense it was split into (`expense_id`, one you paid)
    or the payment it was (`settlement_id`). While that expense or payment is live in a group
    you're in, the entry is listed with `counted: false` and left out of every personal total
    and personal analytics: your share counts as group spending, and a payment isn't spending.
  - On PUT, `channel`, `merchant`, `account`, `account_id`, the links (also
    `transfer_group_id` and `refund_of_id`) and `reviewed` keep their value when the body leaves
    them out. `source`, `reference`, `balance_minor` and `sms_at` are set on create only. A body
    without the `account_id` key (an older app) goes in your open account whose `sms_label` is
    its `account`, if there is one.
  - Totals (`spent_minor` in the list and the summary) are expenses minus refunds, with
    `refunds_minor` beside them; they can be negative. Transfers, adjustments and investments
    are never income or spending. A refund of a split spend isn't counted, like the spend.
  - `GET /personal/transactions` also filters by `type`, `account` (label), `account_id`,
    `channel`, `source` and `reviewed`. `GET /personal/accounts/reported` lists the account
    labels with the latest balance their bank reported (kept for older builds, like
    `/personal/summary`: the app now works both out itself).
  - Personal's default dashboard also has By account, By payment mode and Top merchants
    (`personal_by_account`, `personal_by_channel` and `personal_top_merchants`, migration 0011).
    In the app, Transactions filter by account and by how an entry was paid
    (`Features.breakdownFilters`); what the app works out is in
    [Personal finance on the device](#personal-finance-on-the-device).
- Analytics is config-driven: `GET /analytics/personal` and `GET /analytics/groups/{id}` loop over
  `analytics_configuration` rows (yours if you saved a layout, else the defaults). Each row's
  `source` maps to one function in `app/modules/analytics/sources.py`; each `type` maps to one
  renderer in `app/lib/features/analytics/cards.dart`. `PUT /analytics/layout/{scope}` saves
  your own order; `DELETE` goes back to the defaults.
  - Personal cards count what the summary counts: expenses less refunds (off the refund's own
    category), in your currency, without the entries a group covers. Transfers, investments and
    adjustments never count. With `group_share` (the default; the app sends what its cash flow
    does, `groupShareInCashFlow`), your share of group expenses is spending too, in each
    expense's category: in the trend, categories, daily average, needs and wants and savings
    rate. By account, By payment mode and Top merchants stay your own entries, and Personal vs
    group shows the two side by side. By account goes by the entry's account name, else its
    label. A bar or row never goes below zero; the trend's headline shows the real total.
  - Savings rate (`personal_savings_rate`: income less spending, as a percent rounded half away
    from zero, "—" without income) and Needs and wants (`personal_need_want`, by category `kind`,
    with "Not sorted" when there is some) are default cards from migration 0018. Run
    `python -m app.recover reset-stream global` when it deploys.
  - Personal Insights still come from this endpoint: moving them onto the device was cut from
    the finance revamp. So they leave out the group share that Overview's cash flow counts
    (ISS-105).
- Deletes are soft: `DELETE /expenses/{id}` then `POST /expenses/{id}/restore` (same for settlements).
- Every write is recorded in `audit_logs`, and group writes in `activity_events`, with
  `acting_admin_id` ready for admin impersonation. Every write also lands in the sync change log
  (next section).

## Admin

- `/admin/*` needs an admin signed in as themselves (403 `not_admin` otherwise): `GET /admin/dashboard`,
  `GET /admin/users` (`q`, `role`, paging), `GET /admin/audit` (filters `actor_id`, `target_user_id`,
  `entity`, `admin_only`, `start`/`end`; newest first) and `GET /admin/sessions`.
- View as: `POST /admin/sessions {target_user_id, mode}` (read-only by default) returns a token for
  the target that carries the admin and session ids. `get_actor` checks the session row on every
  request, so `PATCH /admin/sessions/{id} {mode}` and `POST /admin/sessions/{id}/end` apply at once
  (an ended or expired session's token gets 401 `admin_session_ended`). Admins and placeholders
  can't be viewed as; starting a session ends the admin's previous one.
- Read-only is enforced on the server: `get_actor` refuses every write route (403 `read_only`),
  and `require_write()` in the services and in `record()` backs it up. Edit-mode writes store
  `acting_admin_id` and show `by_admin` in the feed. Session events go to `audit_logs` only.

## Sync (offline clients)

Writes go through `record()` (`app/core/events.py`), which also queues the full state of what
changed for the sync log (`app/modules/sync/log.py`). At commit, each entry gets the next seq on
its stream, in the same transaction as the write.

- Streams: `group:<id>` (group, members with names, expenses with splits, settlements),
  `user:<id>` (profile, personal entries, accounts, goals, contributions, allocation rules and
  plans, holdings, reminder decisions and schedules, own categories, learned category rules,
  layouts, memberships), `global` (system categories, default layouts). Seqs are gap-free per
  stream.
- `POST /sync {"cursors": {"group:…": 41, …}}` returns, for every stream you can see, the changes
  after your cursor (paged by `limit`, with `has_more`). `snapshot_required` means: load
  `GET /sync/snapshot/{stream}` and store its `head_seq`. `gone` means: delete your copy.
- Entries are `upsert` (replace your copy with `data`) or `delete` (tombstone). Snapshot entities
  and log entries have the same shape.
- Edits and deletes may send `version` (body field, or `?version=` on delete and restore). A stale
  one gets 409 `version_conflict`. Creates may send their own `id`, so a retry returns the row it
  already made.
- Rows written outside `record()` (the seed, migrations) have no log entries. Clients get them
  from snapshots. Migration 0013 made accounts from entry labels this way, and 0018 added two
  Insights cards to `global`: after running them, `python -m app.recover reset-stream` every
  user stream and `global`, so devices that loaded a snapshot before them reload
  ([Deploying the finance revamp](#deploying-the-finance-revamp)).
- Group entries carry `last_activity_at`; clients move it forward with the `at` of later
  group-stream changes (except `user.*`, which only re-sends member names). Expense entries embed
  their category with `scope` and `owner_id`.

### On the device

The app keeps every stream it can see in a local database (`app/lib/core/local/`, sembast: a
file on Android/iOS, IndexedDB on web; one database per user) and reads every screen from it.
Its schema is version 2 (`LocalStore.schemaVersion`): a copy from an older build is reloaded
from snapshots, so it gets what migration 0013 backfilled.

- `SyncEngine` runs on sign-in, every 45 s while the app is open, on resume and after every write
  (`refreshLedger`). A batch and its cursor are stored in one transaction. The router opens the
  store and starts the sync the moment the session has a user (`runLocalDataWhileSignedIn`), not
  when a screen first asks, which in a browser tab that isn't showing waits for a frame.
- `Ledger` rebuilds each API answer (groups, balances, feed, expense detail, settle-up plan,
  personal list and summary, accounts, goals, contributions, allocation rules and plans,
  categories) from the entities, following the server code line by line; `balance_engine.dart`
  ports the balance engine and settle-up planner (both pass `shared/balance_vectors.json`, like
  the split engine). The finance numbers the server never computes come from the finance
  engine ([Personal finance on the device](#personal-finance-on-the-device)). Analytics,
  layouts and expense history still come from the network. A `Ledger` never changes (the store
  builds a new one on every change), so what its views share is worked out once, when first
  asked for: personal entries
  indexed and sorted (`personal_index.dart`), each group's flows, the feed's order and the
  category-suggestion lookups. `test/perf/` times the views on a heavy synthetic dataset, and
  `integration_test/perf_test.dart` times a cold start, scrolling and an SMS read on a phone
  ([validation.md](validation.md#speed)).
- The store hands out a new `Ledger` once per write (once for writes made together) and once per
  sync, however many streams it brings; sending and confirming writes only changes the outbox,
  which has its own stream. Each change counts against the parts of the data it touches
  (`core/local/revisions.dart`: personal, groups, categories, profile, layouts), and providers
  built with `localOn` (`core/data/providers.dart`) are worked out again only when a part they
  read changes, so a bank SMS import doesn't redo Home.
- Offline, screens keep showing the device copy with a "You're offline" line, and the app opens
  with the saved sign-in. A 401 signs you out but keeps the data; logging out deletes it.
- Writes work offline (`core/local/writes.dart`): expenses, payments (including settle-up with a
  friend, planned on the device and queued as one payment per group), personal entries, new
  groups and archiving. Each is queued in the outbox with its client id or base `version` and the
  full state it leaves behind, which every screen shows at once. The next sync sends the queue in
  order before pulling. A queued write stops being shown once the server's copy arrives.
  - Personal's other writes work offline too: accounts, transfers, refunds, Reconcile, goals
    and contributions, allocation rules and plans, holdings (`writes_finance.dart`,
    `writes_goals.dart`, `writes_plans.dart`, `writes_holdings.dart`, parts of `writes.dart`).
    What has to change together (a transfer's two legs, an income and its plans) goes as one
    `POST /personal/batch`. A `_Draft` checks each item as the server would and lays the
    server's cascades over the device copy, so a write made offline isn't refused later.
  Refusals (409 conflicts, checks only the server can make) move to "Needs your attention" in the
  shell: Keep mine re-sends on top of the other change, Keep theirs / Discard drops it. Adding
  members, profile, categories and analytics layouts still need a connection.
- Checks: `app/test/core/local_parity_test.dart` compares every local answer with the API's for
  two seeded users (`app/test/fixtures/sync/`; holdings aren't in it yet), and the finance
  engine's cash flow with the API's summary. `app/test/live/` does the same against a
  running server after real writes (see the file for how to point it at a throwaway database).

## App development

```sh
cd app
flutter test                               # widgets, split engine (shared vectors), API contract
flutter run -d chrome --dart-define=API_ORIGIN=http://localhost:8000
```

- Theme values come from `splitkit-design/tokens.json`. After editing it, run
  `python3 tool/gen_tokens.py` (a test fails if `tokens.g.dart` is stale).
- Light and dark: `tokens.json` has `color` and `colorDark` (the same names), generated into
  `skLightColors` and `skDarkColors`. `SkColors.x` reads the set in use, which `SkThemedApp`
  (`core/theme/theme_mode.dart`) picks from Profile → Appearance (as the device, light or dark,
  saved on the device) and the phone's own setting; on a change every widget is rebuilt.
  - So colours and text styles are read when building: never keep one in a `const` or a
    `static final` (write a getter), and give a colour parameter no default (take `Color?`).
  - Text and icons on a solid ink, brand or accent fill use `SkColors.onFill`, not white.
  - `SkPalette` (mockup colours outside the tokens) and the avatar pairs have both values too.
- Design-system widgets live in `app/lib/design_system/`; `/gallery` shows them all.
- Layout follows `SkLayout` (`app/lib/core/layout/layout.dart`): tab bar under 600px, NavRail up
  to 1279px, WebSidebar from 1280px. Only phones show the floating add button. Home and group
  detail have their own tablet and desktop layouts; other pages stay phone-width and centred.
- The app has two modes, **Split** and **Personal** (`features/shell/app_mode.dart`), switched
  with `ModeSwitch` at the top of every tab on a phone and in the rail and sidebar. Each has its
  own tabs (Split: Home, Groups; Personal: Overview `/personal`, Transactions
  `/personal/transactions`, Goals `/personal/goals` while `Features.goals` is on, Insights
  `/personal/insights`), add button ("Add split" in brand, "Add entry" in the personal accent)
  and accent. Overview's accounts card opens Accounts (`/personal/accounts`). Profile and Admin
  belong to both; the app reopens in the mode it was left in. The old `/personal/history`,
  `/profile/history` and `/profile/analytics` redirect to Personal's tabs.
- A group is settled by its fewest payments (`suggested`, read through
  `features/groups/settle_plan.dart`): Settle up, the group summary (You pay, You get, Net), the
  desktop side panel and the Balances tab follow it, and so do Home's friend totals and
  settling with a friend across groups. The one-to-one balances (`people`) are a small table at
  the bottom of the Balances tab; tapping a row records a payment for just that pair.
- A group's tabs (Expenses, Balances, Analytics, Members) each have an address
  (`/groups/<id>`, `/groups/<id>/balances`, `/analytics`, `/members`) but are one page
  (`GroupDetailPage`, one page key per group in the router), so the header, tabs and width stay
  put and only the content under the tabs changes.
- Tab pages share one frame (`tabPagePadding`, `TabPageWidth` and `CardColumns` in
  `features/common/common.dart`): the 390px designs in a centred 640px column under 1280px, and
  from 1280px HomeDesktop's 32px gutters and the full width, with cards in columns. Pages opened
  from a tab (forms, Deleted items, Categories, SMS, import) stay a centred column.
- Every link between the two modes is a flag in `app/lib/core/integrations.dart`
  (`integrationsProvider`, overridden in tests), so a link can be tuned or cut in one place.
  The server never reads them. `Features` there tunes each mode on its own.
- Categories are suggested on the device (`lib/core/categorise/`): what you chose before for
  the same merchant or words, then keywords (`category_keywords.dart`), then a typo of one
  (`fuzzywuzzy`). The personal sheet and Add split follow what you type until you pick one.
  - What you chose is learned as a rule (`category_rules` on your user stream): a manual entry,
    a category changed on an edit, or a split teaches its merchant (else its description). The
    API writes the rule with the change (`api/app/modules/categories/rules.py`), and the device
    lays the same rule, with the same id, over its data at once (`LocalWrites._learn`).
    Categories the app guessed for SMS teach nothing, and neither do imports, the Tricount sync
    or an admin acting as you.
  - Rules match by `merchantKey()` (`category_rules.dart`), so "ZOMATO LIMITED", "ZOMATO CYBS"
    and "zomato.payu@axisbank" are one merchant. The newest matching rule wins; income and
    spending are learned apart. A category not offered in the other mode gives its namesake there.
- Bank SMS are read by `lib/core/sms/sms_parser.dart`, which is pure Dart and runs on the phone
  only. It returns a payment (kind, direction, amount, account label, mode, merchant,
  reference, balance, date) or why it skipped the message: OTPs, things still to come,
  failures, statements, foreign currency, promotional and non-bank senders, and refunds, card
  bills or own transfers it couldn't read. The kind (`SmsKind`) is a payment, a refund, a card
  bill or an own transfer. `test/fixtures/sms/corpus.json` is the bank formats it's checked
  against. `sms_ids.dart` gives each SMS a fixed entry id.
- A personal entry can become something in Split (`features/personal/txn_actions.dart`):
  - **Split it:** `/expenses/new?from_txn=<id>` opens Add split filled in from the entry, paid
    by you. Saving queues the expense and the entry's link together
    (`LocalWrites.splitPersonal`, one `enqueueAll`).
  - **Already split:** links the entry to a split you paid with the same amount, dated within
    `linkWindowDays` (`Ledger.linkCandidates`).
  - **Paid a friend / From a friend:** a settle-up with someone you owe (or who owes you),
    started from the entry and linked to its first payment.
  - Overview's **Just in** (`just_in.dart`) lists SMS entries not looked at yet, with Split
    it, Looks right and Not mine (a delete; the SMS's fixed id keeps it deleted), and the
    transfers the finance engine suggests.
  - A linked entry says what it became and can be unlinked. The split shows its owner, and only
    its owner, which account paid.
- The API client in `app/packages/splitkit_api` is generated: after API changes run
  `(cd api && uv run python -m app.openapi) && tool/gen_api_client.sh` (needs Docker).
  Use `apiDate()` for date fields: the generated client converts dates to UTC.
- Admin pages (`features/admin/`) read the API directly, not the synced data. Every "View as"
  button calls `viewAsLauncherProvider` (`features/admin/view_as.dart`); the view-as switch,
  banner and frame (screen 18) plug in there.
- Screen tests run against real API responses in `app/test/fixtures/api`, and screens read from a
  local store synced from the snapshots in `app/test/fixtures/sync`. Refresh both against a
  throwaway database, never the compose one (seeding wipes it), as
  `tool/capture_api_fixtures.py`'s docstring says:

  ```sh
  docker compose exec db createdb -U splitkit splitkit_fixtures
  cd api && export DATABASE_URL=postgresql+psycopg://splitkit:splitkit@localhost:5433/splitkit_fixtures
  uv run alembic upgrade head && uv run python -m app.seed --reset
  uv run uvicorn app.main:app --port 8001          # in another terminal, with the same DATABASE_URL
  API=http://localhost:8001 python3 ../tool/capture_api_fixtures.py
  docker compose exec db dropdb -U splitkit splitkit_fixtures   # after stopping uvicorn
  ```

  Revert the admin fixtures if only their random audit ids changed.
- Tests run on 25 Sep 2026, the day the fixtures were captured: screens read the time from
  `appClock` (`lib/core/clock.dart`), which `test/flutter_test_config.dart` pins.
- On a machine with little free memory, run `flutter test --concurrency=1`.

### An Android beta next to the normal app

To try a build on a phone without updating the installed app, give it another application id:

```sh
tool/build.sh apk --beta --api-origin http://<laptop's LAN IP>:8000 --dev-tools
```

(`--beta` sets `SPLITKIT_APP_ID_SUFFIX=.beta` for Gradle; `flutter build apk` with that variable
does the same.)

It installs as "Splitkit Beta" (`com.splitkit.splitkit.beta`), with its own data and login, and
it may use plain HTTP, so it can talk to the compose stack on a laptop on the same Wi-Fi
(`DEV_TOOLS` keeps the login screen's Server link, should the laptop's address change). Without
`SPLITKIT_APP_ID_SUFFIX` the build is the normal app, which refuses plain HTTP. Both apps read
bank SMS, so turn notifications off in one of them.

### iOS

iOS builds need macOS and Xcode. On a Mac: `cd app && flutter build ios --release
--dart-define=API_ORIGIN=https://…` (signing needs a team set in Xcode), or `flutter run` on a simulator.

Without a Mac, `.github/workflows/ios.yml` builds on a GitHub macOS runner. It runs on pushes that
touch `app/`, or by hand from Actions → iOS build (inputs: `api_origin`, `dev_tools`). It uploads
nothing signed:

- `splitkit-simulator.zip`: a debug `Runner.app` for the iOS Simulator (`xcrun simctl install booted Runner.app`).
- `splitkit-unsigned.ipa`: a release build. Re-sign it with your Apple ID (Sideloadly, AltStore) to put it on a phone.

With no `api_origin`, choose the server under "Server" on the login screen. Use an HTTPS server:
`Info.plist` allows plain `http://` only for local-network hosts (`NSAllowsLocalNetworking`), and
that hasn't been tried on a device yet.

## Money and splits

- Amounts are integer minor units (paise) plus a currency code. `app/core/money.py` formats and
  parses them (`₹1,50,000`, `₹1,533.33`).
- The split engine (`app/modules/splits/engine/`) is pure. Methods are plugins in `registry`;
  each has `validate(total_minor, inputs)` and `allocate(total_minor, inputs)`. Rounding uses
  largest remainder, with ties going to the earlier input, so shares always add up to the total.
- A deferred database trigger rejects any expense whose splits don't add up to its amount.

## Personal finance on the device

The server only stores and checks Personal's records. Every number derived from them is worked
out on the device by a pure-Dart engine, `FinanceEngine` (`app/lib/core/finance/finance.dart`),
and screens read typed answers from its providers (`finance_providers.dart`,
`goal_providers.dart`, `allocation_providers.dart`, `holding_providers.dart`), never doing the
maths themselves. A new `Ledger` takes the engine over while personal data and the profile are
unchanged, so a groups-only sync doesn't rebuild it. "Today" is one provider (`today.dart`)
that `TodayTicker` moves at midnight and on resume.

- **Accounts and balances** (`balances.dart`, Accounts page). A balance is the opening balance
  plus every live entry on the account, whatever its type (for a card or loan, what you owe).
  It's never stored. Entries add up in ledger order: by day, a correction first in its day,
  then the SMS time (else `created_at`), then id. The bank's latest reported balance is a
  checkpoint: Accounts shows "Bank said ₹X on 21 Sep · ₹Y off", and **Reconcile** records a
  balance correction (an `adjustment`) dated that day, which closes the gap there. Without a
  checkpoint the correction is against today's balance. Cards and loans have none (their SMS
  report a limit), and nor do accounts valued by holdings. Closing an account can zero it first
  with a correction. An account made from bank SMS starts reconciled: its opening makes the
  balance after the first reported one equal it (0013's backfill rule,
  `shared/ledger_vectors.json`). A balance read from SMS that nothing ever checked (no reported
  balance, no correction: every card, and banks whose alerts give none) says so on Accounts,
  with Set owed or Set balance.
- **Linked accounts** (`balances.dart`, `account_links.dart`). An account linked to another
  isn't listed on its own: its entries, and the balances its bank reported, count in that one's,
  as that one's type; its own opening doesn't (an account read from a debit card's SMS opens at
  the bank's balance). The account sheet links and unlinks them, and takes a full account
  number. Accounts offers to link accounts that look like one (the same bank with digits one
  of which ends the other, a full number another's label ends, the same card labelled two
  ways, a debit card of a bank you have one account with) and to make a credit card of a bank
  account a credit card's bills went into; "Not the same" and "It's a bank account" are
  remembered on the device (`finance.not_same`, `finance.not_card`).
- **Transfers** (`transfers.dart`): two legs, out and in, made, changed and deleted together.
  An entry can become one ("This was a transfer"), two entries can be paired, and a transfer
  can be unpaired (legs from SMS become spends and incomes again; legs the app made are
  deleted). Just in suggests a spend and an income from bank SMS of the same amount, on two of
  your accounts, at most `transferSuggestionMinutes` (30) apart; each entry joins one pair,
  closest first, and "Not a transfer" is remembered on the device (`finance.not_transfer`).
- **Refunds** (`refunds.dart`): money back for a spend, in its category and, by default, its
  account. It comes off spending in the month it's dated. It finds its spend by the bank
  reference, else the same merchant up to `refundMatchDays` (60) before, with enough left to
  refund; of several, the same account first, then the exact amount, then the newest.
- **Cash flow** (`cash_flow.dart`, Overview, the month picked). Income is counted income.
  Spending is expenses less refunds, plus your share of the month's group expenses while
  `groupShareInCashFlow` (and `groupShareInPersonal`) are on. Entries a group already covers are
  left out, as in the summary. Left over = income − spending; Saved = left over ÷ income, a whole
  percent rounded half away from zero, "—" with no income. Investments, and transfers into or
  out of an investment account, show apart as invested and withdrawn, never as spending. Other
  transfers and corrections aren't in it. Months follow each entry's local date (the profile
  has no timezone).
- **Net worth** (`net_worth.dart`, Accounts and Overview): asset accounts less what you owe on
  cards and loans, closed accounts included, deleted ones not. What friends owe you in Split,
  net, by the groups' fewest payments, is a line of its own (`splitInNetWorth`). Accounts in an
  older currency are left out.
- **Goals** (`goals.dart`, the Goals tab, goal detail, Overview's top 3). Progress comes from
  the goal's contributions, the value of the account it follows, or a figure typed in. Left =
  target − progress, never below 0. Months left counts calendar months to the target's, both
  included; needed a month = left ÷ months, rounded up. The % is rounded down and never reads
  100 before the goal is reached; the bar stops at full, the figure doesn't ("112% · ₹7,000
  over"). States, the first that fits: archived, completed, paused, reached, overdue (date
  passed), behind, on track, no date. Behind means, once the goal is `behindGraceDays` (7) old,
  below a straight line from the day it was made to its date. A goal with an expected monthly
  return also shows what's needed with returns, marked as an estimate.
- **Allocation rules** (`allocation.dart`; rules screens: see the last commit). A rule plans a
  percentage or a fixed amount of each income for a contribution goal or an open account. An
  income gets one plan per rule that's active, whose filters (category, account) take it, whose
  destination takes money, and that existed when the income was recorded, so old bank SMS get
  none. The amount rounds half away from zero, and the plan snapshots the rule. Editing an
  income recomputes its plans with each plan's own snapshot; deleting it cancels them. A plan is
  planned, partial or fulfilled as contributions to its goal (or transfers into its account)
  fill plans oldest first. Rules over 100% of an income (the worst case of category and
  account) get a warning and are never changed. **Plans are intentions: they never move money,
  nor count in a goal's progress or a balance.** The Goals tab's Rules card opens the rules
  (`/personal/goals/rules`); Overview shows planned against actual for the month, goal detail
  what's planned but not yet saved, and the entry sheet an income's plans.
- **Holdings** (`holdings.dart`, Accounts). An investment account with holdings is worth their
  values as last typed, plus what was put in (less taken out) since, at cost: investments and
  withdrawals naming a holding after its valuation, and the account's own entries after its
  latest one. Without holdings it's worth its balance. Gain = value − cost, only with a cost. A
  value over `staleValuationDays` (30) old is stale ("Update value"). Only the latest is kept.
- **Flags** (`core/integrations.dart`): `Integrations.groupShareInCashFlow` and
  `splitInNetWorth` join the Split links; `Features` has `accounts`, `transfers`, `refunds`,
  `investmentTypes`, `transferSuggestions`, `atmToCash`, `pairCardBills`, `goals`,
  `allocationRules` and `holdings`, with the numbers above. `deadlineNearDays` waits for
  reminders.
- **Not built:** reminders on the device (the server keeps decisions and schedules, ISS-104)
  and Insights on the device (they come from `/analytics/personal`, ISS-105).

### Deploying the finance revamp

Migrations 0013–0018 and this app build go out together:

1. Ship the new APK with the server. Builds from before it fail to load Personal once a
   transfer, refund or correction syncs to them (ISS-073).
2. After the API has migrated, make every device reload:
   `docker compose exec api python -m app.recover reset-stream --all` (or each `user:<id>` and
   `global`), for 0013's backfilled accounts and 0018's Insights cards. The new build's local
   schema 2 reloads from snapshots by itself.
3. Downgrading below 0013 is refused while any transfer, refund, investment or correction
   exists (0014–0017 likewise while goals, rules, holdings or reminder decisions do).

Migration 0019 (linked accounts and account numbers) only adds two columns, so it needs no
stream reset. Builds from before it ignore links and count a linked account on its own.
Downgrading is refused while an account is linked or numbered.

## Bank SMS (Android)

Personal can read the SMS a bank sends to the phone and add the payments it finds. It's
Android only. What it adds syncs, so web and iOS show it too, but only the phone reads
messages.

- **Turning it on.** Profile → Bank SMS (`/profile/sms`), or Overview's one-time offer. The
  setup page says what's read and what leaves the phone before the system asks for READ_SMS
  (Google Play's prominent disclosure). You choose how far back to read: this month, or the
  last 3 or 12 months.
- **On the phone** (`android/…/SmsChannel.kt`, `lib/features/sms/`):
  - Kotlin hands over only messages whose sender matches `senderPattern` (business headers
    such as VM-HDFCBK-S), so messages from people never reach the app.
  - `SmsWatcher` reads when the app opens, comes back to the front, or the inbox changes.
  - `SmsImporter` parses each message (`core/sms/`), gives it its fixed id, and adds it with a
    category (`core/categorise`). A payment already here is skipped: the same id, a reference
    already seen, or an entry you made by hand, which gets the account and merchant instead.
    These decisions are a pure function (`core/sms/sms_scan.dart`) over an input taken from the
    device's data once; more than a few dozen messages are read on another isolate
    (`Isolate.run`), so a first read of months of SMS doesn't freeze the screen.
  - Each new entry goes in an account: your open account with the message's label, none if
    that account is closed or deleted, else the one account the label's digits say it is (its
    full number ends in them, or it's the same card of the same bank labelled "Card" one way and
    "Credit card" the other), else a new one (`smsAccountId` of you and the label, the id 0013's
    backfill uses), opened so it matches the bank's first reported balance. A label that says
    "credit card" makes a card, any other a bank account. An account linked to another counts
    as that one: its type, and closed when that one is.
  - A refund goes back into the account for the spend it matches (the finance engine's refund
    rules), in that spend's category. A cash withdrawal is a transfer into your oldest open
    Cash account (`atmToCash`); with none, `countAtmAsSpending` decides whether it's spending.
  - Once every message is read, a card bill pairs with the one payment of its amount out of a
    bank or cash account within 3 days, and an own transfer with the nearest money the other
    way, of its amount, in another account, within `transferSuggestionMinutes`: the two become
    a transfer. One whose other half isn't found is skipped, and tried again by the next read.
    Plain payments are never paired here; Just in suggests them.
  - An income gets the plans your allocation rules make for it, in the same request.
  - Everything a read finds is queued at once (`FinanceWrites.importUnits`) as
    `POST /personal/batch` requests of up to `Features.importChunk` (50) items: accounts first,
    and a unit (an entry, a transfer's two halves, an income and its plans) never split.
  - Backfilled entries arrive looked at, except those from the last
    `Features.justInBackfillDays`.
- **What stays on the phone.** The message text, OTPs, and a "Messages we skipped" list of
  bank messages that weren't added. They're kept in the store's device-only values, never
  synced, and gone on logout.
  - A unit the device's checks refuse is left out (with the units that need it) and the rest
    queued. Its messages go in a per-device retry list (`sms.retry`, with a try count), which
    later reads read again whatever the cursor; after 3 refused reads a message moves to
    "Messages we skipped".
- **Never reads** in view-as, before the first sync, or when your currency isn't rupees.
- **Notifications** (`SmsReceiver.kt`), when a bank SMS arrives with the app closed:
  - A short-lived Dart engine runs `smsBackgroundMain` (in `main.dart`) to describe the
    message with the same parser, e.g. "₹450 at Swiggy · HDFC ··4821 · UPI".
  - A spend's notification has Split (`Integrations.notificationSplitAction`). Opening from it
    adds the payment and opens Add split, or Personal.
  - The phone only knows what `SmsImporter.configureNotifications` tells it: whether to notify
    (switch on the setup page), whether to offer Split, and the sender pattern.
  - It stores nothing itself; the app reads the inbox when it's opened. Signing out turns it
    off.
- **On an emulator:** run `flutter run --dart-define=SMS_TEST_SENDER=5551234`, then
  `adb emu sms send 5551234 "Sent Rs.450.00 From HDFC Bank A/C *4821 To SWIGGY On 12/10/26 Ref 627812345678"`.
- **Google Play** allows READ_SMS for SMS-based money management, through a declaration
  (ISSUES.md).

## Tricount sync

A deletable module (`api/app/modules/tricount_sync/`, `app/lib/features/tricount_sync/`, the
`tricount` compose service and migration 0008) that keeps a group and a tricount the same,
both ways, from the group's menu → Sync with Tricount (`/groups/{id}/tricount`).

- **Unofficial.** Tricount has no public API. The server talks to bunq's private one the way
  the Android app does (`client.py`, after github.com/federicobond/go-tricount): it registers
  once as an anonymous device and joins tricounts by their share link. Writes are only accepted
  with the Android app's User-Agent (`TRICOUNT_USER_AGENT`). It may break or be blocked at any
  time, and may not be allowed by Tricount's terms. `TRICOUNT_API_URL` points it elsewhere.
- **Server-side.** Apps and the website never call Tricount: they write to Splitkit as always
  (offline queue included), and the server mirrors. Turning the sync off is stopping the
  `tricount` service.
- `POST /groups/{id}/tricount/preview {link}` reads a tricount without joining it and suggests
  who its people are. `POST /groups/{id}/tricount {link, people}` links it (or `{create: true}`
  makes a new tricount from the group); the first pass runs right after, and the group takes
  the tricount's name. `GET …/tricount` is the status, `POST …/tricount/sync` syncs now,
  `DELETE …/tricount` stops (nothing is deleted).
- **A pass** (`reconcile.py`) reads the whole tricount and compares each entry three ways:
  Splitkit's, Tricount's, and the version both last agreed on (`tricount_entries.base`, in the
  form `mapping.py` defines). One side changed: it goes to the other. Both changed: a
  `tricount_conflicts` row, shown in the app as "N changes from Tricount need a decision",
  resolved with `POST /tricount/conflicts/{id}/resolve {keep}`. New people on either side
  are added to the other (Tricount people become placeholders). There's no retry queue: what
  still has to go is whatever differs from its base, so a failed pass just leaves work for the
  next one, and creates use ids derived from the other side so a redo never duplicates.
- **When** (`worker.py`): within seconds of a Splitkit change, every
  `TRICOUNT_POLL_SECONDS` (60) while someone in the group uses the app
  (`ActivityMiddleware` sets `last_active_at`), with exponential backoff after failures.
  `python -m app.modules.tricount_sync --once` runs one round.
- Changes from Tricount are recorded as the "Tricount" system user (`role = 'system'`), so
  history says "Edited by Tricount".
- Not carried over: Tricount income entries (shown as a warning with the amount, since
  balances then differ), payment methods and expense notes (Tricount has neither), member
  removals and renames after linking. Categories map coarsely (`mapping.py`).
- Tests use an in-memory Tricount (`api/tests/tricount_fake.py`). Nothing here has run
  against the real service: try it on a throwaway tricount first.

## Tricount import

A deletable module: `api/app/modules/import_tricount/` and `app/lib/features/import_tricount/`,
reached from Profile → Import from Tricount (`/profile/import`). Nothing else depends on it except
the router entry, the Profile link and the `import_batch_id` columns.

- `POST /import/tricount/preview` (multipart `file`, optional `group_id` / `currency`) parses the
  export and saves nothing: suggested people and category mappings, every row in minor units with
  its issues, and totals. It is stateless; the client keeps the file.
- `POST /import/tricount/commit` (the same `file` plus `options` JSON: target, people, categories)
  imports everything in one transaction as one `import_batches` row. Expenses become exact splits,
  money transfers become payments (one per recipient), income rows are skipped. The group, the
  memberships, expenses and payments it creates carry `import_batch_id`, and every write goes
  through `record()`.
- `GET /import/batches`, `GET /import/batches/{id}` and `POST /import/batches/{id}/undo`. Undo
  soft-deletes the batch's expenses and payments (edited ones too), ends the memberships it added
  for people left in nothing live, and archives a group it created once it's empty. Undoing
  twice changes nothing.
- The parser (`parser.py`) matches headers case-insensitively by alias: Tricount's own
  `Title, Amount, Currency, Exchange rate, Amount in default currency, Date & time, Paid by,
  Transaction type, Category, Impacted to <name>…`, plus `Paid for`/`Share <name>`, `Paid by <name>`
  (Sesterce layout), `Who paid`, `Description`, `Total`. It reads CSV (`,` `;` tab `|`, BOM,
  UTF-8/16 or cp1252) and XLSX, decimal commas and thousands separators, and ISO, d/m/y, m/d/y
  (decided per file) and text dates. `plan.py` turns rows into minor units: shares that add up are
  kept; a few paise of Tricount rounding, or a converted row, is re-spread with the split engine's
  largest remainder; a bigger gap is a row error ("₹100 still needs to be allocated").
- Sample exports are in `api/tests/fixtures/tricount/` (the mockup's Goa Trip).
