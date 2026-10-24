import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'tricount_providers.dart';

/// "Synced with Tricount · 2 min ago" under a group's name, when the group is linked. Nothing
/// otherwise, or while offline. Tapping it opens the sync page.
class TricountStatusLine extends ConsumerWidget {
  const TricountStatusLine({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(tricountStatusProvider(groupId)).value?.link;
    if (link == null) return const SizedBox.shrink();
    final (text, color) = switch (link.state) {
      _ when link.conflicts.isNotEmpty => (
        '${link.conflicts.length} ${link.conflicts.length == 1 ? 'change needs' : 'changes need'} a decision',
        SkColors.pending,
      ),
      TricountLinkOutStateEnum.syncing => ('Syncing with Tricount…', SkColors.ink2),
      TricountLinkOutStateEnum.error => ('Tricount sync stopped · see why', SkColors.oweInk),
      _ => (
        link.lastSyncedAt == null ? 'Synced with Tricount' : 'Synced with Tricount · ${agoLabel(link.lastSyncedAt!)}',
        SkColors.ink2,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go('/groups/$groupId/tricount'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkIcon('swap', size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(child: Text(text, style: SkText.body(13, 600, color: color))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
