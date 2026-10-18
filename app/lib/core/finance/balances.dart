/// Account balances: what each account holds (or, for a card or loan, what you owe), worked out
/// from its opening balance and every live entry on it, and how that compares with the balance
/// the bank last reported.
library;

import 'model.dart';

/// What [e] does to the balance of an account of type [t]: an asset rises with money in, what's
/// owed on a liability rises with money out.
int entryEffect(FinEntry e, AccountType t) {
  final signed = e.flow == MoneyFlow.inflow ? e.amount : -e.amount;
  return t.isLiability ? -signed : signed;
}

/// The order entries happen in on an account: by day, a balance correction first in its day (so
/// one dated on a reported balance's day closes the gap at it), then when it happened (the SMS's
/// time, else created_at), when it was made, and id. Migration 0013's backfill sorts the same way
/// (it never sees a correction).
int compareLedgerOrder(FinEntry a, FinEntry b) {
  var c = a.day.compareTo(b.day);
  if (c != 0) return c;
  final aFirst = a.txnType == TxnType.adjustment, bFirst = b.txnType == TxnType.adjustment;
  if (aFirst != bFirst) return aFirst ? -1 : 1;
  c = a.atMicros.compareTo(b.atMicros);
  if (c != 0) return c;
  c = a.createdMicros.compareTo(b.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// A balance the bank reported with an entry, against the one worked out up to that entry.
final class Checkpoint {
  const Checkpoint({required this.entryId, required this.day, required this.reportedMinor, required this.derivedMinor});

  /// The entry whose SMS reported it.
  final String entryId;
  final int day;
  final int reportedMinor;

  /// The opening plus every entry up to and including [entryId], in [compareLedgerOrder].
  final int derivedMinor;

  /// What the entries miss: more than zero when the bank says there's more than they add up to.
  int get gapMinor => reportedMinor - derivedMinor;
}

/// An account's balance from its entries.
final class AccountBalance {
  const AccountBalance({
    required this.account,
    required this.balanceMinor,
    required this.entryCount,
    this.lastActivityDay,
    this.lastReported,
  });

  final FinAccount account;

  /// What it holds, or for a liability, what you owe.
  final int balanceMinor;

  /// The live entries on it.
  final int entryCount;

  /// The day of its latest entry, if any.
  final int? lastActivityDay;

  /// The latest balance the bank reported (asset accounts only: card SMS report a limit, not what
  /// you owe).
  final Checkpoint? lastReported;

  /// What it adds to net worth: a liability takes away what you owe.
  int get netWorthMinor => account.type.isLiability ? -balanceMinor : balanceMinor;
}

/// Whether [e] can move a balance: live and of a type this build knows.
bool _moves(FinEntry e) => !e.deleted && e.txnType != null;

/// The balance of each of [accounts] that isn't deleted, in the order given: its opening plus
/// the effect of every live entry in [entries] on it (whatever its type, counted in cash flow or
/// not: the money did move), in the account's currency. Entries in another currency (from
/// before a currency change) can't be added, so they're left out.
List<AccountBalance> accountBalances(Iterable<FinAccount> accounts, Iterable<FinEntry> entries) {
  final running = <String, _Running>{
    for (final a in accounts)
      if (!a.deleted) a.id: _Running(a),
  };
  final mine = [
    for (final e in entries)
      if (_moves(e) && running.containsKey(e.accountId)) e,
  ];
  if (!_inLedgerOrder(mine)) mine.sort(compareLedgerOrder);
  for (final e in mine) {
    running[e.accountId]!.add(e);
  }
  return [for (final r in running.values) r.balance()];
}

bool _inLedgerOrder(List<FinEntry> entries) {
  for (var i = 1; i < entries.length; i++) {
    if (compareLedgerOrder(entries[i - 1], entries[i]) > 0) return false;
  }
  return true;
}

/// One account's balance, added up entry by entry in ledger order.
class _Running {
  _Running(this.account) : minor = account.openingMinor;

  final FinAccount account;
  int minor;
  int count = 0;
  int? lastDay;
  FinEntry? reported;
  int reportedDerived = 0;

  void add(FinEntry e) {
    if (e.currency != account.currency) return;
    minor += entryEffect(e, account.type);
    count++;
    lastDay = e.day;
    if (e.balance != null && !account.type.isLiability) {
      reported = e;
      reportedDerived = minor;
    }
  }

  AccountBalance balance() => AccountBalance(
    account: account,
    balanceMinor: minor,
    entryCount: count,
    lastActivityDay: lastDay,
    lastReported: switch (reported) {
      final e? => Checkpoint(entryId: e.id, day: e.day, reportedMinor: e.balance!, derivedMinor: reportedDerived),
      null => null,
    },
  );
}

/// The opening balance that makes an account's balance, right after the first of [entries]
/// that reported one, equal what it reported; 0 when none did, and for a liability (card SMS
/// report a limit, not what you owe). [entries] are one account's entries in its currency;
/// deleted ones are skipped. The same rule as migration 0013's backfill (opening_balance), so an
/// account made from bank SMS starts reconciled (shared/ledger_vectors.json).
int openingFromFirstReport(Iterable<FinEntry> entries, AccountType type) {
  if (type.isLiability) return 0;
  final sorted = [
    for (final e in entries)
      if (_moves(e)) e,
  ]..sort(compareLedgerOrder);
  var running = 0;
  for (final e in sorted) {
    running += entryEffect(e, type);
    if (e.balance case final reported?) return reported - running;
  }
  return 0;
}

/// The balance correction that makes [b] agree with what the bank says ([bankSaysMinor]: what
/// it holds, or for a liability, what you owe), or null when it already does.
///
/// With [atCheckpoint] (and a reported balance to compare with), the correction is for the day
/// of [b]'s latest reported balance: dated that day, it sorts before the entry that reported it
/// and closes the gap there. Otherwise it's against the balance now.
({MoneyFlow flow, int amountMinor})? reconcileDelta(AccountBalance b, int bankSaysMinor, {bool atCheckpoint = true}) {
  final from = (atCheckpoint ? b.lastReported?.derivedMinor : null) ?? b.balanceMinor;
  final gap = bankSaysMinor - from;
  if (gap == 0) return null;
  final up = b.account.type.isLiability ? MoneyFlow.outflow : MoneyFlow.inflow;
  return (flow: gap > 0 ? up : up.opposite, amountMinor: gap.abs());
}
