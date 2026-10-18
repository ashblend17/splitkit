import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/local/personal_index.dart' show localDay;
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../personal/personal_txn_sheet.dart';
import 'goal_sheet.dart';

/// "Add money" to goal [p], as its mode allows: a contribution for a goal that counts them
/// ([ContributionSheet]); for one that follows an account, the transfer sheet, to move money
/// there; for one tracked by hand, "Update progress".
Future<void> showAddMoney(BuildContext context, GoalProgress p) async {
  switch (p.goal.mode) {
    case GoalMode.contribution:
      await showGoalSheet<bool>(context, ContributionSheet(goal: p));
    case GoalMode.linkedBalance:
      await showPersonalTxnSheet(context, type: 'transfer');
    case GoalMode.manual:
      await showUpdateProgressSheet(context, p);
  }
}

/// Edit contribution [c] of goal [p]: its amount, date, goal and note.
Future<void> showEditContribution(BuildContext context, GoalProgress p, ContributionView c) =>
    showGoalSheet<bool>(context, ContributionSheet(goal: p, existing: c));

/// "Update progress" for goal [p], tracked by hand: what's saved now.
Future<void> showUpdateProgressSheet(BuildContext context, GoalProgress p) =>
    showGoalSheet<bool>(context, _UpdateProgress(p));

/// How the money for a new contribution moved.
enum _How {
  notRecorded('Not recorded'),
  transfer('Between my accounts'),
  invested('Invested'),
  entry('An existing entry');

  const _How(this.label);
  final String label;
}

/// A contribution to goal [goal] (or, with [existing], that one to edit): the amount, date, goal
/// and note, and for a new one how the money moved: not recorded anywhere, between two of your
/// accounts (a transfer, made with it), invested (an investment entry, made with it), or an
/// entry already there (a transfer in or an investment that counts toward no goal yet, of at
/// least this much).
class ContributionSheet extends ConsumerStatefulWidget {
  const ContributionSheet({super.key, required this.goal, this.existing});

  final GoalProgress goal;
  final ContributionView? existing;

