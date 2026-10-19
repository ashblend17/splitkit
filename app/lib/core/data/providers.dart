import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../clock.dart';
import '../categorise/category_guesser.dart';
import '../integrations.dart';
import '../local/ledger.dart';
import '../local/providers.dart';
import '../session/session.dart';

/// Awaits an API call. A 401 ends the session (the router then shows Login); a null body
/// is treated as an error. Only analytics, layouts and expense history still come from the
/// network; everything else is read from the device ([local]).
Future<T> fetch<T>(Ref ref, Future<T?> request) async {
  try {
    final result = await request;
    if (result == null) throw ApiException(500, 'Empty response');
    return result;
  } on ApiException catch (e) {
    if (e.code == 401) await ref.read(sessionProvider.notifier).expire();
    rethrow;
  }
}

/// An answer computed from the synced data on this device (see core/local/ledger.dart). Screens
/// see the same models, and the same 404 for something they can't have, as from the API.
Future<T> local<T>(Ref ref, T? Function(Ledger ledger) view) async {
  final watched = await ref.watch(ledgerProvider.future); // asked again when the data changes
  // The store's own ledger is current the moment a write is queued; ledgerProvider only
  // catches up on its next event. Reading it means a screen opened right after a write
  // (a new group) finds what was just written. Read without awaiting: an await here would
  // let the next event cancel this answer before anyone gets it.
  final ledger = ref.read(localStoreProvider).value?.ledger ?? watched;
  try {
    final result = view(ledger);
    if (result == null) throw ApiException(500, 'Could not read this from the device');
    return result;
  } on LocalNotFound catch (e) {
    throw ApiException(404, jsonEncode({'error': {'code': 'not_found', 'message': '$e'}}));
  }
}

/// [local] for an answer that can be nothing.
Future<T?> localOrNull<T>(Ref ref, T? Function(Ledger ledger) view) async => (await local(ref, (l) => (view(l),))).$1;

/// [local] for a view that reads only some parts of the data ([reads]): asked again when one of
/// them changes, not on every change (a personal entry doesn't redo Home). It waits for the
/// first data and fails like [local], 404 included.
Future<T> localOn<T>(Ref ref, Set<LedgerDomain> reads, T? Function(Ledger ledger) view) async {
  // Before the first data, wait for it without being asked again when it arrives (that would
  // work the view out twice), but keep it coming. If it fails, the lines below report that.
  final first = ref.read(ledgerProvider);
  if (!first.hasValue && !first.hasError) {
    ref.listen(ledgerProvider, (_, _) {});
    await ref.read(ledgerProvider.future).then((_) {}, onError: (_) {});
  }
  // Then asked again when the data fails, or when a part this view reads changes; not when
  // only other parts change, or when it's reloaded to the same data.
  ref.watch(ledgerProvider.select((v) => v.hasError ? v.error : v.value?.revisions.of(reads)));
  final watched = await ref.read(ledgerProvider.future);
  // As in [local]: the store's own ledger already shows a write made a moment ago.
  final ledger = ref.read(localStoreProvider).value?.ledger ?? watched;
  try {
    final result = view(ledger);
    if (result == null) throw ApiException(500, 'Could not read this from the device');
    return result;
  } on LocalNotFound catch (e) {
    throw ApiException(404, jsonEncode({'error': {'code': 'not_found', 'message': '$e'}}));
  }
}

/// [localOn] for an answer that can be nothing.
Future<T?> localOnOrNull<T>(Ref ref, Set<LedgerDomain> reads, T? Function(Ledger ledger) view) async =>
    (await localOn(ref, reads, (l) => (view(l),))).$1;

/// What the views read ([localOn]). Groups views name people from the groups' members and you
/// from your profile. Personal views also read groups: an entry linked to a split isn't counted,
/// and the summary adds your share of group spending. An expense carries its own category.
const groupViews = {LedgerDomain.groups, LedgerDomain.profile};
const categoryViews = {LedgerDomain.categories, LedgerDomain.profile};
const personalViews = {LedgerDomain.personal, LedgerDomain.categories, LedgerDomain.groups, LedgerDomain.profile};

/// Personal views that show splits or payments but no categories.
const personalLinkViews = {LedgerDomain.personal, LedgerDomain.groups, LedgerDomain.profile};

/// For answers that come from the server rather than the device: ask again once a sync has
/// sent this device's queued writes, or they'd still show the server's state from before them.
void _afterEachSync(Ref ref) => ref.watch(syncStatusProvider.select((s) => s.value?.lastSyncedAt));

String? _day(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);

final groupsProvider = FutureProvider<List<GroupOut>>(
  (ref) => localOn(ref, groupViews, (l) => GroupOut.listFromJson(l.groups())),
);

final archivedGroupsProvider = FutureProvider<List<GroupOut>>(
  (ref) => localOn(ref, groupViews, (l) => GroupOut.listFromJson(l.groups(archived: true))),
);

