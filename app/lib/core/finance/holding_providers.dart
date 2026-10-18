/// What the holdings screens read (core/finance/holdings.dart over Ledger.finance): what each
/// account is worth, the holdings in an investment account, and your investments added up. Each is
/// worked out again only when your entries, accounts, holdings or profile change ([localOn]).
///
/// While Features.holdings is off, no holdings are shown and every account is worth its balance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../integrations.dart';
import '../local/ledger.dart';
import 'finance.dart';
import 'today.dart';

/// Entries, accounts and holdings, and the profile (your currency).
const _reads = {LedgerDomain.personal, LedgerDomain.profile};

/// What each account that isn't deleted is worth today, in accountBalancesProvider's order: an
/// investment account with holdings by them, every other account its balance.
final accountValuesProvider = FutureProvider<List<AccountValue>>((ref) {
  final features = ref.watch(featuresProvider);
  final today = ref.watch(todayProvider);
  return localOn(ref, _reads, (l) => _values(l.finance, features, today));
});

/// The live holdings in account [accountId] today, oldest first: none for an account that isn't
/// an investment account (or is deleted or unknown).
final holdingsOfProvider = FutureProvider.family<List<HoldingView>, String>((ref, accountId) {
  final features = ref.watch(featuresProvider);
  if (!features.holdings) return const [];
  final today = ref.watch(todayProvider);
  return localOn(
    ref,
    _reads,
    (l) => l.finance.holdingsOf(accountId, today: today, staleDays: features.staleValuationDays),
  );
});

/// Your investment accounts in your currency today, valued and added up: Overview's
/// "Investments ₹85,750 · as of 15 Aug" and "1 value is stale".
final investmentsProvider = FutureProvider<Investments>((ref) {
  final features = ref.watch(featuresProvider);
  final today = ref.watch(todayProvider);
  return localOn(
    ref,
    _reads,
    (l) => features.holdings
        ? l.finance.investments(today: today, staleDays: features.staleValuationDays)
        : investmentsOf(_values(l.finance, features, today), currency: l.finance.currency),
  );
});

List<AccountValue> _values(FinanceEngine f, Features features, int today) => features.holdings
    ? f.accountValues(today: today, staleDays: features.staleValuationDays)
    : [
        for (final b in f.balances)
          AccountValue(account: b.account, ledgerMinor: b.balanceMinor, valueMinor: b.balanceMinor),
      ];

