# Backend: changelog

The API (`/api/v1`) and the Tricount worker, which share one image and one version, on their
own: the app has its own (`app/CHANGELOG.md`). [Semantic versioning](https://semver.org): a
major version for a change an app that's out there can't take (it would need `/api/v2`, or every
app updated first), a minor one for something new that older apps can ignore (an endpoint, a
field, a migration that only adds), a patch for fixes. Notes go under Unreleased as changes are
made; `python3 tool/version.py bump api <patch|minor|major>` turns them into a version (README
"Versions and releases"). Note a migration in the version that brings it.

## Unreleased

## 1.0.0 · 2026-10-24

The first numbered release: everything up to here, migrations 0001–0019.

- Groups, members (placeholders and linking them to accounts), expenses with the split engine,
  payments, balances by each group's fewest payments, friends and settle up across groups, the
  feed and history.
- Personal finance: accounts, entries of every type, transfers, refunds, goals and
  contributions, allocation rules and plans, holdings, reminders' server side, and Insights
  dashboards from `analytics_configuration` (Spending by category with each category's usual
  week or month).
- The sync change log and snapshots for offline devices.
- Import from Tricount (income as payments, rows paid by several people, Sesterce's layout) and
  the live Tricount sync (each change credited to whoever made it, entry times in UTC).
- Settings come from the repo's `.env` outside Docker too: the database from `DB_USER`,
  `DB_NAME` and `POSTGRES_PASSWORD`, the name the API uses for the app from `APP_NAME`, the seeded
  accounts' password from `SEED_PASSWORD`; `JWT_SECRET` has no default. A Tricount conflict is
  resolved with `keep: local` or `tricount`.
- The seeded accounts are made-up people: the admin is John Doe (`admin@example.com`).
- Admin: dashboard, users, sessions, audit log, view as.
