# Validation and recovery

How to check that Splitkit's data is correct — on the server, on each device, and between the
two — and what to do when something is wrong. Commands assume the repo root unless they `cd`.

## Quick check

```sh
docker compose up -d --build api                   # the image must include app/validate.py
docker compose exec api python -m app.validate     # the running server's data
```

Passing looks like `15 checks: 0 failed, 0 warnings.` and exit code 0. Exit code 1 means at
least one **error** (the data is wrong); warnings alone still exit 0. Exit code 2 means the
checks couldn't run (usually the database isn't reachable). Add `--json` for a
machine-readable report, e.g. in CI or a cron job.

To check everything before a release:

```sh
cd api && uv run pytest -q && uv run ruff check .             # API: 600+ tests
cd app && flutter analyze && flutter test --concurrency=1       # app: 240+ tests
```

## What "valid" means

Splitkit's money rules (HANDOFF rules 1–4) and the sync design depend on a few invariants.
Some are enforced by PostgreSQL and can't be broken by the app; the rest are checked by
`app.validate`.

### Enforced by the database

| Rule | How |
|---|---|
| Shares of an expense add up to its amount | Deferred constraint triggers `expense_splits_sum_matches` / `expenses_split_sum_matches` (checked at commit) |
| Amounts are above zero, shares not negative | `ck_*_amount_positive`, `ck_expense_splits_share_not_negative` |
| A payment is between two different people | `ck_settlements_different_people` |
| Only people with an email can have a password | `ck_users_login_needs_email` |
| Emails are unique, ignoring case | unique index `uq_users_email_lower` |
| A transfer's live legs are one out and one in, same amount and currency, between two different accounts | Deferred constraint trigger `personal_transfer_pairs` (checked at commit) |
| A personal entry's account, and the spend a refund points at, are its owner's | Foreign keys on `(account_id, user_id)` and `(refund_of_id, user_id)` |
| One personal account per bank SMS label, deleted ones included | unique index `uq_personal_accounts_user_sms_label` |
| A goal's followed account and a contribution's goal and entry are the owner's | Foreign keys on `(linked_account_id, user_id)`, `(goal_id, user_id)` and `(transaction_id, user_id)` |
| An entry counts towards one goal at most; each tracking mode has its own field and only that one | unique index `uq_personal_goal_contributions_live_transaction`; `ck_personal_goals_account_only_when_linked`, `ck_personal_goals_progress_only_when_manual` |
| One allocation plan per income and rule, ever; rules and plans go to exactly one goal or account, theirs; each kind has its own value | `uq_personal_allocation_plans_source_transaction_id`; `ck_*_one_destination`, `ck_*_percent_when_percentage`, `ck_*_amount_when_fixed`; foreign keys on `(…, user_id)` |
| Only investments and withdrawals name a holding, the owner's; a holding is in the owner's account | `ck_personal_transactions_holding_only_on_investments`; foreign keys on `(holding_id, user_id)` and `(account_id, user_id)` |
| One reminder decision per dedup key, ever; snoozed exactly when it has an until time; a schedule is for one goal or holding, on days 1–28 | `uq_personal_reminder_states_user_id`; `ck_personal_reminder_states_until_only_when_snoozed`; `ck_personal_reminder_schedules_one_target`, `ck_personal_reminder_schedules_day_of_month` |
| Enumerations (roles, scopes, methods, view-as modes, sync ops) | `ck_*` check constraints |

### Checked by `python -m app.validate`

