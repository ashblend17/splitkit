import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';

enum ActivityPeriod {
  any('Any time'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last3Months('Last 3 months');

  const ActivityPeriod(this.label);
  final String label;

  /// First and last day covered, or nulls for any time.
  (DateTime?, DateTime?) range(DateTime today) => switch (this) {
    any => (null, null),
    thisMonth => (DateTime(today.year, today.month), null),
    lastMonth => (DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0)),
    last3Months => (DateTime(today.year, today.month - 2), null),
  };
}

/// Home's activity filters. They live above the page so they stay put while you switch
/// tabs or resize the window. Phones and tablets only use [groupId]; the desktop toolbar
/// uses all of them.
class ActivityFilters {
  const ActivityFilters({
    this.groupId,
    this.category,
    this.period = ActivityPeriod.any,
    this.unsettled = false,
    this.search = '',
  });

  final String? groupId;
  final String? category;
  final ActivityPeriod period;
  final bool unsettled;
  final String search;

  bool get narrowed => groupId != null || category != null || period != ActivityPeriod.any || unsettled;

  ActivityQuery query(DateTime today) {
    final (start, end) = period.range(today);
    return (groupId: groupId, category: category, start: start, end: end, unsettled: unsettled, search: search.trim());
  }

  ActivityFilters withGroup(String? id) =>
      ActivityFilters(groupId: id, category: category, period: period, unsettled: unsettled, search: search);
  ActivityFilters withCategory(String? key) =>
      ActivityFilters(groupId: groupId, category: key, period: period, unsettled: unsettled, search: search);
  ActivityFilters withPeriod(ActivityPeriod p) =>
      ActivityFilters(groupId: groupId, category: category, period: p, unsettled: unsettled, search: search);
  ActivityFilters withUnsettled(bool on) =>
      ActivityFilters(groupId: groupId, category: category, period: period, unsettled: on, search: search);
  ActivityFilters withSearch(String text) =>
      ActivityFilters(groupId: groupId, category: category, period: period, unsettled: unsettled, search: text);
}

class ActivityFiltersNotifier extends Notifier<ActivityFilters> {
  @override
  ActivityFilters build() => const ActivityFilters();

  void change(ActivityFilters Function(ActivityFilters f) edit) => state = edit(state);

  void clear() => state = ActivityFilters(search: state.search);
}

final activityFiltersProvider = NotifierProvider<ActivityFiltersNotifier, ActivityFilters>(ActivityFiltersNotifier.new);
