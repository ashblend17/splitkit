import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../goals/top_goals_card.dart';
import '../sms/sms_prompt.dart';
import 'accounts_card.dart';
import 'just_in.dart';
import 'personal_txn_sheet.dart';
import 'planned_actual_card.dart';

/// Personal's Overview tab: your own income and spending, kept apart from groups (screen 11).
/// In the design's order (finance revamp §2.4): net worth, this month's cash flow and what was
/// planned from its income, your top goals, bank SMS, then Recent. Entries are added with the floating "Add entry" (or the rail
/// and sidebar).
class PersonalPage extends ConsumerStatefulWidget {
  const PersonalPage({super.key});

  @override
  ConsumerState<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends ConsumerState<PersonalPage> {
  DateTime _month = monthOf(appClock.now());

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(cashFlowProvider(_month));
    final recent = ref.watch(personalListProvider(const PersonalQuery(limit: 5)));
    // Names the account on a transfer's other side in Recent.
    final finance = ref.watch(financeEngineProvider).value;
    final groupShare = ref.watch(integrationsProvider).groupShareInPersonal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.personal,
          onRefresh: () async {
            refreshPersonal(ref.invalidate);
            await ref.read(cashFlowProvider(_month).future);
          },
          child: ListView(
            // Room at the bottom for the floating "Add entry".
            padding: tabPagePadding(context, bottom: 120),
            children: [
              TabPageWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('Overview', style: SkText.title)),
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
                              SkIcon('lock', size: 14, color: SkColors.personalInk),
                              const SizedBox(width: 6),
                              Text('Only you see this', style: SkText.body(12, 700, color: SkColors.personalInk)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Desktop: your money on the left (net worth, this month, bank SMS); your goals and
                    // the latest entries beside it.
                    if (isWideLayout(context))
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [_thisMonth(flow, groupShare), const SmsPromptCard(), const JustIn()],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [const TopGoalsCard(), _recent(recent, finance)],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _thisMonth(flow, groupShare),
                      const TopGoalsCard(),
                      const SmsPromptCard(),
                      const JustIn(),
                      _recent(recent, finance),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Your accounts and net worth, this month's cash flow, then what your rules planned from its
  /// income against what's set aside.
  Widget _thisMonth(AsyncValue<CashFlow> flow, bool groupShare) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AccountsCard(),
      AsyncBody(
        value: flow,
        onRetry: () => ref.invalidate(cashFlowProvider(_month)),
        skeletonRows: 2,
        builder: (f) => _summaryCard(f, groupShare: groupShare),
      ),
      const SizedBox(height: 20),
      PlannedActualCard(month: _month),
    ],
  );

  Widget _recent(AsyncValue<PersonalListOut> recent, FinanceEngine? finance) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text('Recent', style: SkText.section)),
          ),
          InkWell(
            onTap: () => context.go('/personal/transactions'),
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
                  for (final t in list.items) ...[_card(t, finance), const SizedBox(height: 8)],
                ],
              ),
      ),
    ],
  );

  Widget _card(PersonalTxnOut t, FinanceEngine? finance) {
    final v = personalView(t, finance: finance);
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

  /// What you spent in the month and what's left of your income: the finance engine's cash flow.
  /// [groupShare]: your share of group spending shows (an integration, see integrations.dart); it's
  /// part of what you spent while cash flow counts it ([CashFlow.groupShareCounted]).
  Widget _summaryCard(CashFlow f, {required bool groupShare}) {
    final c = ref.watch(meProvider).currency;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            'Spent in ${DateFormat('MMMM').format(_month)}',
            style: SkText.body(14, 600, color: SkColors.ink2),
          ),
        ),
        SkPillButton(shortMonthLabel(_month), trailing: 'down', onPressed: _pickMonth),
      ],
    );
    if (f.isEmpty) {
      return SkCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 18),
            Text('Nothing this month yet', style: SkText.display(22, 700)),
            const SizedBox(height: 6),
            Text(
              'Add what you spend and earn, and this month adds up here.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SkButton(
                'Add entry',
                icon: 'plus',
                size: SkButtonSize.small,
                variant: SkButtonVariant.strong,
                onPressed: () => showPersonalTxnSheet(context),
              ),
            ),
          ],
        ),
      );
    }
    final shareCounted = f.groupShareCounted && f.groupShareMinor > 0;
    // What Spent is made of, when it's more than your own spending.
    final parts = [
      if (f.expensesMinor > 0) _line('On your own', money(f.expensesMinor, c), SkColors.ink),
      if (shareCounted) _line('Your share in groups', money(f.groupShareMinor, c), SkColors.brandInk),
      if (f.refundsMinor > 0) _line('Refunds', money(-f.refundsMinor, c), SkColors.owed),
    ];
    final ownOnly = parts.length == 1 && f.expensesMinor > 0;
    final top = [
      for (final t in f.byCategory.take(3))
        if (t.amountMinor > 0) t,
    ];
    final max = top.isEmpty ? 0 : top.first.amountMinor;
    // With no income logged there's nothing to be left over from (not "overspent").
    final noIncome = f.incomeMinor == 0;
    final over = f.netMinor < 0 && !noIncome;
    final rate = f.savingsRatePercent;
    final behind = rate != null && rate < 0;
    return SkCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(f.consumptionMinor, c), maxLines: 1, style: SkText.display(44, 800, height: 1)),
          ),
          if (parts.isNotEmpty && !ownOnly) ...[
            const SizedBox(height: 10),
            for (final (i, p) in parts.indexed) ...[if (i > 0) const SizedBox(height: 6), p],
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _tile('Income', money(f.incomeMinor, c), SkColors.owedSoft, SkColors.owedInk, SkColors.owed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: over
                    ? _tile('Overspent', money(-f.netMinor, c), SkColors.oweSoft, SkColors.oweInk, SkColors.owe)
                    : _tile(
                        'Left over',
                        noIncome ? '—' : money(f.netMinor, c),
                        SkColors.paper,
                        SkColors.ink2,
                        SkColors.ink,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tile(
                  'Saved',
                  rate == null ? '—' : '${behind ? minus : ''}${rate.abs()}%',
                  behind ? SkColors.oweSoft : SkColors.personalSoft,
                  behind ? SkColors.oweInk : SkColors.personalInk,
                  behind ? SkColors.owe : SkColors.personalInk,
                ),
              ),
            ],
          ),
          // Shown next to your spending but not part of it (groupShareInCashFlow is off).
          if (groupShare && !f.groupShareCounted && f.groupShareMinor > 0) ...[
            const SizedBox(height: 12),
            _line('Your share in groups (not counted)', money(f.groupShareMinor, c), SkColors.brandInk),
          ],
          if (f.investedMinor != 0) ...[
            const SizedBox(height: 12),
            _line('Invested', money(f.investedMinor, c), SkColors.ink),
          ],
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
                          widthFactor: max <= 0 ? 0 : (t.amountMinor / max).clamp(0.0, 1.0),
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

  /// One line of the summary: what, and how much.
  Widget _line(String label, String value, Color color) => Semantics(
    label: '$label: $value',
    child: ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: SkText.body(13, 600, color: SkColors.ink2)),
          ),
          Text(value, style: SkText.body(13, 700, color: color)),
        ],
      ),
    ),
  );

  Widget _tile(String label, String value, Color bg, Color labelColor, Color valueColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: SkText.body(12, 600, color: labelColor)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: SkText.display(18, 700, color: valueColor)),
        ),
      ],
    ),
  );

  Future<void> _pickMonth() async {
    final now = monthOf(appClock.now());
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
                      if (m == _month) SkIcon('check', size: 20, color: SkColors.personal),
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
