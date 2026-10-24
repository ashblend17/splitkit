# App: changelog

The UI (Android, iOS and the web image), versioned on its own: the backend has its own
(`api/CHANGELOG.md`). [Semantic versioning](https://semver.org): a major version for a change
that needs people to do something (sign in again, a newer backend), a minor one for something
new, a patch for fixes. Notes go under Unreleased as changes are made;
`python3 tool/version.py bump ui <patch|minor|major>` turns them into a version (README
"Versions and releases").

## Unreleased

## 1.0.0 · 2026-10-24

The first numbered release: everything up to here.

- Split: groups, expenses split equally, exactly, by percent or by shares, payments and settle
  up by each group's fewest payments, friends across groups, history, offline with sync.
  Tapping a name with everyone ticked splits with only them.
- Personal: accounts and balances (a balance you set stays put when older entries come in),
  entries of every type (spends, income, transfers, refunds, investments, corrections), goals,
  allocation rules and plans, holdings, Overview's cash flow, and Insights: the trend,
  breakdowns side by side in a carousel, each category's usual week or month against now,
  needs and wants and the savings rate, with animations.
- Android: bank SMS read on the phone, notifications that open the entry (and hide amounts on
  the lock screen unless you choose), "This was a refund" and "This was a transfer".
- Import from Tricount, and keep a group in sync with a tricount.
- Admin: users, sessions, audit log, view as.
- The app icon on every platform.
- The app's name and Android id come from `.env` (`APP_NAME`, `APP_ID`) when it's built.
