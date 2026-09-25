import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'personal_txn_sheet.dart';

/// Screen 12: filter by dates, type and category; totals; entries grouped by day.
class PersonalHistoryPage extends ConsumerStatefulWidget {
  const PersonalHistoryPage({super.key});

  @override
  ConsumerState<PersonalHistoryPage> createState() => _PersonalHistoryPageState();
}

class _PersonalHistoryPageState extends ConsumerState<PersonalHistoryPage> {
  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _end = DateTime.now();
  String? _type = 'expense';
  Set<String> _categories = {};

  static const _types = {'expense': 'Expenses only', 'income': 'Income only', null: 'Everything'};

  PersonalQuery get _query {
    final keys = _categories.toList()..sort();
    return (start: _start, end: _end, type: _type, categories: keys.join(','), limit: 500);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final list = ref.watch(personalListProvider(_query));
    final categories = ref.watch(personalCategoriesProvider);
    final days =
        DateTime(_end.year, _end.month, _end.day).difference(DateTime(_start.year, _start.month, _start.day)).inDays +
        1;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back',
                            onPressed: () => context.canPop() ? context.pop() : context.go('/personal'),
                          ),
                        ),
                        Semantics(header: true, child: Text('Spending history', style: SkText.display(20, 700))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF9F6),
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

  String _dayTotal(List<PersonalTxnOut> list) {
    final spent = list.where((t) => t.type == PersonalTxnOutTypeEnum.expense).fold(0, (a, t) => a + t.amountMinor);
    final income = list.where((t) => t.type == PersonalTxnOutTypeEnum.income).fold(0, (a, t) => a + t.amountMinor);
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
          border: last ? null : const Border(bottom: BorderSide(color: SkPalette.divider)),
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
                    t.category?.label ?? (income ? 'Income' : 'Uncategorised'),
                    style: SkText.body(12, 400, color: SkColors.ink2),
                  ),
                ],
              ),
            ),
            Text(
              income ? '+${money(t.amountMinor, t.currency)}' : money(t.amountMinor, t.currency),
              style: SkText.display(16, 700, color: income ? SkColors.owed : SkColors.ink),
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
    }
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
                      if (_type == key) const SkIcon('check', size: 20, color: SkColors.personal),
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
