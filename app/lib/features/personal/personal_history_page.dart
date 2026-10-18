import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'personal_txn_sheet.dart';

/// Screen 12, Personal's Transactions tab: filter by dates, type, category, account and how it
/// was paid; totals; entries grouped by day. Only the rows on screen are built, and more entries
/// are asked for as you scroll towards the end.
class PersonalHistoryPage extends ConsumerStatefulWidget {
  const PersonalHistoryPage({super.key, this.accountId, this.account});

  /// Start filtered to this account.
  final String? accountId;

  /// Start filtered to the entries with this bank SMS label (links from before accounts).
  final String? account;

  @override
  ConsumerState<PersonalHistoryPage> createState() => _PersonalHistoryPageState();
}

class _PersonalHistoryPageState extends ConsumerState<PersonalHistoryPage> {
  late DateTime _start = DateTime(appClock.now().year, appClock.now().month);
  DateTime _end = appClock.now();
  String? _type = 'expense';
  Set<String> _categories = {};
  late String? _accountId = widget.accountId;

  /// A bank SMS label from an old link, until another account is picked.
  late String? _label = widget.accountId == null ? widget.account : null;
  String? _channel;

  /// Entries asked for at first; scrolling near the end asks for as many more.
  static const _page = 100;
  int _limit = _page;

  /// The list on screen, and the filters it's for: kept while a longer page of it loads.
  (PersonalQuery, PersonalListOut)? _shown;

  /// Day headers and rows of [_shown], worked out once per list.
  (PersonalListOut, List<_Line>)? _lines;

  /// What names the account on a transfer's other side in the rows.
  FinanceEngine? _finance;

  @override
  void didUpdateWidget(PersonalHistoryPage old) {
    super.didUpdateWidget(old);
    // The tab keeps its page, so a link to another account arrives here.
    if (widget.accountId != old.accountId || widget.account != old.account) {
      _accountId = widget.accountId;
      _label = widget.accountId == null ? widget.account : null;
      _limit = _page;
    }
  }

  /// What the type filter offers, by the API's type (null: every type).
  Map<String?, String> get _types {
    final features = ref.read(featuresProvider);
    return {
      'expense': 'Expenses only',
      'income': 'Income only',
      if (features.transfers || _type == 'transfer') 'transfer': 'Transfers only',
      if (features.refunds || _type == 'refund') 'refund': 'Refunds only',
      null: 'Everything',
    };
  }

  PersonalQuery _queryFor(int limit) {
    final keys = _categories.toList()..sort();
    return PersonalQuery(
      start: _start,
      end: _end,
      type: _type,
      categories: _type == 'transfer' ? '' : keys.join(','),
      accountId: _accountId,
      account: _label,
      channel: _channel,
      limit: limit,
    );
  }

