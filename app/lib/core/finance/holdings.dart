/// Holdings: what's in your investment accounts at the value you last typed, and how an investment
/// account is valued by them, each rupee counted once (finance revamp design §5.1).
///
/// An investment account with live holdings is worth what they were worth on their valuation
/// days, plus what's been put in (less taken out) since at cost: investments and withdrawals that
/// name a holding and are dated after its valuation, and the account's own entries dated after
/// its latest valuation. Its opening balance and its entries up to then aren't counted: the
/// valuation is taken to include them. So a transfer into the account counts at cost straight away
/// (net worth doesn't move), and an opening balance typed in as the portfolio's value isn't
/// counted twice. Without live holdings it's worth its balance, as any other account.
library;

import 'balances.dart';
import 'model.dart';

/// A value older than this many days is stale (Features.staleValuationDays).
const defaultStaleDays = 30;

/// One holding as the screens show it: its value with what's been added since at cost, how old
/// its value is, and its gain when its cost is known.
final class HoldingView {
  const HoldingView({
    required this.holding,
    required this.valueMinor,
    required this.addedSinceMinor,
    required this.ageDays,
    required this.stale,
    this.gainMinor,
    this.gainBp,
  });

  final FinHolding holding;

  /// Its market value plus [addedSinceMinor].
  final int valueMinor;

  /// Put in (less taken out) by investments and withdrawals naming it, dated after its valuation:
  /// counted at cost until its next valuation.
  final int addedSinceMinor;

  /// Days from its valuation to today.
  final int ageDays;

  /// Its value is more than the stale days old: "Update value".
  final bool stale;

  /// Market value less cost basis; null without a cost basis. What's added since at cost raises
  /// value and cost alike, so it's left out.
  final int? gainMinor;

  /// [gainMinor] in basis points of the cost (1408 is 14.08%); null without a cost, or a zero one.
  final int? gainBp;
}

/// [h] on day [today] (a day key), from [namingIt]: entries that name it (others, deleted ones
/// and ones in another currency are skipped). Stale when its value is more than [staleDays] old:
/// day 30 is fresh, day 31 stale.
HoldingView holdingView(
  FinHolding h, {
  required int today,
  required Iterable<FinEntry> namingIt,
  int staleDays = defaultStaleDays,
}) {
  var added = 0;
  for (final e in namingIt) {
    if (e.holdingId != h.id || e.deleted || e.day <= h.valuationDay || e.currency != h.currency) continue;
    added += switch (e.txnType) {
      TxnType.investmentContribution => e.amount,
      TxnType.investmentWithdrawal => -e.amount,
      _ => 0,
    };
  }
  final age = daysBetween(h.valuationDay, today);
  final cost = h.costBasisMinor;
  final gain = cost == null ? null : h.marketValueMinor - cost;
  return HoldingView(
    holding: h,
    valueMinor: h.marketValueMinor + added,
    addedSinceMinor: added,
    ageDays: age,
    stale: age > staleDays,
    gainMinor: gain,
    gainBp: gain == null || cost == 0 ? null : gain * 10000 ~/ cost!,
  );
}

/// What an account is worth: its balance, or for an investment account with live holdings, its
/// value by them ([accountValue]).
final class AccountValue {
  const AccountValue({
    required this.account,
    required this.ledgerMinor,
    required this.valueMinor,
    this.byHoldings = false,
    this.holdingsMinor = 0,
    this.addedSinceMinor = 0,
    this.asOfDay,
    this.latestValuationDay,
    this.staleCount = 0,
    this.holdings = const [],
  });

  final FinAccount account;

  /// Its balance from its entries ([AccountBalance.balanceMinor]).
  final int ledgerMinor;

  /// What it's worth: [ledgerMinor], or by its holdings, [holdingsMinor] + [addedSinceMinor].
  final int valueMinor;

  /// Valued by its holdings (an investment account with live ones).
  final bool byHoldings;

  /// Its holdings' market values, as last typed.
  final int holdingsMinor;

  /// Put in (less taken out) since their valuations, at cost: investments and withdrawals naming
  /// them, and the account's own entries after its latest valuation. "incl. ₹5,000 added since
  /// 15 Aug" ([asOfDay]).
  final int addedSinceMinor;

  /// Its holdings' earliest valuation day ("as of 15 Aug"); null when not [byHoldings].
  final int? asOfDay;

  /// Its holdings' latest valuation day: its own entries after it count at cost.
  final int? latestValuationDay;

