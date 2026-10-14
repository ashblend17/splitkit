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

## Run everything

```sh
cp .env.example .env
docker compose up -d --build          # db :5433, api :8000, web :8080
docker compose exec api python -m app.seed --reset
```

- Web app: http://localhost:8080 (log in as a seeded user; the component gallery is at `/gallery`)
- API docs: http://localhost:8000/api/v1/docs (OpenAPI JSON at `/api/v1/openapi.json`)
- Seeded logins: any seeded email with password `splitkit-dev`, e.g. `ansh.c@cyware.com` (admin)

The API container runs `alembic upgrade head` on start. Seeding never runs automatically.
The system categories and default dashboards are reference data, added by migration 0009 to
every database (the seed has the same rows; `tests/api/test_reference_data.py` keeps them equal).

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
- Balances are pairwise and per group ("You owe Rahul ₹500"). `GET /groups/{id}/balances` also
  returns `suggested`, the fewest payments that would settle the whole group. Home adds the
  groups up per friend.
- Placeholder members (people with no account, e.g. from a Tricount import) are linked with
  `POST /groups/{id}/members/{user_id}/link {email}` (`groups/linking.py`). If that email has an
  account, the placeholder's membership, expenses, shares and payments in all its groups move to
  it; where both were in one split the shares add up and the split becomes exact, and payments
  between the two are deleted. Otherwise the email is saved as the member's `invite_email`, and
  signing up with it turns the placeholder into the new account. Balances never move. The
  placeholder is kept with its memberships ended; the account's membership says `placeholder_name`.
- Settling with a friend across groups (`POST /friends/{id}/settle-up`) records one settlement
  per group, so every group's own balance stays right. With no amount every shared group ends
  at zero; a part payment pays down the oldest group first.
