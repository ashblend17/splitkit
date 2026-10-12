import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/integrations.dart';
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'personal_txn_sheet.dart';
import 'txn_actions.dart';

/// Overview's "Just in": entries the app read from bank SMS that you haven't looked at yet,
/// newest first, each with what can be done with it (Split it, Looks right, Not mine).
/// Nothing at all when there are none.
class JustIn extends ConsumerWidget {
  const JustIn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(featuresProvider).justInLimit;
    final list = ref.watch(personalListProvider(PersonalQuery(source: 'sms', reviewed: false, limit: limit))).value;
    if (list == null || list.items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text('Just in', style: SkText.section))),
              if (list.count > 1) StatusChip('${list.count} to check', tone: StatusTone.personal, showDot: false),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in list.items) ...[_JustInCard(t), const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

class _JustInCard extends ConsumerWidget {
  const _JustInCard(this.txn);
  final PersonalTxnOut txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = personalView(txn);
    return SkCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showPersonalTxnSheet(context, existing: txn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(v.glyph, background: SkColors.personalSoft, foreground: SkColors.personalInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txn.description, style: SkText.body(15, 700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [?txn.account, entryWhen(txn.date, txn.smsAt ?? txn.createdAt, withDay: true)].join(' · '),
                      style: SkText.body(13, 400, color: SkColors.ink2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(v.amount, style: SkText.display(18, 700)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...txnActions(context, ref, txn, likely: true),
              SkButton(
                'Looks right',
                size: SkButtonSize.small,
                variant: SkButtonVariant.secondary,
                onPressed: () => _write(context, ref, (w) => w.reviewPersonal(txn.id)),
              ),
              SkButton(
                'Not mine',
                size: SkButtonSize.small,
                variant: SkButtonVariant.ghost,
                onPressed: () => _notMine(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _write(BuildContext context, WidgetRef ref, Future<void> Function(LocalWrites w) write) async {
    try {
      await write(ref.read(writesProvider));
      refreshPersonal(ref.invalidate);
    } catch (e) {
      if (context.mounted) showMessage(context, apiErrorMessage(e));
    }
  }

  /// Deleted, with Undo. Its id comes from the SMS, so reading the inbox again won't bring it
  /// back.
  Future<void> _notMine(BuildContext context, WidgetRef ref) async {
    final writes = ref.read(writesProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    await _write(context, ref, (w) => w.deletePersonal(txn.id));
    if (!context.mounted) return;
    showMessage(
      context,
      'Removed ${txn.description}',
      actionLabel: 'Undo',
      onAction: () async {
        await writes.restorePersonal(txn.id);
        refreshPersonal(container.invalidate);
      },
    );
  }
}
