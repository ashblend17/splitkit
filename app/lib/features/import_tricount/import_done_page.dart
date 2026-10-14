import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'import_api.dart';
import 'import_flow.dart';
import 'widgets.dart';

/// Screen 20 (done): what was imported, what needs a look, and one-step undo.
class ImportDonePage extends ConsumerStatefulWidget {
  const ImportDonePage({super.key, required this.batchId});
  final String batchId;

  @override
  ConsumerState<ImportDonePage> createState() => _ImportDonePageState();
}

class _ImportDonePageState extends ConsumerState<ImportDonePage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(importBatchProvider(widget.batchId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            ContentWidth(
              maxWidth: 620,
              child: AsyncBody(
                value: batch,
                onRetry: () => ref.invalidate(importBatchProvider(widget.batchId)),
                builder: _body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ImportBatchOut b) {
    final s = b.stats;
    final undone = b.undoneAt != null;
    final group = b.groupName ?? 'The group';
    final when = DateFormat('d MMM y, h:mm a').format(b.createdAt.toLocal());
    return SkCard(
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconTile(
              undone ? 'refresh' : 'check',
              background: undone ? SkColors.sunken : SkColors.owedSoft,
              foreground: undone ? SkColors.ink2 : SkColors.owed,
              size: 60,
              radius: 18,
              iconSize: 32,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(undone ? 'Import undone' : 'Import completed', style: SkText.display(30, 800)),
          ),
          const SizedBox(height: 6),
          Text(
            undone
                ? 'Everything this import added was removed, and balances are back to how they were.'
                : '$group is ready. Balances were recalculated from the imported splits.',
            style: SkText.body(15, 400, color: SkColors.ink2),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ImportStat(value: '${s.expenses}', label: s.expenses == 1 ? 'expense imported' : 'expenses imported'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ImportStat(value: '${s.people}', label: s.people == 1 ? 'person matched' : 'people matched'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ImportStat(
                  value: '${s.review.length}',
                  label: s.review.length == 1 ? 'item needs review' : 'items need review',
                  warn: s.review.isNotEmpty,
                ),
              ),
            ],
          ),
          if (s.transfers > 0 || s.skipped > 0) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (s.transfers > 0)
                  '${plural(s.transfers, 'payment')} (${money(s.transferTotalMinor, s.currency)}) from Tricount’s money transfers',
                if (s.skipped > 0) '${plural(s.skipped, 'row')} not imported',
              ].join(' · '),
              style: SkText.body(13, 500, color: SkColors.ink2),
            ),
          ],
          if (s.review.isNotEmpty && !undone) ...[
            const SizedBox(height: 16),
            _list([
              for (final r in s.review)
                _item(
                  r.title,
                  r.why,
                  r.expenseId == null ? null : () => context.go('/expenses/${r.expenseId}'),
                ),
            ]),
          ],
          if (s.skippedRows.isNotEmpty && !undone) ...[
            const SizedBox(height: 16),
            const Overline('Not imported'),
            const SizedBox(height: 8),
            _list([for (final row in s.skippedRows) _item(row, null, null)]),
          ],
          const SizedBox(height: 20),
          _actions(b, undone),
          const SizedBox(height: 12),
          Text(
            undone
                ? 'Batch ${b.id.substring(0, 8)} · imported $when · undone ${DateFormat('d MMM y, h:mm a').format(b.undoneAt!.toLocal())}.'
                : 'Batch ${b.id.substring(0, 8)} · $when · undo removes only what this import created.',
            style: SkText.body(12, 400, color: SkColors.ink2),
          ),
        ],
      ),
    );
  }

  Widget _actions(ImportBatchOut b, bool undone) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final open = !undone && b.groupId != null
        ? SkButton(
            'Open ${b.groupName ?? 'group'}',
            size: SkButtonSize.large,
            expand: true,
            onPressed: () => context.go('/groups/${b.groupId}'),
          )
        : SkButton('Back to profile', size: SkButtonSize.large, expand: true, onPressed: () => context.go('/profile'));
    if (undone) return open;
    final undo = SkButton(
      _busy ? 'Undoing…' : 'Undo this import',
      variant: SkButtonVariant.danger,
      size: SkButtonSize.large,
      expand: narrow,
      onPressed: _busy ? null : () => _undo(b),
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [open, const SizedBox(height: 10), undo],
      );
    }
    return Row(children: [Expanded(child: open), const SizedBox(width: 10), undo]);
  }

  Widget _list(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SkColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );

  Widget _item(String title, String? why, VoidCallback? onReview) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: SkPalette.divider))),
    child: Row(
      children: [
        SkIcon('alert', size: 18, color: SkColors.pending),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title, style: SkText.body(14, 700)),
                if (why != null) TextSpan(text: ' · $why'),
              ],
            ),
            style: SkText.body(14, 400),
          ),
        ),
        if (onReview != null) SkButton('Review', variant: SkButtonVariant.ghost, size: SkButtonSize.small, onPressed: onReview),
      ],
    ),
  );

  Future<void> _undo(ImportBatchOut b) async {
    final s = b.stats;
    final ok = await showConfirmDialog(
      context,
      title: 'Undo this import?',
      body:
          'This removes the ${plural(s.expenses, 'expense')}${s.transfers > 0 ? ' and ${plural(s.transfers, 'payment')}' : ''} it added. '
          'You can still restore single expenses from the group’s deleted items.',
      confirmLabel: 'Undo import',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(importClientProvider).undo(b.id);
      refreshLedger(ref.invalidate);
      ref.invalidate(importBatchProvider(b.id));
      if (mounted) showMessage(context, 'Import undone');
    } catch (e) {
      if (mounted) showMessage(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
