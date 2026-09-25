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
- Screen tests run against real API responses in `app/test/fixtures/api`. Refresh them with
  `docker compose exec api python -m app.seed --reset && python3 tool/capture_api_fixtures.py`.

## Money and splits

- Amounts are integer minor units (paise) plus a currency code. `app/core/money.py` formats and
  parses them (`₹1,50,000`, `₹1,533.33`).
- The split engine (`app/modules/splits/engine/`) is pure. Methods are plugins in `registry`;
  each has `validate(total_minor, inputs)` and `allocate(total_minor, inputs)`. Rounding uses
  largest remainder, with ties going to the earlier input, so shares always add up to the total.
- A deferred database trigger rejects any expense whose splits don't add up to its amount.
