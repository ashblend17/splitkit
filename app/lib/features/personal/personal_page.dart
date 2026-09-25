import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'personal_txn_sheet.dart';

/// Your own income and spending, kept apart from groups (screen 11).
class PersonalPage extends ConsumerStatefulWidget {
  const PersonalPage({super.key});

  @override
  ConsumerState<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends ConsumerState<PersonalPage> {
  DateTime _month = monthOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(personalSummaryProvider(_month));
    final recent = ref.watch(personalListProvider((start: null, end: null, type: null, categories: '', limit: 5)));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.brand,
          onRefresh: () async {
            refreshPersonal(ref.invalidate);
            await ref.read(personalSummaryProvider(_month).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('Personal', style: SkText.title)),
                        ),
                        Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: SkColors.personalSoft,
                            borderRadius: BorderRadius.circular(SkRadius.chip),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SkIcon('lock', size: 14, color: SkColors.personalInk),
                              const SizedBox(width: 6),
                              Text('Only you see this', style: SkText.body(12, 700, color: SkColors.personalInk)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AsyncBody(
                      value: summary,
                      onRetry: () => ref.invalidate(personalSummaryProvider(_month)),
                      skeletonRows: 2,
                      builder: _summaryCard,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SkButton(
                            'Expense',
                            icon: 'plus',
                            variant: SkButtonVariant.strong,
                            expand: true,
                            onPressed: () => showPersonalTxnSheet(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SkButton(
                            'Income',
                            icon: 'plus',
                            variant: SkButtonVariant.secondary,
                            expand: true,
                            onPressed: () => showPersonalTxnSheet(context, type: 'income'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('Recent', style: SkText.section)),
                        ),
                        InkWell(
                          onTap: () => context.go('/personal/history'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('See all', style: SkText.body(14, 700, color: SkColors.brandInk)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AsyncBody(
                      value: recent,
                      onRetry: () => ref.invalidate(personalListProvider),
                      builder: (list) => list.items.isEmpty
                          ? const EmptyState(
                              glyph: 'wallet',
                              title: 'Nothing here yet',
                              body: 'Add what you spend and earn. Only you can see it.',
                            )
                          : Column(
                              children: [
                                for (final t in list.items) ...[_card(t), const SizedBox(height: 8)],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(PersonalTxnOut t) {
    final v = personalView(t);
    return TransactionCard(
      title: v.title,
      subtitle: v.subtitle,
      tag: v.tag,
      when: entryWhen(t.date, t.createdAt, withDay: true),
      label: v.label,
      amount: v.amount,
      glyph: v.glyph,
      tone: v.tone,
      scope: TxnScope.personal,
      adminBadge: t.actingAdminId != null,
      onTap: () => showPersonalTxnSheet(context, existing: t),
    );
  }

  Widget _summaryCard(PersonalSummaryOut s) {
    final c = s.currency;
    final top = s.byCategory.take(3).toList();
    final max = top.isEmpty ? 0 : top.first.amountMinor;
    final over = s.leftOverMinor < 0;
    return SkCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spent in ${s.monthLabel.split(' ').first}',
                  style: SkText.body(14, 600, color: SkColors.ink2),
                ),
              ),
              SkPillButton(shortMonthLabel(_month), trailing: 'down', onPressed: _pickMonth),
            ],
          ),
          const SizedBox(height: 14),
          Text(money(s.spentMinor, c), style: SkText.display(44, 800, height: 1)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _tile('Income', money(s.incomeMinor, c), SkColors.owedSoft, SkColors.owedInk, SkColors.owed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: over
                    ? _tile('Overspent', money(-s.leftOverMinor, c), SkColors.oweSoft, SkColors.oweInk, SkColors.owe)
                    : _tile('Left over', money(s.leftOverMinor, c), SkColors.paper, SkColors.ink2, SkColors.ink),
              ),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final (i, t) in top.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              Semantics(
                label: '${t.label}: ${money(t.amountMinor, c)}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(t.label, style: SkText.body(13, 600))),
                          Text(money(t.amountMinor, c), style: SkText.body(13, 400, color: SkColors.ink2)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: SkColors.sunken,
                          borderRadius: BorderRadius.circular(SkRadius.chip),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: max == 0 ? 0 : t.amountMinor / max,
                          child: Container(
                            decoration: BoxDecoration(
                              color: SkColors.personal,
                              borderRadius: BorderRadius.circular(SkRadius.chip),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _tile(String label, String value, Color bg, Color labelColor, Color valueColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: SkText.body(12, 600, color: labelColor)),
        const SizedBox(height: 2),
        Text(value, style: SkText.display(18, 700, color: valueColor)),
      ],
    ),
  );

  Future<void> _pickMonth() async {
    final now = monthOf(DateTime.now());
    final months = [for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i)];
    final picked = await showAppBottomSheet<DateTime>(
      context,
      title: 'Show month',
      child: Column(
        children: [
          for (final m in months)
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(m),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Expanded(child: Text(shortMonthLabel(m), style: SkText.body(15, 600))),
                      if (m == _month) const SkIcon('check', size: 20, color: SkColors.personal),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _month = picked);
  }
}
