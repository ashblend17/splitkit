import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'tricount_providers.dart';
import '../../core/config.dart';

/// Every entry changed in both this app and Tricount, for someone to pick a side.
Future<void> showTricountConflictsSheet(BuildContext context) => showAppBottomSheet<void>(
  context,
  title: 'Changed in both apps',
  child: const _ConflictSheet(),
);

class _ConflictSheet extends ConsumerWidget {
  const _ConflictSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(tricountConflictsProvider).value ?? const [];
    if (conflicts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Nothing to sort out. ${AppConfig.appName} and Tricount agree.', style: SkText.body(14, 400, color: SkColors.ink2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'These were changed in ${AppConfig.appName} and in Tricount since the two last agreed. Pick the version to keep; '
          'the other app is updated to match.',
          style: SkText.body(14, 400, color: SkColors.ink2, height: 1.45),
        ),
        const SizedBox(height: 12),
        for (final c in conflicts) ...[TricountConflictCard(conflict: c, showGroup: true), const SizedBox(height: 10)],
      ],
    );
  }
}

/// One conflict: what each app says now, and a button to keep each.
class TricountConflictCard extends ConsumerStatefulWidget {
  const TricountConflictCard({super.key, required this.conflict, this.showGroup = false});
  final TricountConflictOut conflict;
  final bool showGroup;

  @override
  ConsumerState<TricountConflictCard> createState() => _TricountConflictCardState();
}

class _TricountConflictCardState extends ConsumerState<TricountConflictCard> {
  bool _busy = false;

  Future<void> _keep(ResolveConflictInKeepEnum keep) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .tricount
          .resolveTricountConflict(widget.conflict.id, ResolveConflictIn(keep: keep));
      ref.invalidate(tricountConflictsProvider);
      ref.invalidate(tricountStatusProvider(widget.conflict.groupId));
      refreshLedger(ref.invalidate);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conflict;
    final what = c.entity == TricountConflictOutEntityEnum.payment ? 'payment' : 'expense';
    return SkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.showGroup ? 'An $what in ${c.groupName}' : 'An $what',
            style: SkText.body(12, 600, color: SkColors.ink2),
          ),
          const SizedBox(height: 8),
          _Side(app: AppConfig.appName, side: c.local),
          const SizedBox(height: 8),
          _Side(app: 'Tricount', side: c.tricount),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SkButton(
                  "Keep ${AppConfig.appName}'s",
                  size: SkButtonSize.small,
                  expand: true,
                  onPressed: _busy ? null : () => _keep(ResolveConflictInKeepEnum.local),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SkButton(
                  "Keep Tricount's",
                  variant: SkButtonVariant.secondary,
                  size: SkButtonSize.small,
                  expand: true,
                  onPressed: _busy ? null : () => _keep(ResolveConflictInKeepEnum.tricount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.app, required this.side});
  final String app;
  final ConflictSideOut side;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('In $app', style: SkText.overline),
          const SizedBox(height: 2),
          Text(
            side.deleted ? 'Deleted' : side.title,
            style: SkText.body(15, 700, color: side.deleted ? SkColors.oweInk : SkColors.ink),
          ),
          if (!side.deleted) Text(side.summary, style: SkText.body(13, 400, color: SkColors.ink2)),
        ],
      ),
    );
  }
}