| Check | Severity | Means | If it fails |
|---|---|---|---|
| `expense_shares_add_up` | error | Shares add up to the amount (also re-checked here in case the trigger was dropped) | Edit the expense in the app to re-allocate its split |
| `amounts_positive` | error | No zero/negative amounts or shares | Edit the row; amounts are integer paise |
| `expense_people_are_members` | error | Payer and everyone in a split are (or were) members of the group | Add the person back to the group, or edit the expense |
| `settlements_are_between_members` | error | Both sides of a payment are members of its group | Delete the payment (restorable) and record it again |
| `personal_links_are_the_owners` | warning | A personal entry linked to a split is its payer's; one linked to a payment is the sender's (spending) or receiver's (income) | Expected after a payer edit; unlink the entry |
| `currency_matches_group` | error | Expenses and payments are in the group's currency | Bad import or manual SQL; fix the row |
| `categories_fit_their_use` | error | Expenses use group categories; personal entries use personal ones (built in or their owner's) | Pick another category in the app |
| `transfer_pairs_are_whole` | error | A transfer's live legs are one out and one in, same amount and currency, between two of one person's accounts (also re-checked here in case the trigger was dropped) | Check the `personal_transfer_pairs` trigger exists, then fix or delete the legs |
| `entries_use_own_accounts` | error | A personal entry's account is its owner's (the foreign key normally refuses anything else) | Set the entry's `account_id` to null or the owner's account, then reset their stream |
| `goal_contributions_count_once` | error | No entry counts towards a goal both as a contribution and through the balance of an account another goal follows (either leg of a transfer) | Delete the contribution, or switch the goal that follows the account to another mode |
| `goal_contributions_fit` | error | A live contribution is to a live goal in its currency; its entry (if any) is live, in that currency and at least as much | Delete the contribution or fix its amount; deletes normally cascade |
| `linked_goals_follow_live_accounts` | error | A goal that follows an account's balance follows a live account in its currency, and no other counting goal follows the same one | Restore the account, or switch one goal to another mode |
| `allocation_plans_follow_their_income` | error | A live allocation plan is for a live income, in the income's currency | Delete the plan; deleting an income normally cancels its plans |
| `allocation_rules_point_somewhere` | error | A live allocation rule sends money to a live contribution-mode goal (not archived) or a live, open account, in its currency | Point the rule elsewhere or delete it; the API normally refuses the change that broke it |
| `holdings_are_in_investment_accounts` | error | A live holding is in a live investment account in its currency; a live entry that names a holding names a live one in its currency | Move the holding, restore what was deleted, or clear the entry's `holding_id` |
| `reminder_schedules_point_somewhere` | error | A live reminder schedule is for a live goal or holding | Delete the schedule or restore its target; deletes normally cascade |
| `accounts_are_sane` | error | Placeholders have no password, personal entries, accounts, goals, allocation rules or holdings; no duplicate emails | Merge the accounts, or move the rows |
| `invites_are_open` | warning | Invite emails are lowercase, only on current placeholder members, and no account has the email yet | Link the member again: with an account it merges |
| `groups_have_members` | warning | A group that isn't archived has a current member | Normal after everyone leaves; archive it |
| `versions_start_at_one` | error | Every versioned row has version ≥ 1 (used for conflict detection) | `UPDATE … SET version = 1`, then reset its stream |
| `undone_imports_left_nothing` | error | An undone Tricount import has no live rows left | Undo it again (`POST /import/batches/{id}/undo` is idempotent) |
| `admin_sessions_are_closed` | warning | No view-as session is open past its expiry | `python -m app.recover end-admin-sessions` |
| `admin_writes_by_admins` | warning | Rows marked "by an admin" point at an admin | Expected if an admin was demoted; else check the audit log |
| `sync_streams_are_gap_free` | error | Each stream's kept changes run `oldest_seq+1 … head_seq` with no gaps | `python -m app.recover reset-stream <stream>` |
| `sync_streams_point_somewhere` | error | Every stream is `global` or names an existing group/user | Delete the orphan stream's rows |
| `sync_log_matches_tables` | error | The newest sync entry for each entity matches its table row (exists, same version) | A write bypassed `record()`; `reset-stream` that stream |

The checks are in `api/app/validate.py`; each has a test that plants the problem and expects it
to be found (`api/tests/api/test_validate_recover.py`).

### Checked by the test suites

| What | Where |
|---|---|
| Every API route, including permissions, read-only view-as, conflicts (409), idempotent client ids, the sync log | `api/tests/` |
| The split engine and balance engine give the same answers in Python and Dart | `shared/split_vectors.json`, `shared/balance_vectors.json` (both suites run them) |
| Every answer the app computes on the device (groups, balances, feed, expense detail, settle-up, personal list, summary and accounts, categories) equals the API's, for two seeded users | `app/test/core/local_parity_test.dart` with `app/test/fixtures/sync/` |
| Syncing: snapshots, incremental changes, tombstones, paging, lost access, crash-safe cursors, offline | `app/test/core/sync_engine_test.dart`, `app/test/features/offline_test.dart` |
| Offline writes: shown at once, sent once, retried with the same id, conflicts, keep mine / keep theirs | `app/test/features/outbox_test.dart` |
| View-as: banner and frame, target's data, read-only refused on the device, allow edits, exit | `app/test/features/admin_test.dart` |
| Recovery actions on the device | `app/test/features/recovery_test.dart` |

### End to end against a real server

The live tests sync a fresh device from a running API, make real writes as two users (including
an offline edit that hits a real conflict), sync again and compare every answer with the API.
They **write** to the server, so use a throwaway database, never the dev one:

```sh
cd api
export DATABASE_URL=postgresql+psycopg://splitkit:splitkit@localhost:5433/splitkit_fixtures
docker compose exec db psql -U splitkit -c 'CREATE DATABASE splitkit_fixtures' || true
uv run alembic upgrade head && uv run python -m app.seed --reset
uv run uvicorn app.main:app --port 8001 &
cd ../app && LIVE_API=http://localhost:8001 flutter test test/live
cd ../api && uv run python -m app.validate                     # still valid after the traffic
```

Reseed before each run (`uv run python -m app.seed --reset` with the same `DATABASE_URL`). Refresh
the captured fixtures from the same instance with
`API=http://localhost:8001 python3 tool/capture_api_fixtures.py`.

### Speed

`flutter test test/perf` times the device-side code on a heavy synthetic dataset (about five
years of use: 20k personal entries, 5k group expenses) in the VM, prints a table, and fails when
something gets about 4× slower than when its ceiling was set. It runs in the normal suite too.

On-device timing runs the app on a phone over the same dataset, in a real store on the phone's
disk, with a fake API and a fake SMS inbox, and traces three actions: a cold start to Overview's
numbers, flinging Transactions from top to bottom, and a first read of 2,000 bank SMS. It isn't
part of `flutter test`. Plug in an Android phone with USB debugging on, then:

```sh
cd app
flutter devices                      # the phone's id
flutter drive --profile -d <device-id> \
  --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
```

It prints a table per action: frames, frame build times (UI thread: average, 90th and 99th
percentile, worst) and raster times, and how many missed the 16 ms budget. The figures go to
`build/perf_summary.json`, each action's summary to `build/<action>.timeline_summary.json`, and
the full timelines to `build/<action>.timeline.json` (open them in Perfetto). The plan's targets:
Overview within 1.5 s of a cold start (`wall_clock_ms.cold_start_to_overview`), and no missed
frames, with builds under 8 ms, while scrolling.

It installs a profile build of the app on the phone. Its data goes in the app's temporary folder
and leaves your own alone, but if the installed app was signed with another key, Flutter
uninstalls it first and its device data (unsent changes, bank SMS settings) is lost: sync first,
or use a phone without your data. `-d linux` works from a copy of `app/` with
`flutter create --platforms=linux .` run in it (the repo has no `linux/` folder), as a quick check
that the test runs; the web has no `dart:io`, so it can't run there.

## When something is wrong: on a device

The app keeps a full copy of your groups and personal data on the device and works offline.
Changes made on the device wait in an outbox until the server takes them. Most device problems
are fixed by syncing again or reloading that copy, and neither loses your unsynced changes.

Everything below is on **Profile › This device** unless stated.

| Symptom | What's happening | Do this |
|---|---|---|
| "You're offline. Showing what's on this device." while you are online | The app can't reach the API | Check the server is up (`curl <origin>/api/v1/openapi.json`). In debug builds, check **Server: …** under the login form points at the right origin (emulator: `http://10.0.2.2:8000`, phone: your computer's LAN IP). |
| "N changes will sync when you're back." | Normal offline: changes are queued | Nothing. They're sent, in order, the next time the app reaches the server. |
| Changes stay "waiting" while online | The server is failing those requests (5xx) | Check the API logs. The app retries on every sync (every 45 s, on resume, on **Sync now**) and keeps receiving others' changes meanwhile. |
| "N changes couldn't be saved · Review" | The server refused them: someone else changed the same thing (conflict), or a check only the server can make failed | Tap **Review**. For a conflict: **Keep mine** sends yours on top of theirs; **Keep theirs** drops yours. For other refusals the reason is shown; **Discard** drops it and you can redo it. |
| Numbers differ from someone else's phone | One device hasn't synced, or a local copy is off | **Sync now** on both. Still different: **Reload from the server** (keeps unsynced changes). Still different: run `python -m app.validate` on the server. |
| App shows an error card on first sign-in | The first sync needs a connection | Connect and tap **Try again**. After that the app opens offline. |
| Signed out unexpectedly | The token expired (the app wasn't opened online for 7 days) | Sign in again as the same person: the device's data and unsynced changes are kept and sent. |
| Need to wipe the app or switch phones with changes waiting | Logging out or clearing app storage deletes unsynced changes | **Copy unsynced changes** first (JSON with each request), then log out. The Log out dialog warns when changes would be lost. |
| App crashes on open, or the local database is damaged | Rare: storage corruption | If it opens: **Reload from the server**. If it doesn't: clear the app's storage (Android: Settings › Apps › Splitkit › Storage › Clear storage; web: clear site data), then sign in. Unsynced changes are lost in that case. |
| An admin is stuck "viewing as" someone | View-as lives in memory only | Tap **Exit** on the amber banner, or restart the app (it always comes back as the admin). On the server: `python -m app.recover end-admin-sessions`. |

## When something is wrong: on the server

### Validation reports an error

1. Run `python -m app.validate` and read the **Fix** line and the sample rows for each failing
   check (table above).
2. Fix the data through the app or API where possible. Every write through the API is
   recorded in the audit log and sent to devices by the sync log. Avoid manual SQL.
3. If you had to use SQL, finish with `python -m app.recover reset-stream <stream>` for each
   affected stream (`group:<group id>`, `user:<user id>` or `global`), so devices reload from
   the tables.
4. Run `python -m app.validate` again until it passes.

### Common repairs

| Problem | Repair |
|---|---|
| An expense or payment was deleted by mistake | Deletes are soft: restore it from the group's **Deleted items** (`/groups/<id>/deleted`), or `POST /expenses/{id}/restore` / `POST /settlements/{id}/restore`. |
| An expense was edited wrongly | Its detail page lists every change with before/after (from `audit_logs`); edit it back. |
| A Tricount import went wrong | **Undo import** on the Done screen, or `POST /import/batches/{id}/undo`. It soft-deletes everything the batch created, even rows edited afterwards; each can be restored. |
| Devices show stale or inconsistent data for one group | `docker compose exec api python -m app.recover reset-stream group:<id>`: every device reloads that group on its next sync. |
| Devices are inconsistent everywhere (e.g. after a restore) | `docker compose exec api python -m app.recover reset-stream --all` |
| View-as sessions left open | `docker compose exec api python -m app.recover end-admin-sessions` (audited) |

`reset-stream` doesn't delete anything. It writes the stream's root entity again (group,
profile or built-in categories), then marks every older cursor as too old, so devices load a
fresh snapshot built from the tables.

### Backups and restore

```sh
# Back up (custom format, compressed)
docker compose exec -T db pg_dump -U splitkit -Fc splitkit > splitkit-$(date +%F).dump

# Restore into a stopped API
docker compose stop api
docker compose exec -T db dropdb -U splitkit --if-exists splitkit
docker compose exec -T db createdb -U splitkit splitkit
docker compose exec -T db pg_restore -U splitkit -d splitkit < splitkit-YYYY-MM-DD.dump
docker compose start api                       # runs `alembic upgrade head` on start
docker compose exec api python -m app.validate
docker compose exec api python -m app.recover reset-stream --all
```

**Always run `reset-stream --all` after a restore.** Devices remember how far they got in each
stream. After going back in time, a device whose cursor is ahead of the restored server is
detected automatically. A device whose cursor happens to be at or below the restored head
would not be, and it would keep changes the server no longer has. Changes queued on devices
are sent again; creates carry their own ids, so nothing is added twice.

### Migrations

```sh
cd api
uv run alembic current && uv run alembic heads      # one head: 0006_split_position
uv run alembic upgrade head
uv run alembic check                                # models and migrations agree
uv run alembic downgrade -1                         # undo the last migration if it went wrong
```

If an upgrade fails half-way, PostgreSQL rolls that migration back (migrations run in a
transaction). Fix the cause and run `upgrade head` again. After any migration run
`python -m app.validate`.

### Development database

`python -m app.seed --reset` **deletes everything** and loads the sample data (Goa Trip,
Flatmates, personal finances). Use it only on the dev or a throwaway database. Test runs use
their own database (`splitkit_test` by default; set `TEST_DATABASE_URL` to pick another) and
never touch the dev one.

## Build environment (this machine)

| Problem | Fix |
|---|---|
| `flutter build apk` / Gradle killed ("daemon disappeared", exit 137) | Out of memory. `~/.gradle/gradle.properties` caps Gradle at 2 GB; close other apps or lower it further. |
| `flutter test` killed | Run `flutter test --concurrency=1`. |
| "No Android SDK found" | `flutter config --android-sdk ~/Android/Sdk`; `ANDROID_HOME` and `JAVA_HOME` are set in `~/.zshenv`. |
| Android Studio's folder was removed | The JDK builds use lives in `~/packages/android-studio/jbr`. Point `JAVA_HOME` and `flutter config --jdk-dir` at another JDK 17+ first. |

## Where things are

| Path | What |
|---|---|
| `api/app/validate.py` | The server checks |
| `api/app/recover.py` | `reset-stream`, `end-admin-sessions` |
| `api/app/modules/sync/` | Sync log, `POST /sync`, snapshots |
| `app/lib/core/local/` | Device store, sync engine, ledger (answers computed on the device), offline writes |
| `app/lib/features/profile/device_card.dart` | Profile › This device |
| `app/lib/features/shell/sync_banner.dart` | Offline line and "Needs your attention" |
| `app/test/live/` | End-to-end tests against a real server |
