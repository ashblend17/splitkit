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
  `message` is human copy the app can show as-is.
- Balances are pairwise and per group ("You owe Rahul ₹500"). `GET /groups/{id}/balances` also
  returns `suggested`, the fewest payments that would settle the whole group. Home adds the
  groups up per friend.
- Settling with a friend across groups (`POST /friends/{id}/settle-up`) records one settlement
  per group, so every group's own balance stays right. With no amount every shared group ends
  at zero; a part payment pays down the oldest group first.
- `GET /feed` lists expenses and payments newest first, from the viewer's point of view
  (`my_net_minor`); `?deleted=true` lists deleted items for restoring. The desktop filters map to
  `group_id`, `category` (key), `start`/`end`, `unsettled` (expenses you aren't square on yet) and
  `q` (description or a person's name). `category` and `unsettled` leave payments out.
- Personal finance (`/personal/...`) is private to its owner: transactions with filters and
  totals, plus a monthly summary that includes your share of group spending.
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
  `user:<id>` (profile, personal entries, own categories, layouts, memberships), `global`
  (system categories, default layouts). Seqs are gap-free per stream.
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
- Design-system widgets live in `app/lib/design_system/`; `/gallery` shows them all.
- Layout follows `SkLayout` (`app/lib/core/layout/layout.dart`): tab bar under 600px, NavRail up
  to 1279px, WebSidebar from 1280px. Only phones show the floating "Add split". Home and group
  detail have their own tablet and desktop layouts; other pages stay phone-width and centred.
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
