import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/local/outbox.dart';
import '../../core/local/providers.dart';
import '../../core/local/writes.dart';
import '../../core/router/router.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../admin/view_as.dart';
import '../tricount_sync/tricount_conflicts.dart';
import '../tricount_sync/tricount_providers.dart';

/// What every screen sits in (MaterialApp's builder): the view-as banner and frame, then the
/// sync line. Above the navigator, so full-screen pages and sheets get the line too.
Widget appChrome(BuildContext context, Widget? child) => ViewAsChrome(child: SyncBanner(child: child!));

/// One line above every signed-in screen when something needs saying: offline (and how many
/// changes are waiting), changes the server refused ("Needs your attention"), or entries
/// changed in both Splitkit and a linked tricount.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing to say before sign-in (and the providers below need a session).
    if (ref.watch(sessionProvider.select((s) => s.value == null))) return child;
    final offline = ref.watch(syncStatusProvider).value?.offline ?? false;
    // This line sits above the navigator, so its sheets open from the navigator's context.
    BuildContext sheetContext() => ref.read(routerProvider).routerDelegate.navigatorKey.currentContext ?? context;
    final ops = ref.watch(outboxProvider);
    final waiting = ops.where((o) => o.status != OutboxStatus.rejected).length;
    final refused = ops.where((o) => o.status == OutboxStatus.rejected).length;
    final fromTricount = ref.watch(tricountConflictsProvider).value?.length ?? 0;

    Widget? line;
    if (refused > 0) {
      line = _Line(
        glyph: 'alert',
        text: refused == 1 ? "1 change couldn't be saved" : "$refused changes couldn't be saved",
        action: 'Review',
        background: SkColors.pendingSoft,
        foreground: SkColors.pending,
        onTap: () => showAttentionSheet(sheetContext()),
      );
    } else if (fromTricount > 0 && !offline) {
      line = _Line(
        glyph: 'swap',
        text: fromTricount == 1
            ? '1 change from Tricount needs a decision'
            : '$fromTricount changes from Tricount need a decision',
        action: 'Review',
        background: SkColors.pendingSoft,
        foreground: SkColors.pending,
        onTap: () => showTricountConflictsSheet(sheetContext()),
      );
    } else if (offline) {
      line = _Line(
        glyph: 'alert',
        text: waiting == 0
            ? "You're offline. Showing what's on this device."
            : "You're offline. ${waiting == 1 ? '1 change' : '$waiting changes'} will sync when you're back.",
        background: SkColors.sunken,
        foreground: SkColors.ink2,
      );
    }
    return Column(
      children: [
        ?line,
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: line != null, child: child)),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.glyph,
    required this.text,
    required this.background,
    required this.foreground,
    this.action,
    this.onTap,
  });

  final String glyph;
  final String text;
  final Color background;
  final Color foreground;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: onTap != null,
      child: Material(
        color: background,
        child: InkWell(
          onTap: onTap,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SkIcon(glyph, size: 16, color: foreground),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: SkText.body(13, 600, color: foreground))),
                  if (action != null) Text(action!, style: SkText.body(13, 700, color: foreground)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Changes the server refused, with why and what you can do.
Future<void> showAttentionSheet(BuildContext context) =>
    showAppBottomSheet<void>(context, title: 'Needs your attention', child: const _AttentionList());

class _AttentionList extends ConsumerWidget {
  const _AttentionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refused = ref.watch(outboxProvider).where((o) => o.status == OutboxStatus.rejected).toList();
    if (refused.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('All your changes are saved.', style: SkText.body(14, 400, color: SkColors.ink2)),
      );
    }
    final writes = ref.read(writesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "These were made on this device but the server didn't take them, so they aren't in your balances.",
          style: SkText.body(14, 400, color: SkColors.ink2, height: 1.45),
        ),
        const SizedBox(height: 12),
        for (final op in refused)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(op.label, style: SkText.body(15, 700)),
                const SizedBox(height: 2),
                Text(op.error ?? 'The server refused this change', style: SkText.body(14, 400, color: SkColors.oweInk)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (op.isConflict) ...[
                      SkButton('Keep mine', size: SkButtonSize.small, onPressed: () => _run(context, () => writes.keepMine(op))),
                      const SizedBox(width: 8),
                    ],
                    SkButton(
                      op.isConflict ? 'Keep theirs' : 'Discard',
                      variant: SkButtonVariant.secondary,
                      size: SkButtonSize.small,
                      onPressed: () => _run(context, () => writes.discard(op)),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}
