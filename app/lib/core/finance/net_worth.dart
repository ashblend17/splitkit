/// Net worth: what your accounts hold, less what you owe on cards and loans, and (when that's
/// counted) what friends owe you in Split, net.
library;

import 'balances.dart';

/// Your net worth in one currency.
final class NetWorth {
  const NetWorth({
    required this.assetsMinor,
    required this.liabilitiesMinor,
    required this.splitMinor,
    required this.splitCounted,
    required this.accounts,
    this.otherCurrency = const [],
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

  int get totalMinor => assetsMinor - liabilitiesMinor + (splitCounted ? splitMinor : 0);

  bool get hasAccounts => accounts.isNotEmpty;
}

/// Net worth from [balances] in [currency] (closed accounts count, deleted ones don't), plus the
/// Split line ([splitNetMinor]) when [countSplit].
NetWorth netWorth({
  required List<AccountBalance> balances,
  required String currency,
  required int splitNetMinor,
  required bool countSplit,
}) {
  var assets = 0, liabilities = 0;
  final counted = <AccountBalance>[], other = <AccountBalance>[];
  for (final b in balances) {
    if (b.account.deleted) continue;
    if (b.account.currency != currency) {
      other.add(b);
      continue;
    }
    counted.add(b);
    if (b.account.type.isLiability) {
      liabilities += b.balanceMinor;
    } else {
      assets += b.balanceMinor;
    }
  }
  return NetWorth(
    assetsMinor: assets,
    liabilitiesMinor: liabilities,
    splitMinor: splitNetMinor,
    splitCounted: countSplit,
    accounts: List.unmodifiable(counted),
    otherCurrency: List.unmodifiable(other),
  );
}
