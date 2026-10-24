/// Net worth: what your accounts hold, less what you owe on cards and loans, and (when that's
/// counted) what friends owe you in Split, net. An investment account with holdings counts at its
/// value by them (holdings.dart), every other account at its balance.
library;

import 'balances.dart';
import 'holdings.dart';
import 'model.dart';

/// Your net worth in one currency.
final class NetWorth {
  const NetWorth({
    required this.assetsMinor,
    required this.liabilitiesMinor,
    required this.splitMinor,
    required this.splitCounted,
    required this.accounts,
    this.otherCurrency = const [],
    this.values = const {},
    this.investmentsMinor = 0,
    this.addedSinceMinor = 0,
    this.asOfDay,
    this.staleCount = 0,
  });

  /// What the asset accounts hold (an overdrawn one takes away).
  final int assetsMinor;

  /// What you owe on cards and loans.
  final int liabilitiesMinor;

  /// What friends owe you in Split, net (less than zero when you owe them).
  final int splitMinor;

  /// Whether [splitMinor] is in [totalMinor].
  final bool splitCounted;

  /// The accounts in it, closed ones included, in the order given.
  final List<AccountBalance> accounts;

  /// Accounts in another currency (from before a currency change), left out of the totals.
  final List<AccountBalance> otherCurrency;

  /// What each account of [accounts] and [otherCurrency] is worth, by id, when it was worked out
  /// by value ([valueOf]).
  final Map<String, AccountValue> values;

  /// What your investment accounts are worth (in [assetsMinor]).
  final int investmentsMinor;

  /// Of [investmentsMinor], what was put in since the holdings' valuations, at cost.
  final int addedSinceMinor;

  /// The earliest valuation day of the holdings in it ("as of 15 Aug"), or null with none.
  final int? asOfDay;

  /// Holdings in it with a stale value.
  final int staleCount;

  int get totalMinor => assetsMinor - liabilitiesMinor + (splitCounted ? splitMinor : 0);

  bool get hasAccounts => accounts.isNotEmpty;

  /// What [b]'s account counts for: its value ([values]), else its balance.
  int valueOf(AccountBalance b) => values[b.account.id]?.valueMinor ?? b.balanceMinor;
}

/// Net worth from [balances] in [currency] (closed accounts count, deleted ones don't), plus the
/// Split line ([splitNetMinor]) when [countSplit]. An account in [values] (by id) counts at its
/// [AccountValue.valueMinor], the rest at their balances.
NetWorth netWorth({
  required List<AccountBalance> balances,
  required String currency,
  required int splitNetMinor,
  required bool countSplit,
  Map<String, AccountValue> values = const {},
}) {
  var assets = 0, liabilities = 0, investments = 0, added = 0, stale = 0;
  int? asOf;
  final counted = <AccountBalance>[], other = <AccountBalance>[];
  for (final b in balances) {
    if (b.account.deleted) continue;
    if (b.account.currency != currency) {
      other.add(b);
      continue;
    }
    counted.add(b);
    final v = values[b.account.id];
    final worth = v?.valueMinor ?? b.balanceMinor;
    if (b.account.type.isLiability) {
      liabilities += worth;
    } else {
      assets += worth;
    }
    if (b.account.type != AccountType.investment) continue;
    investments += worth;
    if (v == null || !v.byHoldings) continue;
    added += v.addedSinceMinor;
    stale += v.staleCount;
    if (v.asOfDay case final d? when asOf == null || d < asOf) asOf = d;
  }
  return NetWorth(
    assetsMinor: assets,
    liabilitiesMinor: liabilities,
    splitMinor: splitNetMinor,
    splitCounted: countSplit,
    accounts: List.unmodifiable(counted),
    otherCurrency: List.unmodifiable(other),
    values: values,
    investmentsMinor: investments,
    addedSinceMinor: added,
    asOfDay: asOf,
    staleCount: stale,
  );
}
