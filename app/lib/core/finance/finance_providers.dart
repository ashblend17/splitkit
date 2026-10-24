/// What the finance screens read from the device's data (core/finance over Ledger.finance): typed
/// answers, never JSON. Each is worked out again only when a part of the data it reads changes
/// ([localOn]), and the flags that shape the answers (core/integrations.dart) are read here, not
/// in the engine.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../categorise/category_rules.dart' show merchantKey;

import '../data/providers.dart';
import '../integrations.dart';
import '../local/ledger.dart';
import '../local/providers.dart';
import 'finance.dart';
import 'today.dart';

/// The finance engine over your accounts and entries: a new one only when they or your profile
/// change (Ledger.finance is handed on otherwise).
final financeEngineProvider = FutureProvider<FinanceEngine>(
  (ref) => localOn(ref, const {LedgerDomain.personal, LedgerDomain.profile}, (l) => l.finance),
);

/// Your accounts that aren't deleted, closed ones too (an entry can still name one), oldest
/// first: what account pickers offer.
final accountsProvider = FutureProvider<List<FinAccount>>(
  (ref) => localOn(ref, const {LedgerDomain.personal}, (l) => l.finance.accounts),
);

/// The balance of each account that isn't deleted, in [accountsProvider]'s order.
final accountBalancesProvider = FutureProvider<List<AccountBalance>>(
  (ref) => localOn(ref, const {LedgerDomain.personal}, (l) => l.finance.balances),
);

/// The cash flow of the month [month] is in (any day of it gives the month; pass [monthOf] so
/// screens share one). Your share of group spending counts while both groupShareInPersonal and
/// groupShareInCashFlow are on. Reads groups (entries linked to a split aren't counted, and the
/// share) and categories (their labels).
final cashFlowProvider = FutureProvider.family<CashFlow, DateTime>((ref, month) {
  final links = ref.watch(integrationsProvider);
  final countGroupShare = links.groupShareInPersonal && links.groupShareInCashFlow;
  final period = monthRange(month.year, month.month);
  return localOn(
    ref,
    personalViews,
    (l) => l.finance.cashFlow(
      period,
      notCounted: l.notCounted,
      groupShareMinor: l.groupShareFor(period),
      countGroupShare: countGroupShare,
      label: l.categoryLabel,
    ),
  );
});

/// Your net worth in your currency, with what friends owe you in Split, net, counted while
/// splitInNetWorth is on (and given either way). An investment account with holdings counts at
/// its value by them while the holdings feature is on.
final netWorthProvider = FutureProvider<NetWorth>((ref) {
  final countSplit = ref.watch(integrationsProvider).splitInNetWorth;
  final features = ref.watch(featuresProvider);
  final today = ref.watch(todayProvider);
  return localOn(
    ref,
    personalLinkViews,
    (l) => l.finance.netWorth(
      splitNetMinor: l.splitNet(l.finance.currency),
      countSplit: countSplit,
      today: today,
      holdings: features.holdings,
      staleDays: features.staleValuationDays,
    ),
  );
});


/// Spends and incomes read from bank SMS that look like one transfer between two of your
/// accounts, newest first, without the pairs you said aren't one ([notTransferProvider]). None
/// while transferSuggestions is off.
final transferSuggestionsProvider = FutureProvider<List<TransferSuggestion>>((ref) async {
  final features = ref.watch(featuresProvider);
  if (!features.transferSuggestions) return const [];
  final window = Duration(minutes: features.transferSuggestionMinutes);
  final dismissed = await ref.watch(notTransferProvider.future);
  return localOn(
    ref,
    _entriesAndGroups,
    (l) => l.finance.transferSuggestions(notCounted: l.notCounted, dismissed: dismissed, window: window),
  );
});

/// Your entries and accounts, and groups: an entry linked to a split isn't a transfer.
const _entriesAndGroups = {LedgerDomain.personal, LedgerDomain.groups};

