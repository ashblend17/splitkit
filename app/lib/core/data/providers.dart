import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../api/api.dart';
import '../session/session.dart';

/// Awaits an API call. A 401 ends the session (the router then shows Login); a null body
/// is treated as an error.
Future<T> fetch<T>(Ref ref, Future<T?> request) async {
  try {
    final result = await request;
    if (result == null) throw ApiException(500, 'Empty response');
    return result;
  } on ApiException catch (e) {
    if (e.code == 401) await ref.read(sessionProvider.notifier).logout();
    rethrow;
  }
}

final groupsProvider = FutureProvider<List<GroupOut>>((ref) => fetch(ref, ref.watch(apiProvider).groups.listGroups()));

final groupProvider = FutureProvider.family<GroupOut, String>(
  (ref, id) => fetch(ref, ref.watch(apiProvider).groups.getGroup(id)),
);

final overallBalancesProvider = FutureProvider<OverallBalancesOut>(
  (ref) => fetch(ref, ref.watch(apiProvider).balances.overallBalances()),
);

final groupBalancesProvider = FutureProvider.family<GroupBalancesOut, String>(
  (ref, id) => fetch(ref, ref.watch(apiProvider).balances.groupBalances(id)),
);

/// Activity, newest first. `groupId` null means every group; `deleted` lists the trash.
typedef FeedQuery = ({String? groupId, bool deleted});

final feedProvider = FutureProvider.family<List<FeedItem>, FeedQuery>(
  (ref, q) => fetch(ref, ref.watch(apiProvider).balances.feed(groupId: q.groupId, deleted: q.deleted, limit: 100)),
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
});

final activityProvider = FutureProvider.family<List<FeedItem>, ActivityQuery>(
  (ref, q) => fetch(
    ref,
    ref
        .watch(apiProvider)
        .balances
        .feed(
          groupId: q.groupId,
          category: q.category,
          start: q.start == null ? null : apiDate(q.start!),
          end: q.end == null ? null : apiDate(q.end!),
          unsettled: q.unsettled ? true : null,
          q: q.search.isEmpty ? null : q.search,
          limit: 100,
        ),
  ),
);

final expenseProvider = FutureProvider.family<ExpenseOut, String>(
  (ref, id) => fetch(ref, ref.watch(apiProvider).expenses.getExpense(id)),
);

final expenseHistoryProvider = FutureProvider.family<List<HistoryEntry>, String>(
  (ref, id) => fetch(ref, ref.watch(apiProvider).expenses.expenseHistory(id)),
);

final groupCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => fetch(ref, ref.watch(apiProvider).categories.listCategories(scope: 'group')),
);

final settleUpPlanProvider = FutureProvider.family<SettleUpPlanOut, String>(
  (ref, friendId) => fetch(ref, ref.watch(apiProvider).settlements.settleUpPlan(friendId)),
);

// ---- personal finance & analytics (step 6) ----

/// A calendar month, as its first day.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

final personalSummaryProvider = FutureProvider.family<PersonalSummaryOut, DateTime>(
  (ref, month) => fetch(ref, ref.watch(apiProvider).personal.personalSummary(month: apiDate(month))),
);

/// History filters. `categories` is a comma-joined, sorted list of keys so the record
/// compares by value.
typedef PersonalQuery = ({DateTime? start, DateTime? end, String? type, String categories, int limit});

final personalListProvider = FutureProvider.family<PersonalListOut, PersonalQuery>(
  (ref, q) => fetch(
    ref,
    ref
        .watch(apiProvider)
        .personal
        .listPersonal(
          start: q.start == null ? null : apiDate(q.start!),
          end: q.end == null ? null : apiDate(q.end!),
          type: q.type,
          category: q.categories.isEmpty ? null : q.categories.split(','),
          limit: q.limit,
        ),
  ),
);

final personalCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => fetch(ref, ref.watch(apiProvider).categories.listCategories(scope: 'personal')),
);

final allCategoriesProvider = FutureProvider<List<CategoryOut>>(
  (ref) => fetch(ref, ref.watch(apiProvider).categories.listCategories()),
);

/// Personal dashboard for "week", "month" or "year", as of today on this device.
final personalDashboardProvider = FutureProvider.family<DashboardOut, String>(
  (ref, period) =>
      fetch(ref, ref.watch(apiProvider).analytics.personalDashboard(period: period, on_: apiDate(DateTime.now()))),
);

final groupDashboardProvider = FutureProvider.family<DashboardOut, String>(
  (ref, groupId) => fetch(ref, ref.watch(apiProvider).analytics.groupDashboard(groupId, on_: apiDate(DateTime.now()))),
);

final layoutProvider = FutureProvider.family<LayoutOut, String>(
  (ref, scope) => fetch(ref, ref.watch(apiProvider).analytics.getLayout(scope)),
);

/// After a personal write: summaries, lists and dashboards are stale.
void refreshPersonal(void Function(ProviderOrFamily provider) invalidate) {
  for (final p in <ProviderOrFamily>[personalSummaryProvider, personalListProvider, personalDashboardProvider]) {
    invalidate(p);
  }
}

/// After any write everything derived from expenses and settlements is stale.
/// Usage: `refreshLedger(ref.invalidate)` from a widget or provider.
void refreshLedger(void Function(ProviderOrFamily provider) invalidate) {
  for (final p in <ProviderOrFamily>[
    groupsProvider,
    groupProvider,
    overallBalancesProvider,
    groupBalancesProvider,
    feedProvider,
    activityProvider,
    expenseProvider,
    expenseHistoryProvider,
    settleUpPlanProvider,
    groupDashboardProvider,
    personalSummaryProvider,
    personalDashboardProvider,
  ]) {
    invalidate(p);
  }
}