  @override
  ConsumerState<ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<ContributionSheet> {
  ContributionView? get _existing => widget.existing;
  String get _currency => widget.goal.goal.currency;
  late final _amount = TextEditingController(
    text: _existing == null ? '' : amountFieldText(_existing!.contribution.amountMinor, _currency),
  );
  late final _note = TextEditingController(text: _existing?.contribution.note ?? '');
  late DateTime _date = _existing == null ? _today() : localDay(_existing!.contribution.day);
  late String _goalId = widget.goal.goal.id;
  _How _how = _How.notRecorded;
  String? _from, _to, _holdingId, _entryId;
  bool _busy = false;

  static DateTime _today() {
    final now = appClock.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = typedAmount(_amount, _currency);
    final finance = ref.watch(financeEngineProvider).value;
    final open = [
      for (final a in ref.watch(accountsProvider).value ?? const <FinAccount>[])
        if (!a.closed && a.currency == _currency) a,
    ];
    final goals = [
      for (final g in ref.watch(goalsProvider).value ?? const <GoalProgress>[])
        if (g.goal.mode == GoalMode.contribution && g.goal.status != GoalStatus.archived) g.goal,
    ];
    final entries = _how == _How.entry && finance != null ? _candidates(finance, amount) : const <PersonalTxnOut>[];
    final ready =
        !_busy &&
        (amount ?? 0) > 0 &&
        switch (_how) {
          _How.notRecorded => true,
          _How.transfer => _from != null && _to != null && _from != _to,
          _How.invested => _from != null,
          _How.entry => _entryId != null && entries.any((e) => e.id == _entryId),
        };
    return GoalSheetFrame(
      title: _existing == null ? 'Add money' : 'Edit contribution',
      subtitle: _existing == null ? 'To ${widget.goal.goal.name}' : null,
      children: [
        amountField('Amount', _amount, _currency, key: const Key('contribution-amount')),
        const SizedBox(height: 14),
        fieldLabel('Date'),
        GoalDateButton(
          date: _date,
          first: DateTime(2000),
          last: _today().add(const Duration(days: 365)),
          onPicked: (d) => setState(() => _date = d),
        ),
        if (_existing != null && goals.length > 1) ...[
          const SizedBox(height: 14),
          fieldLabel('Goal'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in goals)
                SelectableChip(
                  label: g.name,
                  selected: g.id == _goalId,
                  accent: ChipAccent.personal,
                  onTap: () => setState(() => _goalId = g.id),
                ),
            ],
          ),
        ],
        if (_existing == null) ...[
          const SizedBox(height: 16),
          fieldLabel('How did the money move?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _How.values)
                SelectableChip(
                  label: h.label,
                  selected: h == _how,
                  accent: ChipAccent.personal,
                  // Between my accounts needs two.
                  onTap: h == _How.transfer && open.length < 2 ? null : () => setState(() => _how = h),
                ),
            ],
          ),
          ..._howFields(open, finance, entries),
        ],
        const SizedBox(height: 14),
        SkTextField(key: const Key('contribution-note'), label: 'Note (optional)', controller: _note),
        const SizedBox(height: 18),
        SkButton(
          _busy ? 'Saving…' : (_existing == null ? 'Add money' : 'Save changes'),
          size: SkButtonSize.large,
          expand: true,
          onPressed: ready ? () => _save(amount!) : null,
        ),
        if (_existing != null) ...[
          const SizedBox(height: 8),
          SkButton(
            'Delete',
            icon: 'trash',
            variant: SkButtonVariant.danger,
            expand: true,
            onPressed: _busy ? null : _delete,
          ),
        ],
      ],
    );
  }

  List<Widget> _howFields(List<FinAccount> open, FinanceEngine? finance, List<PersonalTxnOut> entries) =>
      switch (_how) {
        _How.notRecorded => [fieldHint('Just noted here, like cash put aside. No entry is added.')],
        _How.transfer => [
          const SizedBox(height: 14),
          fieldLabel('From'),
          accountChips(open, selected: _from, disabled: _to, onPick: (id) => setState(() => _from = id)),
          const SizedBox(height: 14),
          fieldLabel('To'),
          accountChips(open, selected: _to, disabled: _from, onPick: (id) => setState(() => _to = id)),
          fieldHint('Adds the transfer to your entries too.'),
        ],
        _How.invested => [
          const SizedBox(height: 14),
          fieldLabel('Paid from'),
          accountChips(open, selected: _from, onPick: (id) => setState(() => _from = id)),
          if (finance != null && finance.holdings.isNotEmpty) ...[
            const SizedBox(height: 14),
            fieldLabel('Into (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in finance.holdings)
                  if (h.currency == _currency)
                    SelectableChip(
                      label: h.name,
                      selected: h.id == _holdingId,
                      accent: ChipAccent.personal,
                      onTap: () => setState(() => _holdingId = h.id == _holdingId ? null : h.id),
                    ),
              ],
            ),
          ],
          fieldHint('Adds the investment to your entries too.'),
        ],
        _How.entry => [
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No transfer in or investment to use: each counts toward one goal, and must be at least this much.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            )
          else
            for (final e in entries) _entryRow(e, finance),
        ],
      };

  /// Recent transfers in and investments in this currency that count toward no goal, could
  /// count toward this one, and are at least [amount].
  List<PersonalTxnOut> _candidates(FinanceEngine finance, int? amount) {
    final transfers = ref.watch(personalListProvider(const PersonalQuery(type: 'transfer', limit: 60))).value;
    final invested = ref
        .watch(personalListProvider(const PersonalQuery(type: 'investment_contribution', limit: 30)))
        .value;
    return [
      for (final t in [...?transfers?.items, ...?invested?.items])
        if (t.currency == _currency &&
            (t.type != PersonalTxnOutTypeEnum.transfer || t.direction == PersonalTxnOutDirectionEnum.in_) &&
            (amount == null || t.amountMinor >= amount) &&
            finance.contributionBlocker(goalId: _goalId, entryId: t.id) == null)
          t,
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  Widget _entryRow(PersonalTxnOut t, FinanceEngine? finance) {
    final selected = t.id == _entryId;
    final account = t.accountId == null ? t.account : finance?.account(t.accountId!)?.name ?? t.account;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('entry:${t.id}'),
        onTap: () => setState(() {
          _entryId = t.id;
          if (_amount.text.trim().isEmpty) _amount.text = amountFieldText(t.amountMinor, _currency);
          _date = DateTime(t.date.year, t.date.month, t.date.day);
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SkColors.personalSoft : SkColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? SkColors.personal : SkColors.line, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.description, style: SkText.body(14, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text([dayLabel(t.date), ?account].join(' · '), style: SkText.body(12, 400, color: SkColors.ink2)),
                  ],
                ),
              ),
              Text(money(t.amountMinor, t.currency), style: SkText.body(14, 700)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(int amount) async {
    final goalId = _goalId, date = _date, note = _note.text.trim();
    final existing = _existing;
    setState(() => _busy = true);
    final name = widget.goal.goal.name;
    final ok = await runGoalWrite(context, ref, (w) async {
      if (existing != null) {
        await w.updateContribution(
          existing.contribution.id,
          goalId: goalId,
          amountMinor: amount,
          date: date,
          note: note,
        );
        return;
      }
      switch (_how) {
        case _How.notRecorded:
          await w.addContribution(goalId: goalId, amountMinor: amount, date: date, note: note.isEmpty ? null : note);
        case _How.transfer:
          await w.contributeByTransfer(
            goalId: goalId,
            fromAccountId: _from!,
            toAccountId: _to!,
            amountMinor: amount,
            date: date,
            note: note.isEmpty ? null : note,
          );
        case _How.invested:
          await w.contributeByInvestment(
            goalId: goalId,
            fromAccountId: _from!,
            amountMinor: amount,
            date: date,
            holdingId: _holdingId,
            note: note.isEmpty ? null : note,
          );
        case _How.entry:
          await w.addContribution(
            goalId: goalId,
            amountMinor: amount,
            date: date,
            entryId: _entryId,
            note: note.isEmpty ? null : note,
          );
      }
    }, done: existing == null ? 'Added ${money(amount, _currency)} to $name' : 'Saved the contribution');
    if (!ok && mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final c = _existing!.contribution;
    setState(() => _busy = true);
    final ok = await runGoalWrite(
      context,
      ref,
      (w) => w.deleteContribution(c.id),
      done: 'Deleted ${money(c.amountMinor, c.currency)} from ${widget.goal.goal.name}',
      undo: (w) => w.restoreContribution(c.id),
    );
    if (!ok && mounted) setState(() => _busy = false);
  }
}

/// "Update progress": what's saved now, for a goal tracked by hand.
class _UpdateProgress extends ConsumerStatefulWidget {
  const _UpdateProgress(this.p);
  final GoalProgress p;

  @override
  ConsumerState<_UpdateProgress> createState() => _UpdateProgressState();
}

class _UpdateProgressState extends ConsumerState<_UpdateProgress> {
  late final _amount = TextEditingController(text: amountFieldText(widget.p.progressMinor, widget.p.goal.currency));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.p.goal;
    final amount = typedAmount(_amount, g.currency);
    return GoalSheetFrame(
      title: 'Update progress',
      subtitle: '${g.name}: target ${money(g.targetMinor, g.currency)}',
      children: [
        amountField('Saved so far', _amount, g.currency, key: const Key('progress-amount')),
        const SizedBox(height: 18),
        SkButton(
          _busy ? 'Saving…' : 'Save',
          size: SkButtonSize.large,
          expand: true,
          onPressed: _busy || amount == null ? null : () => _save(amount),
        ),
      ],
    );
  }

  Future<void> _save(int amount) async {
    final g = widget.p.goal, before = widget.p.progressMinor;
    setState(() => _busy = true);
    final ok = await runGoalWrite(
      context,
      ref,
      (w) => w.setGoalProgress(g.id, amount),
      done: '${g.name}: ${money(amount, g.currency)} saved',
      undo: (w) => w.setGoalProgress(g.id, before),
    );
    if (!ok && mounted) {
      setState(() => _busy = false);
    }
  }
}

/// The entry contribution [c] was made with, opened in the entry sheet; says so if it's gone.
Future<void> openContributionEntry(BuildContext context, WidgetRef ref, ContributionView c) async {
  final id = c.contribution.transactionId;
  if (id == null) return;
  try {
    final t = await ref.read(personalTxnProvider(id).future);
    if (context.mounted) await showPersonalTxnSheet(context, existing: t);
  } catch (e) {
    if (context.mounted) sayDone(ScaffoldMessenger.of(context), apiErrorMessage(e));
  }
}
