import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../clock.dart';
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

/// For answers that come from the server rather than the device: ask again once a sync has
/// sent this device's queued writes, or they'd still show the server's state from before them.
void _afterEachSync(Ref ref) => ref.watch(syncStatusProvider.select((s) => s.value?.lastSyncedAt));

String? _day(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);

final groupsProvider = FutureProvider<List<GroupOut>>((ref) => local(ref, (l) => GroupOut.listFromJson(l.groups())));

final groupProvider = FutureProvider.family<GroupOut, String>(
  (ref, id) => local(ref, (l) => GroupOut.fromJson(l.group(id))),
);

final overallBalancesProvider = FutureProvider<OverallBalancesOut>(
  (ref) => local(ref, (l) => OverallBalancesOut.fromJson(l.overallBalances())),
);

final groupBalancesProvider = FutureProvider.family<GroupBalancesOut, String>(
  (ref, id) => local(ref, (l) => GroupBalancesOut.fromJson(l.groupBalances(id))),
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
  (ref, q) => local(ref, (l) => FeedItem.listFromJson(l.feed(groupId: q.groupId, deleted: q.deleted, limit: q.limit))),
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
  (ref, q) => local(
    ref,
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
  (ref, id) => local(ref, (l) => ExpenseOut.fromJson(l.expense(id))),
);

/// Who changed what, from the audit log. Online only; the detail page shows none offline.
final expenseHistoryProvider = FutureProvider.family<List<HistoryEntry>, String>((ref, id) {
  _afterEachSync(ref);
  return fetch(ref, ref.watch(apiProvider).expenses.expenseHistory(id));
});

final groupCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => local(ref, (l) => CategoryOut.listFromJson(l.categories(scope: 'group'))),
);

/// Settling with a friend in one currency: the groups you share in it.
final settleUpPlanProvider = FutureProvider.family<SettleUpPlanOut, ({String friendId, String currency})>(
  (ref, key) => local(ref, (l) => SettleUpPlanOut.fromJson(l.settleUpPlan(key.friendId, currency: key.currency))),
);

// ---- personal finance & analytics (step 6) ----

/// A calendar month, as its first day.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

final personalSummaryProvider = FutureProvider.family<PersonalSummaryOut, DateTime>(
  (ref, month) => local(ref, (l) => PersonalSummaryOut.fromJson(l.personalSummary(month))),
);

/// History filters. `categories` is a comma-joined, sorted list of keys so the record
/// compares by value.
typedef PersonalQuery = ({DateTime? start, DateTime? end, String? type, String categories, int limit});

final personalListProvider = FutureProvider.family<PersonalListOut, PersonalQuery>(
  (ref, q) => local(
    ref,
    (l) => PersonalListOut.fromJson(
      l.personalList(
        start: _day(q.start),
        end: _day(q.end),
        type: q.type,
        categoryKeys: q.categories.isEmpty ? null : q.categories.split(','),
        limit: q.limit,
      ),
    ),
  ),
);

final personalCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => local(ref, (l) => CategoryOut.listFromJson(l.categories(scope: 'personal'))),
);

final allCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => local(ref, (l) => CategoryOut.listFromJson(l.categories())),
);

/// Personal dashboard for "week", "month" or "year", as of today on this device. Analytics is
/// online only: offline, the page shows the offline card.
final personalDashboardProvider = FutureProvider.family<DashboardOut, String>((ref, period) {
  _afterEachSync(ref);
  return fetch(ref, ref.watch(apiProvider).analytics.personalDashboard(period: period, on_: apiDate(appClock.now())));
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
