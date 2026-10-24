import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/local/writes.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// "Show older" under a feed list that may have more than it shows ([shown] reached the
/// list's limit).
class ShowOlder extends ConsumerWidget {
  const ShowOlder({super.key, required this.list, required this.shown});

  /// The [feedLimitProvider] key.
  final String list;
  final int shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shown < ref.watch(feedLimitProvider(list))) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SkButton(
          'Show older',
          variant: SkButtonVariant.secondary,
          size: SkButtonSize.small,
          onPressed: () => ref.read(feedLimitProvider(list).notifier).more(),
        ),
      ),
    );
  }
}

/// Transaction cards for feed items, as a sliver: only the rows on screen are built. [byDay]
/// groups them under "TODAY" / "YESTERDAY" headers (Home); otherwise one flat list with the day
/// in each card (group detail). [frame] wraps each row (the page's column width).
class SliverFeedList extends ConsumerWidget {
  const SliverFeedList({super.key, required this.items, required this.onHome, this.byDay = true, this.frame});

  final List<FeedItem> items;
  final bool onHome;
  final bool byDay;
  final Widget Function(Widget row)? frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = _feedLines(items, byDay);
    final row = _feedRow(context, ref, onHome: onHome, byDay: byDay);
    return SliverList.builder(
      itemCount: lines.length,
      itemBuilder: (context, i) => frame?.call(row(lines[i])) ?? row(lines[i]),
    );
  }
}

/// A feed list's rows in order: a day's header (Home), a card, or the space after a day.
typedef _FeedLine = ({String? day, FeedItem? item});

List<_FeedLine> _feedLines(List<FeedItem> items, bool byDay) {
  if (!byDay) return [for (final i in items) (day: null, item: i)];
  final days = <String, List<FeedItem>>{};
  for (final i in items) {
    days.putIfAbsent(dayLabel(i.date), () => []).add(i);
  }
  return [
    for (final MapEntry(key: day, value: dayItems) in days.entries) ...[
      (day: day, item: null),
      for (final i in dayItems) (day: null, item: i),
      (day: null, item: null),
    ],
  ];
}

Widget Function(_FeedLine line) _feedRow(
  BuildContext context,
  WidgetRef ref, {
  required bool onHome,
  required bool byDay,
}) {
  final me = ref.watch(meProvider);
  return (line) {
    if (line.day case final day?) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Overline(day));
    }
    final i = line.item;
    if (i == null) return const SizedBox(height: 4);
    final v = feedView(i, me.id, onHome: onHome);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TransactionCard(
        key: ValueKey(i.id),
        title: v.title,
        subtitle: v.subtitle,
        tag: v.tag,
        when: entryWhen(i.date, i.createdAt, withDay: !byDay),
        label: v.label,
        amount: v.amount,
        glyph: v.glyph,
        tone: v.tone,
        adminBadge: i.byAdmin,
        onTap: () => i.kind == FeedItemKindEnum.expense
            ? context.push('/expenses/${i.id}')
            : showSettlementDetails(context, ref, i),
      ),
    );
  };
}

/// Payment details with a way to delete it (payments are soft-deleted and restorable).
Future<void> showSettlementDetails(BuildContext context, WidgetRef ref, FeedItem i) async {
  final me = ref.read(meProvider);
  final v = feedView(i, me.id, onHome: true);
  final delete = await showAppBottomSheet<bool>(
    context,
    title: v.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(money(i.amountMinor, i.currency), style: SkText.display(36, 800)),
        const SizedBox(height: 6),
        Text(
          '${i.groupName} · ${formDateLabel(i.date)} · ${paymentMethodLabels[i.method] ?? i.method}',
          style: SkText.body(14, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (sheet) => SkButton(
            'Delete payment',
            icon: 'trash',
            variant: SkButtonVariant.danger,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ),
      ],
    ),
  );
  if (delete != true || !context.mounted) return;
  final ok = await showConfirmDialog(
    context,
    title: 'Delete this payment?',
    body: 'Balances in ${i.groupName} will change back. You can undo right after.',
    confirmLabel: 'Delete',
  );
  if (!ok) return;
  final writes = ref.read(writesProvider);
  try {
    await writes.deleteSettlement(i.id);
    refreshLedger(ref.invalidate);
    if (context.mounted) {
      showMessage(
        context,
        'Payment deleted',
        actionLabel: 'Undo',
        onAction: () async {
          await writes.restoreSettlement(i.id);
          refreshLedger(ref.invalidate);
        },
      );
    }
  } catch (e) {
    if (context.mounted) showMessage(context, apiErrorMessage(e));
  }
}