final groupProvider = FutureProvider.family<GroupOut, String>(
  (ref, id) => localOn(ref, groupViews, (l) => GroupOut.fromJson(l.group(id))),
);

final overallBalancesProvider = FutureProvider<OverallBalancesOut>(
  (ref) => localOn(ref, groupViews, (l) => OverallBalancesOut.fromJson(l.overallBalances())),
);

final groupBalancesProvider = FutureProvider.family<GroupBalancesOut, String>(
  (ref, id) => localOn(ref, groupViews, (l) => GroupBalancesOut.fromJson(l.groupBalances(id))),
);

/// Rows a feed list shows at first; "Show older" adds as many again.
const feedPage = 100;

/// How many rows each feed list shows, by list: `home`, `activity`, `group:<id>`, `trash:<id>`.
final feedLimitProvider = NotifierProvider.family<FeedLimit, int, String>(FeedLimit.new);

class FeedLimit extends Notifier<int> {
  FeedLimit(this.list);
  final String list;

  @override
  int build() => feedPage;

  void more() => state += feedPage;
}

/// Activity, newest first. `groupId` null means every group; `deleted` lists the trash.
typedef FeedQuery = ({String? groupId, bool deleted, int limit});

final feedProvider = FutureProvider.family<List<FeedItem>, FeedQuery>(
  (ref, q) => localOn(
    ref,
    groupViews,
    (l) => FeedItem.listFromJson(l.feed(groupId: q.groupId, deleted: q.deleted, limit: q.limit)),
  ),
);

/// The desktop activity table: [FeedQuery] plus the toolbar filters. `search` is trimmed;
/// empty means no search.
typedef ActivityQuery = ({
  String? groupId,
  String? category,
  DateTime? start,
  DateTime? end,
  bool unsettled,
  String search,
  int limit,
});

final activityProvider = FutureProvider.family<List<FeedItem>, ActivityQuery>(
  (ref, q) => localOn(
    ref,
    groupViews,
    (l) => FeedItem.listFromJson(
      l.feed(
        groupId: q.groupId,
        filters: FeedFilters(
          category: q.category,
          start: _day(q.start),
          end: _day(q.end),
          openOnly: q.unsettled,
          search: q.search.isEmpty ? null : q.search,
        ),
        limit: q.limit,
      ),
    ),
  ),
);

final expenseProvider = FutureProvider.family<ExpenseOut, String>(
  (ref, id) => localOn(ref, groupViews, (l) => ExpenseOut.fromJson(l.expense(id))),
);

/// Who changed what, from the audit log. Online only; the detail page shows none offline.
final expenseHistoryProvider = FutureProvider.family<List<HistoryEntry>, String>((ref, id) {
  _afterEachSync(ref);
  return fetch(ref, ref.watch(apiProvider).expenses.expenseHistory(id));
});

final groupCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => localOn(ref, categoryViews, (l) => CategoryOut.listFromJson(l.categories(scope: 'group'))),
);

/// Settling with a friend in one currency: the groups you share in it.
final settleUpPlanProvider = FutureProvider.family<SettleUpPlanOut, ({String friendId, String currency})>(
  (ref, key) => localOn(
    ref,
    groupViews,
    (l) => SettleUpPlanOut.fromJson(l.settleUpPlan(key.friendId, currency: key.currency)),
  ),
);

// ---- personal finance & analytics (step 6) ----

/// A calendar month, as its first day.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

final personalSummaryProvider = FutureProvider.family<PersonalSummaryOut, DateTime>(
  (ref, month) => localOn(ref, personalViews, (l) => PersonalSummaryOut.fromJson(l.personalSummary(month))),
);

/// Personal list filters, compared by value (they key the provider).
class PersonalQuery {
  const PersonalQuery({
    this.start,
    this.end,
    this.type,
    this.categories = '',
    this.limit = 100,
    this.account,
    this.accountId,
    this.channel,
    this.source,
    this.reviewed,
  });

  final DateTime? start;
  final DateTime? end;
  final String? type;

  /// Category keys, comma-joined and sorted.
  final String categories;
  final int limit;

  /// A bank SMS label ("HDFC ··4821"): entries that carry it.
  final String? account;

  /// One of your accounts: the entries in it.
  final String? accountId;
  final String? channel;
  final String? source;
  final bool? reviewed;

  Object get _key => (start, end, type, categories, limit, account, accountId, channel, source, reviewed);