  /// How many of its holdings have a stale value.
  final int staleCount;

  /// Its live holdings, oldest first.
  final List<HoldingView> holdings;

  /// What it adds to net worth: a liability takes away what you owe.
  int get netWorthMinor => account.type.isLiability ? -valueMinor : valueMinor;
}

/// What [b]'s account is worth on [today] (a day key): by its live [holdings] in its currency if
/// it's an investment account with any (others in [holdings] are skipped), else its balance.
/// [entries] are the live entries on the account and those naming its holdings (any others are
/// skipped), each once.
AccountValue accountValue(
  AccountBalance b,
  List<FinHolding> holdings,
  Iterable<FinEntry> entries, {
  required int today,
  int staleDays = defaultStaleDays,
}) {
  final a = b.account;
  final mine = a.type != AccountType.investment
      ? const <FinHolding>[]
      : [
          for (final h in holdings)
            if (!h.deleted && h.accountId == a.id && h.currency == a.currency) h,
        ];
  if (mine.isEmpty) return AccountValue(account: a, ledgerMinor: b.balanceMinor, valueMinor: b.balanceMinor);
  var latest = mine.first.valuationDay, earliest = latest;
  for (final h in mine) {
    if (h.valuationDay > latest) latest = h.valuationDay;
    if (h.valuationDay < earliest) earliest = h.valuationDay;
  }
  final ids = {for (final h in mine) h.id};
  final naming = <String, List<FinEntry>>{};
  var own = 0;
  for (final e in entries) {
    if (e.deleted || e.txnType == null || e.currency != a.currency) continue;
    if (e.holdingId case final h? when ids.contains(h)) (naming[h] ??= []).add(e);
    if (e.accountId == a.id && e.day > latest) own += entryEffect(e, a.type);
  }
  final views = [
    for (final h in mine) holdingView(h, today: today, namingIt: naming[h.id] ?? const [], staleDays: staleDays),
  ];
  var market = 0, added = own, stale = 0;
  for (final v in views) {
    market += v.holding.marketValueMinor;
    added += v.addedSinceMinor;
    if (v.stale) stale++;
  }
  return AccountValue(
    account: a,
    ledgerMinor: b.balanceMinor,
    valueMinor: market + added,
    byHoldings: true,
    holdingsMinor: market,
    addedSinceMinor: added,
    asOfDay: earliest,
    latestValuationDay: latest,
    staleCount: stale,
    holdings: List.unmodifiable(views),
  );
}

/// Your investment accounts in one currency, valued: what Overview's net worth card shows
/// ("Investments ₹85,750 · as of 15 Aug", "1 value is stale").
final class Investments {
  const Investments({
    required this.accounts,
    required this.totalMinor,
    required this.holdingsMinor,
    required this.addedSinceMinor,
    required this.staleCount,
    required this.holdingCount,
    this.asOfDay,
  });

  /// Your investment accounts that aren't deleted (closed ones too), in the order given.
  final List<AccountValue> accounts;

  /// What they're worth.
  final int totalMinor;

  /// Their holdings' market values, as last typed.
  final int holdingsMinor;

  /// Put in since the valuations, at cost ([AccountValue.addedSinceMinor]).
  final int addedSinceMinor;

  /// The earliest valuation day among their holdings, or null with none.
  final int? asOfDay;

  /// Holdings with a stale value.
  final int staleCount;

  /// Their live holdings.
  final int holdingCount;

  bool get isEmpty => accounts.isEmpty;
}

/// The investment accounts of [values] in [currency], added up.
Investments investmentsOf(Iterable<AccountValue> values, {required String currency}) {
  final accounts = [
    for (final v in values)
      if (v.account.type == AccountType.investment && !v.account.deleted && v.account.currency == currency) v,
  ];
  var total = 0, market = 0, added = 0, stale = 0, count = 0;
  int? asOf;
  for (final v in accounts) {
    total += v.valueMinor;
    market += v.holdingsMinor;
    added += v.addedSinceMinor;
    stale += v.staleCount;
    count += v.holdings.length;
    if (v.asOfDay case final d? when asOf == null || d < asOf) asOf = d;
  }
  return Investments(
    accounts: List.unmodifiable(accounts),
    totalMinor: total,
    holdingsMinor: market,
    addedSinceMinor: added,
    asOfDay: asOf,
    staleCount: stale,
    holdingCount: count,
  );
}