  /// A filter changed: back to the first page.
  void _filter(VoidCallback change) => setState(() {
    change();
    _limit = _page;
  });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final query = _queryFor(_limit);
    var list = ref.watch(personalListProvider(query));
    // More of the same list on its way: keep showing what's there.
    if (_shown case (final q, final l) when !list.hasValue && !list.hasError && q == _queryFor(q.limit)) {
      list = AsyncData(l);
    } else if (list.hasValue) {
      _shown = (query, list.requireValue);
    }
    final categories = ref.watch(personalCategoriesProvider);
    final features = ref.watch(featuresProvider);
    _finance = ref.watch(financeEngineProvider).value;
    final accounts = features.breakdownFilters
        ? (features.accounts ? ref.watch(accountsProvider).value ?? const <FinAccount>[] : null)
        : null;
    final days =
        DateTime(_end.year, _end.month, _end.day).difference(DateTime(_start.year, _start.month, _start.day)).inDays +
        1;
    final l = AsyncBody.dataOf(list);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          // Room at the bottom for the floating "Add entry".
          slivers: paddedSlivers(tabPagePadding(context, bottom: 120), [
            SliverToBoxAdapter(child: TabPageWidth(child: _filters(accounts, categories))),
            if (l == null)
              SliverToBoxAdapter(
                child: TabPageWidth(
                  child: AsyncBody(
                    value: list,
                    onRetry: () => ref.invalidate(personalListProvider),
                    builder: (_) => const SizedBox.shrink(),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: TabPageWidth(
                  child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _totals(l, me.currency, days)),
                ),
              ),
              if (l.items.isEmpty)
                const SliverToBoxAdapter(
                  child: TabPageWidth(
                    child: EmptyState(
                      glyph: 'wallet',
                      title: 'Nothing in this range',
                      body: 'Try other dates or categories.',
                    ),
                  ),
                )
              else
                _rows(l),
              if (l.items.length < l.count)
                SliverToBoxAdapter(
                  child: TabPageWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Showing the newest ${l.items.length} of ${l.count}.',
                        style: SkText.body(13, 400, color: SkColors.ink2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  /// The title, the filters and the category chips. [accounts] null: no account filter.
  Widget _filters(List<FinAccount>? accounts, AsyncValue<List<CategoryOut>> categories) => Column(
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
      if (ref.watch(featuresProvider).breakdownFilters) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (accounts != null && (accounts.isNotEmpty || _accountId != null || _label != null))
              _filterButton(
                label: _accountName(accounts) ?? _label ?? 'All accounts',
                trailing: 'down',
                strong: _accountId != null || _label != null,
                onTap: () => _pick(
                  'Account',
                  {null: 'All accounts', for (final a in accounts) a.id: a.closed ? '${a.name} (closed)' : a.name},
                  _accountId,
                  (v) {
                    _accountId = v;
                    _label = null;
                  },
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
      // Transfers have no category.
      if (_type != 'transfer') ...[
        AsyncBody(
          value: categories,
          onRetry: () => ref.invalidate(personalCategoriesProvider),
          skeletonRows: 1,
          builder: (cats) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', _categories.isEmpty, () => _filter(() => _categories = {})),
                for (final c in cats.where(
                  (c) => _type == 'income' ? c.key == 'income' || c.ownerId != null : c.key != 'income',
                ))
                  _chip(
                    c.label,
                    _categories.contains(c.key),
                    () => _filter(
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
      ],
    ],
  );

  /// How many lines before the end of what's loaded the next page is asked for: more than a
  /// fling covers while it loads (the list growing under an overscroll trips the stretch effect).
  static const _ahead = 50;

  /// The entries, a card per day, as one sliver that builds only the rows on screen.
  Widget _rows(PersonalListOut l) {
    final lines = identical(_lines?.$1, l) ? _lines!.$2 : (_lines = (l, _linesOf(l.items))).$2;
    return SliverList.builder(
      itemCount: lines.length,
      itemBuilder: (context, i) {
        if (i >= lines.length - _ahead) _loadMore(l);
        return TabPageWidth(
          child: switch (lines[i]) {
            _DayHead(:final day, :final total) => _dayHead(day, total),
            _Row(:final txn, :final last) => _rowPiece(txn, last: last),
            _DayEnd() => const SizedBox(height: 12),
          },
        );
      },
    );
  }

  void _loadMore(PersonalListOut l) {
    // Everything's here, or more is already on its way.
    if (l.items.length >= l.count || l.items.length < _limit) return;
    final next = l.items.length + _page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _limit < next) setState(() => _limit = next);
    });
  }

  List<_Line> _linesOf(List<PersonalTxnOut> items) {
    final byDay = <DateTime, List<PersonalTxnOut>>{};
    for (final t in items) {
      byDay.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    return [
      for (final MapEntry(key: day, value: list) in byDay.entries) ...[
        _DayHead(day, _dayTotal(list)),
        for (final (i, t) in list.indexed) _Row(t, last: i == list.length - 1),
        const _DayEnd(),
      ],
    ];
  }

  /// A day's card is drawn a piece at a time: its header (the top of the card)…
  Widget _dayHead(DateTime day, String total) => Container(
    decoration: BoxDecoration(
      color: SkColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(SkRadius.card)),
      border: Border(
        top: BorderSide(color: SkColors.line),
        left: BorderSide(color: SkColors.line),
        right: BorderSide(color: SkColors.line),
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SkPalette.tableHead,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(SkRadius.card - 1)),
        border: Border(bottom: BorderSide(color: SkColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(dayLabel(day), style: SkText.body(13, 700))),
          Text(total, style: SkText.body(13, 400, color: SkColors.ink2)),
        ],
      ),
    ),
  );

  /// …then each entry, the card's sides around it, the last one closing the card.
  Widget _rowPiece(PersonalTxnOut t, {required bool last}) => Container(
    key: ValueKey('personal-txn:${t.id}'),
    decoration: BoxDecoration(
      color: SkColors.surface,
      borderRadius: last ? const BorderRadius.vertical(bottom: Radius.circular(SkRadius.card)) : null,
      border: Border(
        left: BorderSide(color: SkColors.line),
        right: BorderSide(color: SkColors.line),
        bottom: last ? BorderSide(color: SkColors.line) : BorderSide.none,
      ),
    ),
    child: _row(t, last: last),
  );

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

  /// The name of the account the list is filtered to, if any.
  String? _accountName(List<FinAccount> accounts) {
    for (final a in accounts) {
      if (a.id == _accountId) return a.name;
    }
    return null;
  }

  Widget _totals(PersonalListOut l, String currency, int days) {
    final (label, total) = switch (_type) {
      'income' => ('Income', l.incomeMinor),
      'refund' => ('Refunds', l.refundsMinor),
      _ => ('Total', l.spentMinor),
    };
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
    // Moves between your own accounts aren't spending or income: nothing to add up.
    if (_type == 'transfer') {
      return SkCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            figure('Transactions', '${l.count}', weight: 800),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                "Money moved between your accounts isn't spending or income.",
                style: SkText.body(12, 400, color: SkColors.ink2),
              ),
            ),
          ],
        ),
      );
    }
    return SkCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          figure(label, money(total, currency), weight: 800),
          const SizedBox(width: 8),
          figure('Transactions', '${l.count}'),
          const SizedBox(width: 8),
          figure('Per day', money(days <= 0 ? 0 : ((total / days) / 100).round() * 100, currency)),
        ],
      ),
    );
  }

  /// Like the totals: entries that became a split or a payment aren't counted, refunds come off
  /// spending, and a transfer (two halves) is money moved, once.
  String _dayTotal(List<PersonalTxnOut> list) {
    final counted = list.where((t) => t.counted);
    if (counted.isEmpty) return 'Not counted';
    int sum(PersonalTxnOutTypeEnum type, [PersonalTxnOutDirectionEnum? direction]) => counted
        .where((t) => t.type == type && (direction == null || t.direction == direction))
        .fold(0, (a, t) => a + t.amountMinor);
    final expenses = sum(PersonalTxnOutTypeEnum.expense), refunds = sum(PersonalTxnOutTypeEnum.refund);
    final spent = expenses - refunds;
    final income = sum(PersonalTxnOutTypeEnum.income);
    final c = list.first.currency;
    if (expenses == 0 && income == 0) {
      final moved = sum(PersonalTxnOutTypeEnum.transfer, PersonalTxnOutDirectionEnum.out_);
      if (refunds > 0) return '${money(refunds, c)} back';
      if (moved > 0) return '${money(moved, c)} moved';
    }
    if (spent > 0 && income > 0) return '${money(spent, c)} out · ${money(income, c)} in';
    return income > 0 ? '+${money(income, c)}' : money(spent, c);
  }

  Widget _row(PersonalTxnOut t, {required bool last}) {
    final v = personalView(t, finance: _finance, brief: true);
    final (tileBg, tileFg) = personalTile(v);
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
            IconTile(v.glyph, background: tileBg, foreground: tileFg, size: 36, radius: 10, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title, style: SkText.body(15, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(v.subtitle, style: SkText.body(12, 400, color: SkColors.ink2)),
                ],
              ),
            ),
            Text(
              v.amount,
              style: SkText.display(
                16,
                700,
                color: !t.counted
                    ? SkColors.ink3
                    : switch (v.tone) {
                        MoneyTone.income => SkColors.owed,
                        MoneyTone.neutral => SkColors.ink2,
                        _ => SkColors.ink,
                      },
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
      _filter(() {
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
    if (picked != null) _filter(() => set(picked.$1));
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
      _filter(() {
        _type = picked == 'all' ? null : picked;
        _categories = {};
      });
    }
  }
}

/// A line of the Transactions list: a day's header, an entry, or the space after a day.
sealed class _Line {
  const _Line();
}

class _DayHead extends _Line {
  const _DayHead(this.day, this.total);
  final DateTime day;
  final String total;
}

class _Row extends _Line {
  const _Row(this.txn, {required this.last});
  final PersonalTxnOut txn;
  final bool last;
}

class _DayEnd extends _Line {
  const _DayEnd();
}