  @override
  bool operator ==(Object other) => other is PersonalQuery && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

final personalListProvider = FutureProvider.family<PersonalListOut, PersonalQuery>(
  (ref, q) => localOn(
    ref,
    personalViews,
    (l) => PersonalListOut.fromJson(
      l.personalList(
        start: _day(q.start),
        end: _day(q.end),
        type: q.type,
        categoryKeys: q.categories.isEmpty ? null : q.categories.split(','),
        account: q.account,
        accountId: q.accountId,
        channel: q.channel,
        source: q.source,
        reviewed: q.reviewed,
        limit: q.limit,
      ),
    ),
  ),
);

final personalTxnProvider = FutureProvider.family<PersonalTxnOut, String>(
  (ref, id) => localOn(ref, personalViews, (l) => PersonalTxnOut.fromJson(l.personalTransaction(id))),
);

/// Splits you paid that could be the same spend as an entry ("Already split").
final linkCandidatesProvider = FutureProvider.family<List<ExpenseOut>, String>(
  (ref, txnId) => localOn(
    ref,
    personalLinkViews,
    (l) => ExpenseOut.listFromJson(l.linkCandidates(txnId, windowDays: ref.watch(integrationsProvider).linkWindowDays)),
  ),
);

/// Your entry linked to an expense, if any: shown on the expense to you only.
final personalLinkedToProvider = FutureProvider.family<PersonalTxnOut?, String>(
  (ref, expenseId) => localOnOrNull(ref, personalViews, (l) => PersonalTxnOut.fromJson(l.personalLinkedTo(expenseId))),
);

/// Who you paid (or were paid by) the last time an entry from this merchant was a payment.
final friendPaidBeforeProvider = FutureProvider.family<String?, String>(
  (ref, merchant) => localOnOrNull(ref, personalLinkViews, (l) => l.friendPaidBefore(merchant)),
);

/// What an entry became in Split, if anything.
final personalLinkProvider = FutureProvider.family<PersonalLink?, String>(
  (ref, txnId) => localOnOrNull(ref, personalLinkViews, (l) => l.personalLink(txnId)),
);

/// A category for what's being typed into a personal entry ([scope] "personal") or a split
/// ("group"), as core/categorise/category_guesser.dart picks it; null when nothing fits or
/// suggestions are off. Reads the device's data as it is now, without waiting.
String? suggestCategory(WidgetRef ref, String text, {required String scope, bool income = false}) {
  final features = ref.read(featuresProvider);
  final ledger = ref.read(localStoreProvider).value?.ledger;
  if (!features.suggestCategories || ledger == null || ledger.isEmpty || text.trim().isEmpty) return null;
  return categoryFor(ledger, text, scope: scope, income: income, learn: features.learnCategories);
}

/// The accounts and cards your entries went through, with their latest balance.
final personalAccountsProvider = FutureProvider<List<AccountOut>>(
  (ref) => localOn(ref, {LedgerDomain.personal}, (l) => AccountOut.listFromJson(l.personalReportedAccounts())),
);

final personalCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => localOn(ref, categoryViews, (l) => CategoryOut.listFromJson(l.categories(scope: 'personal'))),
);

final allCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => localOn(ref, categoryViews, (l) => CategoryOut.listFromJson(l.categories())),
);

/// Personal dashboard for "week", "month" or "year", as of today on this device. Analytics is
/// online only: offline, the page shows the offline card. Its spending counts your share of
/// group expenses exactly when Overview's cash flow does ([cashFlowProvider]).
final personalDashboardProvider = FutureProvider.family<DashboardOut, String>((ref, period) {
  _afterEachSync(ref);
  final links = ref.watch(integrationsProvider);
  return fetch(
    ref,
    ref
        .watch(apiProvider)
        .analytics
        .personalDashboard(
          period: period,
          on_: apiDate(appClock.now()),
          groupShare: links.groupShareInPersonal && links.groupShareInCashFlow,
        ),
  );
});

final groupDashboardProvider = FutureProvider.family<DashboardOut, String>((ref, groupId) {
  _afterEachSync(ref);
  return fetch(ref, ref.watch(apiProvider).analytics.groupDashboard(groupId, on_: apiDate(appClock.now())));
});

final layoutProvider = FutureProvider.family<LayoutOut, String>(
  (ref, scope) => fetch(ref, ref.watch(apiProvider).analytics.getLayout(scope)),
);

/// After a personal write: sync now; the online dashboards are stale too.
void refreshPersonal(void Function(ProviderOrFamily provider) invalidate) {
  for (final p in <ProviderOrFamily>[ledgerProvider, personalDashboardProvider]) {
    invalidate(p);
  }
}

/// After any write (or on pull-to-refresh): sync now. Everything read from the device updates
/// when the sync lands; the online-only answers are fetched again.
/// Usage: `refreshLedger(ref.invalidate)` from a widget or provider.
void refreshLedger(void Function(ProviderOrFamily provider) invalidate) {
  for (final p in <ProviderOrFamily>[
    ledgerProvider,
    expenseHistoryProvider,
    groupDashboardProvider,
    personalDashboardProvider,
  ]) {
    invalidate(p);
  }
}
