import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/local/outbox.dart';
import '../../core/local/providers.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../shell/sync_banner.dart';

/// "This device": when it last synced, what's waiting, and the recovery actions from
/// validation.md (sync now, reload from the server, copy unsynced changes).
class DeviceCard extends ConsumerWidget {
  const DeviceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value;
    final ops = ref.watch(outboxProvider);
    final waiting = ops.where((o) => o.status != OutboxStatus.rejected).length;
    final refused = ops.length - waiting;
    final last = status?.lastSyncedAt;
    final state = status == null
        ? 'Not synced yet'
        : status.offline
        ? 'Offline${last == null ? '' : ' · last synced ${DateFormat('d MMM, h:mm a').format(last)}'}'
        : last == null
        ? 'Syncing…'
        : 'Synced ${DateFormat('d MMM, h:mm a').format(last)}';
    final changes = [
      if (waiting > 0) waiting == 1 ? '1 change waiting' : '$waiting changes waiting',
      if (refused > 0) refused == 1 ? "1 change couldn't be saved" : "$refused changes couldn't be saved",
    ].join(' · ');

    Future<void> syncNow() async {
      try {
        await (await ref.read(syncEngineProvider.future)).pull();
        if (context.mounted) showMessage(context, 'Up to date');
      } catch (e) {
        if (context.mounted) showMessage(context, apiErrorMessage(e));
      }
    }

    Future<void> reload() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Reload from the server?',
        body: waiting + refused > 0
            ? "This device's copy is replaced with the server's. Your ${waiting + refused} unsynced "
                  'change(s) are kept and sent next.'
            : "This device's copy is replaced with the server's. Nothing of yours is lost.",
        confirmLabel: 'Reload',
        destructive: false,
      );
      if (!ok) return;
      try {
        await (await ref.read(localStoreProvider.future)).resetServerCopy();
        await (await ref.read(syncEngineProvider.future)).pull();
        if (context.mounted) showMessage(context, 'Reloaded from the server');
      } catch (e) {
        if (context.mounted) showMessage(context, apiErrorMessage(e));
      }
    }

    Future<void> copy() async {
      final json = const JsonEncoder.withIndent('  ').convert([for (final o in ops) o.toJson()]);
      await Clipboard.setData(ClipboardData(text: json));
      if (context.mounted) showMessage(context, 'Copied ${ops.length} unsynced change(s)');
    }

    Widget row(String glyph, String label, VoidCallback? onTap, {bool last = false}) => Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: SkPalette.divider)),
          ),
          child: Row(
            children: [
              SkIcon(glyph, size: 20, color: onTap == null ? SkColors.ink3 : SkColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: SkText.body(15, 600, color: onTap == null ? SkColors.ink3 : SkColors.ink)),
              ),
            ],
          ),
        ),
      ),
    );

    return SkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text('This device', style: SkText.body(15, 700))),
                const SizedBox(height: 2),
                Text(state, style: SkText.body(13, 500, color: SkColors.ink2)),
                if (changes.isNotEmpty) Text(changes, style: SkText.body(13, 600, color: SkColors.pending)),
              ],
            ),
          ),
          const Divider(height: 1, color: SkPalette.divider),
          row('refresh', 'Sync now', syncNow),
          if (refused > 0) row('alert', 'Review changes that couldn\'t be saved', () => showAttentionSheet(context)),
          row('down', 'Reload from the server', reload),
          row('file', 'Copy unsynced changes', ops.isEmpty ? null : copy, last: true),
        ],
      ),
    );
  }
}
