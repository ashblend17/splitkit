import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/session/session.dart';
import '../../core/splits/split_engine.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'feed_list.dart';

enum _Col { date, expense, paidBy, total, split, share, balance, when }

/// Desktop activity table (HomeDesktop, GroupDesktop): a header row, then one row per
/// expense or payment, scrolling inside its card. Narrow windows drop the least useful
/// columns first, so the expense name always keeps room.
class ActivityTable extends ConsumerWidget {
  const ActivityTable({super.key, required this.items, required this.onHome});

  final List<FeedItem> items;

  /// Home: group under each title, share and "when" columns. Group: a date column instead.
  final bool onHome;

  static const _minExpense = 200.0;
  static const _gap = 12.0;
  static const _pad = 16.0;

  double _width(_Col c) => switch (c) {
    _Col.date => 90,
    _Col.paidBy => 110,
    _Col.total => 100,
    _Col.split => onHome ? 90 : 110,
    _Col.share => 110,
    _Col.balance => 140,
    _Col.when => 100,
    _Col.expense => 0,
  };

  List<_Col> _columns(double width) {
    final cols = onHome
        ? [_Col.expense, _Col.paidBy, _Col.total, _Col.split, _Col.share, _Col.balance, _Col.when]
        : [_Col.date, _Col.expense, _Col.paidBy, _Col.total, _Col.split, _Col.balance];
    final dropOrder = onHome ? [_Col.split, _Col.share, _Col.when, _Col.paidBy] : [_Col.split, _Col.paidBy, _Col.date];
    double needed() => cols.fold(0.0, (sum, c) => sum + _width(c)) + _gap * (cols.length - 1) + _minExpense;
    for (final c in dropOrder) {
      if (needed() <= width - 2 * _pad) break;
      cols.remove(c);
    }
    return cols;
  }

  String _header(_Col c) => switch (c) {
    _Col.date => 'Date',
    _Col.expense => 'Expense',
    _Col.paidBy => 'Paid by',
    _Col.total => 'Total',
    _Col.split => 'Split',
    _Col.share => 'Your share',
    _Col.balance => onHome ? 'Your balance' : 'You',
    _Col.when => 'When',
  };

  Widget _cells(List<_Col> cols, Widget Function(_Col c) cell) => Row(
    children: [
      for (final (n, c) in cols.indexed) ...[
        if (n > 0) const SizedBox(width: _gap),
        c == _Col.expense ? Expanded(child: cell(c)) : SizedBox(width: _width(c), child: cell(c)),
      ],
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meId = ref.watch(meProvider).id;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = _columns(box.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 10),
                decoration: const BoxDecoration(
                  color: SkPalette.tableHead,
                  border: Border(bottom: BorderSide(color: SkColors.line)),
                ),
                child: _cells(
                  cols,
                  (c) => Text(
                    _header(c).toUpperCase(),
                    style: SkText.body(12, 700, color: SkColors.ink2, letterSpacing: 0.6),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, n) => _row(context, ref, items[n], meId, cols),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, FeedItem i, String meId, List<_Col> cols) {
    final v = feedView(i, meId, onHome: onHome);
    final b = activityBalance(i, meId, onHome: onHome);
    final payment = i.kind == FeedItemKindEnum.settlement;
    final c = i.currency;
    final ink2 = SkText.body(14, 400, color: SkColors.ink2);

    Widget cell(_Col col) => switch (col) {
      _Col.date => Text(DateFormat('d MMM').format(i.date), style: ink2),
      _Col.expense => Row(
        children: [
          if (onHome)
            IconTile(v.glyph, background: v.tone.tileBg, foreground: v.tone.tileFg, size: 36, iconSize: 18, radius: 10)
          else
            SkIcon(v.glyph, size: 18, color: SkColors.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(v.title, style: SkText.body(14, 700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (i.byAdmin) ...[const SizedBox(width: 6), const _AdminPill()],
                  ],
                ),
                if (onHome)
                  Text(
                    i.groupName,
                    style: SkText.body(12, 600, color: SkColors.brandInk),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      _Col.paidBy => Text(
        displayName(i.payer, meId),
        style: SkText.body(14, 400),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      _Col.total => Text(money(i.amountMinor, c), style: SkText.display(14, 600, tracking: 0)),
      _Col.split => Text(payment ? 'Payment' : splitLabel(i.method, i.participantCount), style: ink2),
      _Col.share => Text(
        payment || i.myShareMinor == 0 ? '—' : money(i.myShareMinor, c),
        style: SkText.display(14, 600, tracking: 0),
      ),
      _Col.balance => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            b.label,
            style: SkText.body(12, 600, color: b.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(b.amount, style: SkText.display(onHome ? 16 : 14, 800, color: b.color, tracking: 0)),
        ],
      ),
      _Col.when => Text(dayLabel(i.date).replaceFirst(',', ''), style: ink2),
    };

    return Semantics(
      button: true,
      label: [
        v.title,
        if (onHome) i.groupName,
        '${displayName(i.payer, meId)} paid ${money(i.amountMinor, c)}',
        '${b.label} ${b.amount}',
        dayLabel(i.date),
        if (i.byAdmin) 'Edited by an admin',
      ].join('. '),
      child: Material(
        color: SkColors.surface,
        child: InkWell(
          hoverColor: SkPalette.tableHead,
          onTap: () => payment ? showSettlementDetails(context, ref, i) : context.push('/expenses/${i.id}'),
          child: ExcludeSemantics(
            child: Container(
              constraints: BoxConstraints(minHeight: onHome ? 60 : 56),
              padding: EdgeInsets.symmetric(horizontal: _pad, vertical: onHome ? 4 : 2),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SkPalette.divider)),
              ),
              child: Center(child: _cells(cols, cell)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Equal · 4", "Shares · 6".
String splitLabel(String method, int people) {
  final name = splitRegistry.keys.contains(method) ? splitRegistry.get(method).label : method;
  return '$name · $people';
}

/// The balance column: words, amount and colour for one row.
({String label, String amount, Color color}) activityBalance(FeedItem i, String meId, {required bool onHome}) {
  final c = i.currency;
  if (i.kind == FeedItemKindEnum.settlement) {
    return (label: 'payment', amount: money(i.amountMinor, c), color: SkColors.brandInk);
  }
  final net = i.myNetMinor;
  if (net > 0) return (label: onHome ? 'you are owed' : 'you lent', amount: money(net, c), color: SkColors.owed);
  if (net < 0 && i.settled) {
    return (label: 'settled', amount: money(onHome ? 0 : i.myShareMinor, c), color: SkColors.ink2);
  }
  if (net < 0) {
    return (
      label: onHome ? 'you owe ${firstName(i.payer.name)}' : 'you owe',
      amount: money(-net, c),
      color: SkColors.owe,
    );
  }
  if (i.myShareMinor > 0) return (label: 'your share', amount: money(i.myShareMinor, c), color: SkColors.ink2);
  return (label: 'not involved', amount: '—', color: SkColors.ink2);
}

class _AdminPill extends StatelessWidget {
  const _AdminPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: SkColors.adminBand, borderRadius: BorderRadius.circular(SkRadius.chip)),
    child: Text('Admin', style: SkText.body(11, 700, color: SkColors.adminInk)),
  );
}
