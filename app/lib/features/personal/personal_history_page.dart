import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/integrations.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'personal_txn_sheet.dart';

/// Screen 12, Personal's Transactions tab: filter by dates, type and category; totals;
/// entries grouped by day.
class PersonalHistoryPage extends ConsumerStatefulWidget {
  const PersonalHistoryPage({super.key, this.account});

  /// Start filtered to this account.
  final String? account;

  @override
  ConsumerState<PersonalHistoryPage> createState() => _PersonalHistoryPageState();
}

class _PersonalHistoryPageState extends ConsumerState<PersonalHistoryPage> {
  late DateTime _start = DateTime(appClock.now().year, appClock.now().month);
  DateTime _end = appClock.now();
  String? _type = 'expense';
  Set<String> _categories = {};
  late String? _account = widget.account;
  String? _channel;

  @override
  void didUpdateWidget(PersonalHistoryPage old) {
    super.didUpdateWidget(old);
    // The tab keeps its page, so a link to another account arrives here.
    if (widget.account != old.account) _account = widget.account;
  }

  static const _types = {'expense': 'Expenses only', 'income': 'Income only', null: 'Everything'};

  PersonalQuery get _query {
    final keys = _categories.toList()..sort();
    return PersonalQuery(
      start: _start,
      end: _end,
      type: _type,
      categories: keys.join(','),
      account: _account,
      channel: _channel,
      limit: 500,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final list = ref.watch(personalListProvider(_query));
    final categories = ref.watch(personalCategoriesProvider);
    final accounts = ref.watch(featuresProvider).breakdownFilters
        ? ref.watch(personalAccountsProvider).value ?? const <AccountOut>[]
        : null;
    final days =
        DateTime(_end.year, _end.month, _end.day).difference(DateTime(_start.year, _start.month, _start.day)).inDays +
        1;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Room at the bottom for the floating "Add entry".
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text('Transactions', style: SkText.title)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _filterButton(
                        icon: 'calendar',
                        label: DateSelector.rangeLabel(_start, _end),
                        strong: true,
                        onTap: _pickRange,
                      ),
                      const SizedBox(width: 8),
                      _filterButton(label: _types[_type]!, trailing: 'down', onTap: _pickType),
                    ],
                  ),
                  if (accounts != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (accounts.isNotEmpty || _account != null)
                          _filterButton(
                            label: _account ?? 'All accounts',
                            trailing: 'down',
                            strong: _account != null,
                            onTap: () => _pick(
                              'Account',
                              {null: 'All accounts', for (final a in accounts) a.account: a.account},
                              _account,
                              (v) => _account = v,
                            ),
                          ),
                        _filterButton(
                          label: channelLabels[_channel] ?? 'Any way paid',
                          trailing: 'down',
                          strong: _channel != null,
                          onTap: () => _pick('Paid with', {null: 'Any way paid', ...channelLabels}, _channel, (v) => _channel = v),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  AsyncBody(
                    value: categories,
                    onRetry: () => ref.invalidate(personalCategoriesProvider),
                    skeletonRows: 1,
                    builder: (cats) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip('All', _categories.isEmpty, () => setState(() => _categories = {})),
                          for (final c in cats.where(
                            (c) => _type == 'income' ? c.key == 'income' || c.ownerId != null : c.key != 'income',
                          ))
                            _chip(
                              c.label,
                              _categories.contains(c.key),
                              () => setState(
                                () => _categories = _categories.contains(c.key)
                                    ? ({..._categories}..remove(c.key))
                                    : {..._categories, c.key},
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AsyncBody(
                    value: list,
                    onRetry: () => ref.invalidate(personalListProvider),
                    builder: (l) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _totals(l, me.currency, days),
                        const SizedBox(height: 14),
                        if (l.items.isEmpty)
                          const EmptyState(
                            glyph: 'wallet',
                            title: 'Nothing in this range',
                            body: 'Try other dates or categories.',
                          )
                        else
                          ..._dayGroups(l.items),
                        if (l.items.length < l.count)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Showing the newest ${l.items.length} of ${l.count}. Pick a shorter range to see the rest.',
                              style: SkText.body(13, 400, color: SkColors.ink2),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton({
    String? icon,
    required String label,
    String? trailing,
    bool strong = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: SkColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: strong ? SkColors.ink : SkColors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[SkIcon(icon, size: 16), const SizedBox(width: 6)],
                Text(label, style: SkText.body(13, strong ? 700 : 600)),
                if (trailing != null) ...[const SizedBox(width: 6), SkIcon(trailing, size: 14)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? SkColors.personalSoft : SkColors.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? SkColors.personal : SkColors.line, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(label, style: SkText.body(13, 600, color: on ? SkColors.personalInk : SkColors.ink)),
          ),
        ),
      ),
    ),
  );

  Widget _totals(PersonalListOut l, String currency, int days) {
    final total = _type == 'income' ? l.incomeMinor : l.spentMinor;
    Widget figure(String label, String value, {int weight = 700}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SkText.body(12, 400, color: SkColors.ink2)),
          const SizedBox(height: 2),
          Text(value, style: SkText.display(18, weight)),
        ],
      ),
    );
    return SkCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          figure(_type == 'income' ? 'Income' : 'Total', money(total, currency), weight: 800),
          const SizedBox(width: 8),
          figure('Transactions', '${l.count}'),
          const SizedBox(width: 8),
          figure('Per day', money(days <= 0 ? 0 : ((total / days) / 100).round() * 100, currency)),
        ],
      ),
    );
  }

  List<Widget> _dayGroups(List<PersonalTxnOut> items) {
    final byDay = <DateTime, List<PersonalTxnOut>>{};
    for (final t in items) {
      byDay.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    return [
      for (final MapEntry(key: day, value: list) in byDay.entries) ...[
        Container(
          decoration: BoxDecoration(
            color: SkColors.surface,
            borderRadius: BorderRadius.circular(SkRadius.card),
            border: Border.all(color: SkColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: SkPalette.tableHead,
                  border: Border(bottom: BorderSide(color: SkColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(dayLabel(day), style: SkText.body(13, 700))),
                    Text(_dayTotal(list), style: SkText.body(13, 400, color: SkColors.ink2)),
                  ],
                ),
              ),
              for (final (i, t) in list.indexed) _row(t, last: i == list.length - 1),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// Like the totals: entries that became a split or a payment aren't counted.
  String _dayTotal(List<PersonalTxnOut> list) {
    final counted = list.where((t) => t.counted);
    if (counted.isEmpty) return 'Not counted';
    final spent = counted.where((t) => t.type == PersonalTxnOutTypeEnum.expense).fold(0, (a, t) => a + t.amountMinor);
    final income = counted.where((t) => t.type == PersonalTxnOutTypeEnum.income).fold(0, (a, t) => a + t.amountMinor);
    final c = list.first.currency;
    if (spent > 0 && income > 0) return '${money(spent, c)} out · ${money(income, c)} in';
    return income > 0 ? '+${money(income, c)}' : money(spent, c);
  }

  Widget _row(PersonalTxnOut t, {required bool last}) {
    final income = t.type == PersonalTxnOutTypeEnum.income;
    return InkWell(
      onTap: () => showPersonalTxnSheet(context, existing: t),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: SkPalette.divider)),
        ),
        child: Row(
          children: [
            IconTile(
              glyphOr(t.category?.icon, income ? 'income' : 'other'),
              background: SkColors.personalSoft,
              foreground: SkColors.personalInk,
              size: 36,
              radius: 10,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.description, style: SkText.body(15, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [?categoryLabel(t), ?notCounted(t)].join(' · '),
                    style: SkText.body(12, 400, color: SkColors.ink2),
                  ),
                ],
              ),
            ),
            Text(
              income ? '+${money(t.amountMinor, t.currency)}' : money(t.amountMinor, t.currency),
              style: SkText.display(
                16,
                700,
                color: !t.counted
                    ? SkColors.ink3
                    : income
                    ? SkColors.owed
                    : SkColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: appClock.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
    }
  }

  /// One of [options] (value: label; null is "any"), set with [set].
  Future<void> _pick(String title, Map<String?, String> options, String? current, void Function(String?) set) async {
    final picked = await showAppBottomSheet<(String?,)>(
      context,
      title: title,
      child: Column(
        children: [
          for (final MapEntry(:key, :value) in options.entries)
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop((key,)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Expanded(child: Text(value, style: SkText.body(15, 600))),
                      if (current == key) SkIcon('check', size: 20, color: SkColors.personal),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => set(picked.$1));
  }

  Future<void> _pickType() async {
    final picked = await showAppBottomSheet<String>(
      context,
      title: 'Show',
      child: Column(
        children: [
          for (final MapEntry(:key, :value) in _types.entries)
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(key ?? 'all'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Expanded(child: Text(value, style: SkText.body(15, 600))),
                      if (_type == key) SkIcon('check', size: 20, color: SkColors.personal),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _type = picked == 'all' ? null : picked;
        _categories = {};
      });
    }
  }
}