- `GET /feed` lists expenses and payments newest first, from the viewer's point of view
  (`my_net_minor`); `?deleted=true` lists deleted items for restoring. The desktop filters map to
  `group_id`, `category` (key), `start`/`end`, `unsettled` (expenses you aren't square on yet) and
  `q` (description or a person's name). `category` and `unsettled` leave payments out.
- Personal finance (`/personal/...`) is private to its owner: transactions with filters and
  totals, plus a monthly summary that includes your share of group spending.
  - An entry can say how it was paid (`channel`: upi, card, bank, atm, cash, other), who was paid
    (`merchant`) and the `account` ("HDFC ··4821"). Entries the app read from a bank SMS on the
    phone have `source: sms`, the bank's `reference`, the `balance_minor` it reported, `sms_at`,
    and `reviewed: false` until looked at. The message itself never leaves the phone.
  - An entry can be linked to the group expense it was split into (`expense_id`, one you paid)
    or the payment it was (`settlement_id`). While that expense or payment is live in a group
    you're in, the entry is listed with `counted: false` and left out of every personal total
    and personal analytics: your share counts as group spending, and a payment isn't spending.
  - On PUT, `channel`, `merchant`, `account`, the links and `reviewed` keep their value when
    the body leaves them out. `source`, `reference`, `balance_minor` and `sms_at` are set on
    create only.
  - `GET /personal/transactions` also filters by `account`, `channel`, `source` and `reviewed`.
    `GET /personal/accounts` lists accounts with the latest balance their bank reported.
  - Personal's default dashboard also has By account, By payment mode and Top merchants
    (`personal_by_account`, `personal_by_channel` and `personal_top_merchants`, migration 0011).
    In the app, Overview lists accounts with a reported balance, and Transactions filter by
    account and by how an entry was paid (`Features.accountBalances`, `breakdownFilters`).
- Analytics is config-driven: `GET /analytics/personal` and `GET /analytics/groups/{id}` loop over
  `analytics_configuration` rows (yours if you saved a layout, else the defaults). Each row's
  `source` maps to one function in `app/modules/analytics/sources.py`; each `type` maps to one
  renderer in `app/lib/features/analytics/cards.dart`. `PUT /analytics/layout/{scope}` saves
  your own order; `DELETE` goes back to the defaults.
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
  `user:<id>` (profile, personal entries, own categories, learned category rules, layouts,
  memberships), `global` (system categories, default layouts). Seqs are gap-free per stream.
- `POST /sync {"cursors": {"group:…": 41, …}}` returns, for every stream you can see, the changes
  after your cursor (paged by `limit`, with `has_more`). `snapshot_required` means: load
  `GET /sync/snapshot/{stream}` and store its `head_seq`. `gone` means: delete your copy.
- Entries are `upsert` (replace your copy with `data`) or `delete` (tombstone). Snapshot entities
  and log entries have the same shape.
- Edits and deletes may send `version` (body field, or `?version=` on delete and restore). A stale
  one gets 409 `version_conflict`. Creates may send their own `id`, so a retry returns the row it
  already made.
- Rows written outside `record()` (the seed, migrations) have no log entries. Clients get them
  from snapshots.
- Group entries carry `last_activity_at`; clients move it forward with the `at` of later
  group-stream changes (except `user.*`, which only re-sends member names). Expense entries embed
  their category with `scope` and `owner_id`.

### On the device

The app keeps every stream it can see in a local database (`app/lib/core/local/`, sembast: a
file on Android/iOS, IndexedDB on web; one database per user) and reads every screen from it.

- `SyncEngine` runs on sign-in, every 45 s while the app is open, on resume and after every write
  (`refreshLedger`). A batch and its cursor are stored in one transaction.
- `Ledger` rebuilds each API answer (groups, balances, feed, expense detail, settle-up plan,
  personal list and summary, categories) from the entities, following the server code line by
  line; `balance_engine.dart` ports the balance engine and settle-up planner (both pass
  `shared/balance_vectors.json`, like the split engine). Analytics, layouts and expense history
  still come from the network.
- Offline, screens keep showing the device copy with a "You're offline" line, and the app opens
  with the saved sign-in. A 401 signs you out but keeps the data; logging out deletes it.
- Writes work offline (`core/local/writes.dart`): expenses, payments (including settle-up with a
  friend, planned on the device and queued as one payment per group), personal entries, new
  groups and archiving. Each is queued in the outbox with its client id or base `version` and the
  full state it leaves behind, which every screen shows at once. The next sync sends the queue in
  order before pulling. A queued write stops being shown once the server's copy arrives.
  Refusals (409 conflicts, checks only the server can make) move to "Needs your attention" in the
  shell: Keep mine re-sends on top of the other change, Keep theirs / Discard drops it. Adding
  members, profile, categories and analytics layouts still need a connection.
- Checks: `app/test/core/local_parity_test.dart` compares every local answer with the API's for
  two seeded users (`app/test/fixtures/sync/`), and `app/test/live/` does the same against a
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
  `/personal/transactions`, Insights `/personal/insights`), add button ("Add split" in brand,
  "Add entry" in the personal accent) and accent. Profile and Admin belong to both; the app
  reopens in the mode it was left in. The old `/personal/history`, `/profile/history` and
  `/profile/analytics` redirect to Personal's tabs.
- A group is settled by its fewest payments (`suggested`, read through
  `features/groups/settle_plan.dart`): Settle up, the group summary (You pay, You get, Net), the
  desktop side panel and the top of the balances page follow it. The one-to-one balances
  (`people`) are a small table below; tapping a row records a payment for just that pair. Home
  and settling with a friend across groups stay one-to-one.
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
  only. It returns a payment (direction, amount, account label, mode, merchant, reference,
  balance, date) or why it skipped the message: OTPs, things still to come, failures, refunds,
  card bills, statements, own transfers, foreign currency, promotional and non-bank senders.
  `test/fixtures/sms/corpus.json` is the bank formats it's checked against. `sms_ids.dart`
  gives each SMS a fixed entry id.
- A personal entry can become something in Split (`features/personal/txn_actions.dart`):
  - **Split it:** `/expenses/new?from_txn=<id>` opens Add split filled in from the entry, paid
    by you. Saving queues the expense and the entry's link together
    (`LocalWrites.splitPersonal`, one `enqueueAll`).
  - **Already split:** links the entry to a split you paid with the same amount, dated within
    `linkWindowDays` (`Ledger.linkCandidates`).
  - **Paid a friend / From a friend:** a settle-up with someone you owe (or who owes you),
    started from the entry and linked to its first payment.
  - Overview's **Just in** (`just_in.dart`) lists SMS entries not looked at yet, with Split
    it, Looks right and Not mine (a delete; the SMS's fixed id keeps it deleted).
  - A linked entry says what it became and can be unlinked. The split shows its owner, and only
    its owner, which account paid.
- The API client in `app/packages/splitkit_api` is generated: after API changes run
  `(cd api && uv run python -m app.openapi) && tool/gen_api_client.sh` (needs Docker).
  Use `apiDate()` for date fields: the generated client converts dates to UTC.
- Admin pages (`features/admin/`) read the API directly, not the synced data. Every "View as"
  button calls `viewAsLauncherProvider` (`features/admin/view_as.dart`); the view-as switch,
  banner and frame (screen 18) plug in there.
- Screen tests run against real API responses in `app/test/fixtures/api`, and screens read from a
  local store synced from the snapshots in `app/test/fixtures/sync`. Refresh both with
  `docker compose exec api python -m app.seed --reset && python3 tool/capture_api_fixtures.py`
  (this resets the dev database; `API=http://localhost:8001` points it at another instance).
- Tests run on 25 Sep 2026, the day the fixtures were captured: screens read the time from
  `appClock` (`lib/core/clock.dart`), which `test/flutter_test_config.dart` pins.
- On a machine with little free memory, run `flutter test --concurrency=1`.

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
  - Backfilled entries arrive looked at, except those from the last
    `Features.justInBackfillDays`.
  - Entries go up through `POST /personal/transactions/batch` in chunks.
- **What stays on the phone.** The message text, OTPs, and a "Messages we skipped" list of
  bank messages that weren't added. They're kept in the store's device-only values, never
  synced, and gone on logout.
- **Never reads** in view-as, before the first sync, or when your currency isn't rupees.
- **Notifications** (`SmsReceiver.kt`), when a bank SMS arrives with the app closed:
  - A short-lived Dart engine runs `smsBackgroundMain` (in `main.dart`) to describe the
    message with the same parser, e.g. "₹450 at Swiggy · HDFC ··4821 · UPI".
  - The notification has Split (`Integrations.notificationSplitAction`). Opening from it
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
