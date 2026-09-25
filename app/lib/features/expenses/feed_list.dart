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

/// Transaction cards for feed items. [byDay] groups them under "TODAY" / "YESTERDAY" headers
/// (Home); otherwise one flat list with the day in each card (group detail).
class FeedList extends ConsumerWidget {
  const FeedList({super.key, required this.items, required this.onHome, this.byDay = true});

  final List<FeedItem> items;
  final bool onHome;
  final bool byDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    Widget card(FeedItem i) {
      final v = feedView(i, me.id, onHome: onHome);
      return TransactionCard(
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
      );
    }

    if (!byDay) {
      return Column(
        children: [
          for (final i in items) ...[card(i), const SizedBox(height: 8)],
        ],
      );
    }
    final days = <String, List<FeedItem>>{};
    for (final i in items) {
      days.putIfAbsent(dayLabel(i.date), () => []).add(i);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: day, value: dayItems) in days.entries) ...[
          Overline(day),
          const SizedBox(height: 8),
          for (final i in dayItems) ...[card(i), const SizedBox(height: 8)],
          const SizedBox(height: 4),
        ],
      ],
    );
  }
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
  final api = ref.read(apiProvider);
  try {
    await api.settlements.deleteSettlement(i.id);
    refreshLedger(ref.invalidate);
    if (context.mounted) {
      showMessage(
        context,
        'Payment deleted',
        actionLabel: 'Undo',
        onAction: () async {
          await api.settlements.restoreSettlement(i.id);
          refreshLedger(ref.invalidate);
        },
      );
    }
  } catch (e) {
    if (context.mounted) showMessage(context, apiErrorMessage(e));
  }
}
