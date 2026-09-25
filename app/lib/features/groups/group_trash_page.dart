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

/// Deleted expenses and payments in a group, each restorable.
class GroupTrashPage extends ConsumerWidget {
  const GroupTrashPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final items = ref.watch(feedProvider((groupId: groupId, deleted: true)));
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
                            label: 'Back to group',
                            onPressed: () => context.go('/groups/$groupId'),
                          ),
                        ),
                        Semantics(header: true, child: Text('Deleted items', style: SkText.display(20, 700))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Deleted entries don't count towards balances. Restore one to bring it back.",
                    style: SkText.body(13, 400, color: SkColors.ink2),
                  ),
                  const SizedBox(height: 16),
                  AsyncBody(
                    value: items,
                    onRetry: () => ref.invalidate(feedProvider),
                    builder: (list) => list.isEmpty
                        ? const EmptyState(
                            glyph: 'trash',
                            title: 'Nothing deleted',
                            body: 'Deleted expenses and payments show up here.',
                          )
                        : Column(
                            children: [
                              for (final i in list) ...[_TrashRow(item: i, meId: me.id), const SizedBox(height: 8)],
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
}

class _TrashRow extends ConsumerWidget {
  const _TrashRow({required this.item, required this.meId});
  final FeedItem item;
  final String meId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = feedView(item, meId, onHome: false);
    return SkCard(
      child: Row(
        children: [
          IconTile(v.glyph, background: SkColors.sunken, foreground: SkColors.ink2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.title, style: SkText.body(15, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${money(item.amountMinor, item.currency)} · deleted ${_when(item.deletedAt!.toLocal())}',
                  style: SkText.body(13, 400, color: SkColors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SkButton(
            'Restore',
            variant: SkButtonVariant.secondary,
            size: SkButtonSize.small,
            onPressed: () async {
              final api = ref.read(apiProvider);
              try {
                if (item.kind == FeedItemKindEnum.expense) {
                  await api.expenses.restoreExpense(item.id);
                } else {
                  await api.settlements.restoreSettlement(item.id);
                }
                refreshLedger(ref.invalidate);
                if (context.mounted) showMessage(context, '“${v.title}” restored');
              } catch (e) {
                if (context.mounted) showMessage(context, apiErrorMessage(e));
              }
            },
          ),
        ],
      ),
    );
  }
}

String _when(DateTime at) {
  final label = dayLabel(at);
  return label == 'Today' || label == 'Yesterday' ? label.toLowerCase() : 'on $label';
}
