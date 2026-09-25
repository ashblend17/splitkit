import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../settlements/settlement_sheet.dart';

class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({super.key, required this.expenseId});
  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expense = ref.watch(expenseProvider(expenseId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    HeaderIconButton(
                      glyph: 'back',
                      label: 'Back',
                      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                    ),
                    const Spacer(),
                    if (expense.value?.deletedAt == null) ...[
                      HeaderIconButton(
                        glyph: 'edit',
                        label: 'Edit expense',
                        onPressed: expense.hasValue ? () => context.push('/expenses/$expenseId/edit') : null,
                      ),
                      const SizedBox(width: 4),
                      HeaderIconButton(
                        glyph: 'trash',
                        label: 'Delete expense',
                        color: SkColors.owe,
                        onPressed: expense.hasValue ? () => _delete(context, ref, expense.value!) : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  ContentWidth(
                    child: AsyncBody(
                      value: expense,
                      onRetry: () => ref.invalidate(expenseProvider(expenseId)),
                      builder: (e) => _Body(expense: e),
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

  Future<void> _delete(BuildContext context, WidgetRef ref, ExpenseOut e) async {
    final people = e.splits.where((s) => s.shareMinor > 0).length;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete “${e.description}”?',
      body:
          'Balances for $people ${people == 1 ? 'person' : 'people'} will change. You can restore it from the group’s deleted items.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final api = ref.read(apiProvider);
    try {
      await api.expenses.deleteExpense(e.id);
      refreshLedger(ref.invalidate);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final container = ProviderScope.containerOf(context, listen: false);
      context.canPop() ? context.pop() : context.go('/home');
      messenger.showSnackBar(
        SnackBar(
          content: Text('“${e.description}” deleted'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: SkColors.brandSoft,
            onPressed: () async {
              await api.expenses.restoreExpense(e.id);
              refreshLedger(container.invalidate);
            },
          ),
        ),
      );
    } catch (err) {
      if (context.mounted) showMessage(context, apiErrorMessage(err));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.expense});
  final ExpenseOut expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final e = expense;
    final c = e.currency;
    final group = ref.watch(groupProvider(e.groupId));
    final myShare = e.splits.where((s) => s.user.id == me.id).firstOrNull;
    final iPaid = e.payer.id == me.id;
    final tone = iPaid && e.myNetMinor > 0
        ? MoneyTone.owed
        : myShare?.status == SplitOutStatusEnum.owes
        ? MoneyTone.owe
        : MoneyTone.settled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.deletedAt != null) ...[_deletedBanner(context, ref), const SizedBox(height: 16)],
        // Hero
        Column(
          children: [
            const SizedBox(height: 8),
            IconTile(
              glyphOr(e.category?.icon),
              background: tone.tileBg,
              foreground: tone.tileFg,
              size: 56,
              radius: 16,
              iconSize: 28,
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(e.description, textAlign: TextAlign.center, style: SkText.display(24, 700)),
            ),
            const SizedBox(height: 8),
            Text(money(e.amountMinor, c), style: SkText.display(44, 800, height: 1)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (group.hasValue) _pill(group.value!.name, SkColors.brandSoft, SkColors.brandInk),
                if (e.category != null) _pill(e.category!.label, SkColors.sunken, SkColors.ink2),
                _pill(entryWhen(e.date, e.createdAt, withDay: true), SkColors.sunken, SkColors.ink2),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
        const SizedBox(height: 16),
        _yourPart(context, ref, me, myShare, iPaid),
        const SizedBox(height: 16),
        _splitCard(me),
        if ((e.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          SkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTES',
                  style: SkText.body(12, 700, color: SkColors.ink2, letterSpacing: 12 * 0.06),
                ),
                const SizedBox(height: 8),
                Text(e.notes!, style: SkText.body(15, 400, height: 1.45)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _history(ref, me),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SkRadius.chip)),
    child: Text(text, style: SkText.body(13, 600, color: fg)),
  );

  Widget _deletedBanner(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        const SkIcon('trash', size: 18, color: SkColors.ink2),
        const SizedBox(width: 8),
        Expanded(
          child: Text("Deleted. It doesn't count towards balances.", style: SkText.body(14, 600, color: SkColors.ink2)),
        ),
        SkButton(
          'Restore',
          variant: SkButtonVariant.secondary,
          size: SkButtonSize.small,
          onPressed: () async {
            await ref.read(apiProvider).expenses.restoreExpense(expense.id);
            refreshLedger(ref.invalidate);
          },
        ),
      ],
    ),
  );

  /// "You owe Rahul ₹450 · Settle up", "You are owed ₹1,350", "You're square with Rahul".
  Widget _yourPart(BuildContext context, WidgetRef ref, UserOut me, SplitOut? mine, bool iPaid) {
    final e = expense;
    final c = e.currency;
    final payerName = firstName(e.payer.name);
    final ({String label, String? figure, Color bg, Color labelColor, Color figureColor, bool settle}) part;
    if (iPaid && e.myNetMinor > 0) {
      part = (
        label: 'You are owed',
        figure: money(e.myNetMinor, c),
        bg: SkColors.owedSoft,
        labelColor: SkColors.owedInk,
        figureColor: SkColors.owed,
        settle: false,
      );
    } else if (iPaid) {
      part = (
        label: 'Only you are in this split',
        figure: null,
        bg: SkColors.settledSoft,
        labelColor: SkColors.ink2,
        figureColor: SkColors.ink2,
        settle: false,
      );
    } else if (mine == null || mine.shareMinor == 0) {
      part = (
        label: "You're not part of this split",
        figure: null,
        bg: SkColors.settledSoft,
        labelColor: SkColors.ink2,
        figureColor: SkColors.ink2,
        settle: false,
      );
    } else if (mine.status == SplitOutStatusEnum.settled) {
      part = (
        label: "You're square with $payerName",
        figure: money(mine.shareMinor, c),
        bg: SkColors.settledSoft,
        labelColor: SkColors.ink2,
        figureColor: SkColors.ink2,
        settle: false,
      );
    } else {
      part = (
        label: 'You owe $payerName',
        figure: money(mine.shareMinor, c),
        bg: SkColors.oweSoft,
        labelColor: SkColors.oweInk,
        figureColor: SkColors.owe,
        settle: e.deletedAt == null,
      );
    }
    final (:label, :figure, :bg, :labelColor, :figureColor, :settle) = part;
    return Semantics(
      label: 'Your part: $label ${figure ?? ''}',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: SkText.body(14, 600, color: labelColor)),
                  if (figure != null) ...[
                    const SizedBox(height: 2),
                    Text(figure, style: SkText.display(30, 800, color: figureColor)),
                  ],
                ],
              ),
            ),
            if (settle)
              SkButton(
                'Settle up',
                variant: SkButtonVariant.strong,
                size: SkButtonSize.small,
                onPressed: () => _settle(context, ref, me),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _settle(BuildContext context, WidgetRef ref, UserOut me) async {
    final e = expense;
    final group = await ref.read(groupProvider(e.groupId).future);
    final balances = await ref.read(groupBalancesProvider(e.groupId).future);
    final withPayer = balances.people.where((p) => p.user.id == e.payer.id).firstOrNull?.netMinor ?? 0;
    if (!context.mounted) return;
    showGroupPaymentSheet(
      context,
      GroupPaymentTarget(
        group: group,
        members: balances.people,
        from: UserBrief(id: me.id, name: me.name, avatarUrl: me.avatarUrl),
        to: e.payer,
        // What you owe the payer across the whole group, not just this expense.
        balanceMinor: withPayer < 0 ? -withPayer : 0,
      ),
    );
  }

  Widget _splitCard(UserOut me) {
    final e = expense;
    final c = e.currency;
    final involved = e.splits.where((s) => s.shareMinor > 0).toList();
    final heading = switch (e.splitMethod) {
      'equal' => 'Split equally between ${involved.length}',
      'exact' => 'Split by exact amounts',
      'percent' => 'Split by percentage',
      'shares' => 'Split by shares',
      _ => 'Split',
    };
    final each = e.splitMethod == 'equal' && involved.isNotEmpty ? '${money(involved.first.shareMinor, c)} each' : null;
    return SkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SkColors.line)),
            ),
            child: Row(
              children: [
                Avatar(personOf(e.payer), size: 36, fontSize: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paid by', style: SkText.body(12, 400, color: SkColors.ink2)),
                      Text(e.payer.id == me.id ? 'You' : e.payer.name, style: SkText.body(15, 700)),
                    ],
                  ),
                ),
                Text(money(e.amountMinor, c), style: SkText.display(18, 700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(heading, style: SkText.body(13, 700, color: SkColors.ink2)),
                ),
                if (each != null) Text(each, style: SkText.body(13, 400, color: SkColors.ink2)),
              ],
            ),
          ),
          for (final s in involved)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 28),
                child: Row(
                  children: [
                    Avatar(personOf(s.user), size: 30, fontSize: 11),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.user.id == me.id ? 'You' : firstName(s.user.name), style: SkText.body(15, 600)),
                    ),
                    _status(s.status),
                    SizedBox(
                      width: 72,
                      child: Text(money(s.shareMinor, c), textAlign: TextAlign.right, style: SkText.display(16, 700)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _status(SplitOutStatusEnum status) {
    final (label, bg, fg) = switch (status) {
      SplitOutStatusEnum.paid => ('Paid', SkColors.sunken, SkColors.ink2),
      SplitOutStatusEnum.settled => ('Settled', SkColors.owedSoft, SkColors.owedInk),
      _ => ('Owes', SkColors.pendingSoft, SkColors.pending),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SkRadius.chip)),
      child: Text(label, style: SkText.body(12, 700, color: fg)),
    );
  }

  /// "Added by Rahul · 23 Sep, 9:42 PM", then one line per later change.
  Widget _history(WidgetRef ref, UserOut me) {
    final e = expense;
    final history = ref.watch(expenseHistoryProvider(e.id)).value ?? const <HistoryEntry>[];
    String who(UserBrief? u) => u == null ? 'Tricount import' : (u.id == me.id ? 'you' : firstName(u.name));
    String at(DateTime t) => DateFormat('d MMM, h:mm a').format(t.toLocal());
    final lines = <String>[
      e.importBatchId != null
          ? 'Imported from Tricount · ${at(e.createdAt)}'
          : 'Added by ${e.createdBy.id == me.id ? 'you' : firstName(e.createdBy.name)} · ${at(e.createdAt)}',
      for (final h in history)
        if (h.action != 'expense.create')
          '${_verb(h.action)} by ${who(h.person)}${h.admin != null ? ' (admin: ${h.admin!.name})' : ''}'
              '${_changes(h.diff, e.currency)} · ${at(h.at)}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) ...[
            Text(l, style: SkText.body(13, 400, color: SkColors.ink2)),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  String _verb(String action) => switch (action) {
    'expense.update' => 'Edited',
    'expense.delete' => 'Deleted',
    'expense.restore' => 'Restored',
    _ => 'Changed',
  };

  /// " · amount ₹1,650 → ₹1,800", " · category, split".
  String _changes(Map<String, Object> diff, String currency) {
    if (diff.isEmpty) return '';
    final parts = <String>[];
    for (final MapEntry(:key, :value) in diff.entries) {
      if (key == 'amount_minor' && value is Map) {
        parts.add('amount ${money(value['from'] as int, currency)} → ${money(value['to'] as int, currency)}');
      } else {
        parts.add(switch (key) {
          'category_id' || 'category' => 'category',
          'payer_id' => 'payer',
          'splits' || 'split_method' => 'split',
          'description' => 'description',
          'date' => 'date',
          'notes' => 'notes',
          _ => key,
        });
      }
    }
    return ' · ${parts.toSet().join(', ')}';
  }
}