/// The spend income [txnId] could be money back for (ISS-089): a bank often sends a merchant's
/// refund as a plain credit ("credited … by VPA swiggy.stores@icici"), read as income. One from
/// the same merchant in the 60 days before, with at least this much left to refund
/// ([FinanceEngine.refundTarget]). Only offered, never assumed: a friend paying you back through
/// the same app looks the same.
final refundSuggestionProvider = FutureProvider.family<FinEntry?, String>((ref, txnId) {
  if (!ref.watch(featuresProvider).refunds) return null;
  return localOnOrNull(ref, _entriesAndGroups, (l) {
    final t = l.finance.entry(txnId);
    final merchant = t?.merchant;
    if (t == null || t.deleted || t.txnType != TxnType.income || merchant == null) return null;
    if (t.expenseId != null || t.settlementId != null || l.notCounted.contains(t.id)) return null;
    return l.finance.refundTarget(
      amountMinor: t.amount,
      day: t.day,
      merchantKey: merchantKey(merchant),
      accountId: t.accountId,
    );
  });
});

/// Device-store keys (LocalStore.deviceValue).
abstract final class FinanceKeys {
  /// The [TransferSuggestion.key]s of the pairs you said aren't a transfer, in the order you did.
  static const notTransfer = 'finance.not_transfer';

  /// The [SameAccount.key]s of the accounts you said aren't one account.
  static const notSame = 'finance.not_same';

  /// The ids of the accounts you said aren't a credit card.
  static const notCard = 'finance.not_card';
}

/// The pairs you said aren't a transfer ("Not a transfer"), as [TransferSuggestion.key]s, so
/// they aren't offered again. Kept on this device only, like its bank SMS settings: "Reload from
/// server" keeps them, signing out forgets them.
final notTransferProvider = AsyncNotifierProvider<NotTransferPairs, Set<String>>(NotTransferPairs.new);

class NotTransferPairs extends DismissedKeys {
  @override
  String get storeKey => FinanceKeys.notTransfer;

  /// "Not a transfer": [suggestion] isn't offered again on this device.
  Future<void> dismiss(TransferSuggestion suggestion) => dismissKey(suggestion.key);
}

/// The accounts you said aren't one ("Not the same"), as [SameAccount.key]s; kept as
/// [notTransferProvider] is.
final notSameAccountProvider = AsyncNotifierProvider<NotSameAccounts, Set<String>>(NotSameAccounts.new);

class NotSameAccounts extends DismissedKeys {
  @override
  String get storeKey => FinanceKeys.notSame;

  Future<void> dismiss(SameAccount pair) => dismissKey(pair.key);
}

/// The accounts you said aren't a credit card ("It's a bank account"); kept as
/// [notTransferProvider] is.
final notCardProvider = AsyncNotifierProvider<NotCards, Set<String>>(NotCards.new);

class NotCards extends DismissedKeys {
  @override
  String get storeKey => FinanceKeys.notCard;

  Future<void> dismiss(LooksLikeCard card) => dismissKey(card.account.id);
}

/// Keys of suggestions you turned down, kept in the device store under [storeKey].
abstract class DismissedKeys extends AsyncNotifier<Set<String>> {
  String get storeKey;

  @override
  Future<Set<String>> build() async {
    final store = await ref.watch(localStoreProvider.future);
    final saved = await store.deviceValue(storeKey);
    return Set.unmodifiable(saved is List ? saved.cast<String>() : const <String>[]);
  }

  /// [key] isn't offered again on this device.
  Future<void> dismissKey(String key) async {
    final store = await ref.read(localStoreProvider.future);
    final before = state.value ?? await future;
    if (before.contains(key)) return;
    // Shown at once; saved after, with whatever else was dismissed meanwhile.
    final after = Set<String>.unmodifiable({...state.value ?? before, key});
    state = AsyncData(after);
    await store.setDeviceValue(storeKey, after.toList());
  }
}

/// Pairs of your accounts that look like one account (sameAccounts in account_links.dart), less
/// those you said aren't ([notSameAccountProvider]): Accounts offers to link them.
final sameAccountsProvider = FutureProvider<List<SameAccount>>((ref) async {
  final dismissed = await ref.watch(notSameAccountProvider.future);
  return localOn(ref, const {LedgerDomain.personal}, (l) => sameAccounts(l.finance.balances, dismissed: dismissed));
});

/// Bank accounts a credit card's messages went into (looksLikeCards), less those you said aren't
/// one ([notCardProvider]): Accounts offers to make them credit cards.
final looksLikeCardsProvider = FutureProvider<List<LooksLikeCard>>((ref) async {
  final dismissed = await ref.watch(notCardProvider.future);
  return localOn(ref, const {LedgerDomain.personal}, (l) {
    final f = l.finance;
    return [
      for (final c in looksLikeCards(f.balances, f.creditCardLabelIn))
        if (!dismissed.contains(c.account.id)) c,
    ];
  });
});
