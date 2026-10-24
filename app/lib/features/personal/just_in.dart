import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'personal_txn_sheet.dart';
import 'txn_actions.dart';

/// Overview's "Just in": first a spend and an income from bank SMS that look like one transfer
/// between your accounts (This was a transfer, Not a transfer), then entries the app read from
/// bank SMS that you haven't looked at yet, newest first, each with what can be done with it
/// (Split it, Looks right, Not mine). Nothing at all when there are none.
class JustIn extends ConsumerWidget {
  const JustIn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(featuresProvider).justInLimit;
    final list = ref.watch(personalListProvider(PersonalQuery(source: 'sms', reviewed: false, limit: limit))).value;
    // None while transferSuggestions is off.
    final pairs = (ref.watch(transferSuggestionsProvider).value ?? const <TransferSuggestion>[]).take(limit).toList();
    final entries = list?.items ?? const <PersonalTxnOut>[];
    if (entries.isEmpty && pairs.isEmpty) return const SizedBox.shrink();
    final count = (list?.count ?? 0) + pairs.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text('Just in', style: SkText.section))),
              if (count > 1) StatusChip('$count to check', tone: StatusTone.personal, showDot: false),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in pairs) ...[_TransferCard(p), const SizedBox(height: 8)],
          for (final t in entries) ...[_JustInCard(t), const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

/// "Looks like a transfer · ₹5,000 HDFC ··4821 → ICICI ··9911": a spend and an income that may be
/// one move between your accounts.
class _TransferCard extends ConsumerWidget {
  const _TransferCard(this.pair);
  final TransferSuggestion pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = {for (final a in ref.watch(accountsProvider).value ?? const <FinAccount>[]) a.id: a.name};
    String name(FinEntry e) => names[e.accountId] ?? e.account ?? 'An account';
    final out = pair.outflow, into = pair.inflow;
    final amount = money(out.amount, out.currency);
    return SkCard(
      key: ValueKey('transfer-suggestion:${pair.key}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Looks like a transfer: $amount from ${name(out)} to ${name(into)}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  IconTile('swap', background: SkColors.sunken, foreground: SkColors.ink2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Looks like a transfer', style: SkText.body(15, 700)),
                        Text(
                          '${name(out)} → ${name(into)}',
                          style: SkText.body(13, 400, color: SkColors.ink2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(amount, style: SkText.display(18, 700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SkButton(
                'This was a transfer',
                size: SkButtonSize.small,
                variant: SkButtonVariant.secondary,
                onPressed: () => _pair(context, ref),
              ),
              SkButton(
                'Not a transfer',
                size: SkButtonSize.small,
                variant: SkButtonVariant.ghost,
                onPressed: () => ref.read(notTransferProvider.notifier).dismiss(pair),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Both become the halves of one transfer: neither spending nor income any more.
  Future<void> _pair(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(writesProvider).pairAsTransfer(pair.outflow.id, pair.inflow.id);
      refreshPersonal(ref.invalidate);
    } catch (e) {
      if (context.mounted) showMessage(context, apiErrorMessage(e));
    }
  }
}

class _JustInCard extends ConsumerWidget {
  const _JustInCard(this.txn);
  final PersonalTxnOut txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = personalView(txn, finance: ref.watch(financeEngineProvider).value);
    final (tileBg, tileFg) = personalTile(v);
    return SkCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showPersonalTxnSheet(context, existing: txn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(v.glyph, background: tileBg, foreground: tileFg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.title, style: SkText.body(15, 700), maxLines: 1, overflow: TextOverflow.ellipsis),
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
              ...entryActions(context, ref, txn, likely: true),
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
