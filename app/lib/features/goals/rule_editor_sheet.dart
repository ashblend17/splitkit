import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/local/writes.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'goal_sheet.dart';
import 'plans.dart';

/// A new allocation rule, or rule [existing] to edit (or delete, with Undo): its name, a
/// percentage of each income (to 2 decimals, kept as basis points) or a fixed amount, which income
/// it takes ("From": any, a category's, or an account's), where the money goes ("To": an active
/// goal that counts contributions, or an open account) and whether it's on. Warns as you type when
/// your rules would set aside more than all of an income (allowed, never changed).
Future<void> showRuleEditor(BuildContext context, {FinRule? existing}) =>
    showGoalSheet<bool>(context, _RuleEditor(existing: existing));

/// Which income a rule takes.
enum _From { any, category, account }

/// Where a rule sends the money.
enum _To { goal, account }

class _RuleEditor extends ConsumerStatefulWidget {
  const _RuleEditor({this.existing});
  final FinRule? existing;

  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  FinRule? get _rule => widget.existing;
  String get _currency => _rule?.currency ?? ref.read(meProvider).currency;
  late final _name = TextEditingController(text: _rule?.name ?? '');
  late final _percent = TextEditingController(
    text: _rule?.percentBp == null ? '' : returnPercentLabel(_rule!.percentBp!).replaceAll('%', ''),
  );
  late final _amount = TextEditingController(
    text: _rule?.amountMinor == null ? '' : amountFieldText(_rule!.amountMinor!, _currency),
  );
  late AllocationKind _kind = _rule?.kind ?? AllocationKind.percentage;
  late _From _from = _rule?.sourceCategoryId != null
      ? _From.category
      : (_rule?.sourceAccountId != null ? _From.account : _From.any);
  late String? _categoryId = _rule?.sourceCategoryId, _sourceAccountId = _rule?.sourceAccountId;
  late _To _to = _rule?.accountId != null ? _To.account : _To.goal;
  late String? _goalId = _rule?.goalId, _accountId = _rule?.accountId;
  late bool _active = _rule?.active ?? true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _percent, _amount]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _percent, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The percentage typed, in basis points ("12.5" is 1250); null when empty; -1 when it isn't a
  /// percentage from 0.01% to 1000%.
  int? get _bp {
    final t = _percent.text.trim().replaceAll('%', '');
    if (t.isEmpty) return null;
    final m = RegExp(r'^(\d{1,4})(?:\.(\d{0,2}))?$').firstMatch(t);
    if (m == null) return -1;
    final bp = int.parse(m.group(1)!) * 100 + int.parse((m.group(2) ?? '').padRight(2, '0'));
    return bp < 1 || bp > 100000 ? -1 : bp;
  }

  /// The rule as the editor has it, or null while its amount isn't one.
  RuleDraft? _draft() {
    final bp = _bp, amount = typedAmount(_amount, _currency);
    final percentage = _kind == AllocationKind.percentage;
    if (percentage ? (bp == null || bp < 0) : (amount ?? 0) <= 0) return null;
    final name = _name.text.trim();
    return RuleDraft(
      kind: _kind,
      name: name.isEmpty ? null : name,
      percentBp: percentage ? bp : null,
      amountMinor: percentage ? null : amount,
      sourceCategoryId: _from == _From.category ? _categoryId : null,
      sourceAccountId: _from == _From.account ? _sourceAccountId : null,
      goalId: _to == _To.goal ? _goalId : null,
      accountId: _to == _To.account ? _accountId : null,
      active: _active,
      priority: _rule?.priority ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = _currency;
    final finance = ref.watch(financeEngineProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? const <FinAccount>[];
    final categories = [
      for (final c in ref.watch(personalCategoriesProvider).value ?? const <CategoryOut>[])
        if (c.key == 'income' || c.ownerId != null || c.id == _rule?.sourceCategoryId) c,
    ];
    final sources = [
      for (final a in accounts)
        if (!a.closed || a.id == _rule?.sourceAccountId) a,
    ];
    final goals = [
      for (final g in ref.watch(goalsProvider).value ?? const <GoalProgress>[])
        if ((g.goal.mode == GoalMode.contribution && g.goal.status == GoalStatus.active) || g.goal.id == _rule?.goalId)
          g.goal,
    ];
    final destinations = [
      for (final a in accounts)
        if ((!a.closed && a.currency == currency) || a.id == _rule?.accountId) a,
    ];
    final draft = _draft();
    final load = draft == null
        ? null
        : finance?.allocationLoad(
            draft: draft.toRule(id: _rule?.id ?? '', currency: currency),
          );
    final nameTooLong = _name.text.trim().length > 60;
    final canSave =
        !_busy &&
        draft != null &&
        !nameTooLong &&
        (draft.goalId ?? draft.accountId) != null &&
        switch (_from) {
          _From.any => true,
          _From.category => _categoryId != null,
          _From.account => _sourceAccountId != null,
        };
    return GoalSheetFrame(
      title: _rule == null ? 'New rule' : 'Edit rule',
      subtitle: 'Each time income comes in, a rule plans part of it for a goal or an account.',
      children: [
        SkTextField(
          key: const Key('rule-name'),
          label: 'Name (optional)',
          controller: _name,
          hint: 'Trip fund, Emergency top-up…',
          errorText: nameTooLong ? 'At most 60 characters' : null,
        ),
        const SizedBox(height: 16),
        fieldLabel('How much'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (kind, label) in [(AllocationKind.percentage, 'Percentage'), (AllocationKind.fixed, 'Fixed')])
              SelectableChip(
                label: label,
                selected: kind == _kind,
                accent: ChipAccent.personal,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_kind == AllocationKind.percentage)
          SkTextField(
            key: const Key('rule-percent'),
            label: 'Percent of each income',
            controller: _percent,
            hint: '10',
            errorText: _bp == -1 ? 'A percentage from 0.01 to 1000, like 10 or 12.5' : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          )
        else
          amountField('Amount from each income', _amount, currency, key: const Key('rule-amount')),
        const SizedBox(height: 16),
        fieldLabel('From'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (from, label) in [
              (_From.any, 'Any income'),
              (_From.category, 'A category'),
              (_From.account, 'An account'),
            ])
              SelectableChip(
                label: label,
                selected: from == _from,
                accent: ChipAccent.personal,
                onTap: () => setState(() => _from = from),
              ),
          ],
        ),
        if (_from == _From.category) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                SelectableChip(
                  label: c.label,
                  icon: glyphOr(c.icon),
                  selected: c.id == _categoryId,
                  accent: ChipAccent.personal,
                  onTap: () => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          fieldHint('Only income in this category.'),
        ],
        if (_from == _From.account) ...[
          const SizedBox(height: 10),
          if (sources.isEmpty)
            Text('No account yet.', style: SkText.body(13, 400, color: SkColors.ink2))
          else
            accountChips(sources, selected: _sourceAccountId, onPick: (id) => setState(() => _sourceAccountId = id)),
          fieldHint('Only income received in this account.'),
        ],
        const SizedBox(height: 16),
        fieldLabel('To'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (to, label) in [(_To.goal, 'A goal'), (_To.account, 'An account')])
              SelectableChip(
                label: label,
                selected: to == _to,
                accent: ChipAccent.personal,
                onTap: () => setState(() => _to = to),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_to == _To.goal)
          goals.isEmpty
              ? Text(
                  'No goal takes money yet: add a goal that counts contributions.',
                  style: SkText.body(13, 400, color: SkColors.ink2),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in goals)
                      SelectableChip(
                        label: g.name,
                        icon: 'target',
                        selected: g.id == _goalId,
                        accent: ChipAccent.personal,
                        onTap: () => setState(() => _goalId = g.id),
                      ),
                  ],
                )
        else if (destinations.isEmpty)
          Text('No open account yet.', style: SkText.body(13, 400, color: SkColors.ink2))
        else
          accountChips(destinations, selected: _accountId, onPick: (id) => setState(() => _accountId = id)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('On', style: SkText.body(14, 600)),
                  Text('While it\'s off, it makes no plans.', style: SkText.body(12, 400, color: SkColors.ink2)),
                ],
              ),
            ),
            Switch(
              key: const Key('rule-active'),
              value: _active,
              activeColor: SkColors.personal,
              onChanged: (on) => setState(() => _active = on),
            ),
          ],
        ),
        if (load != null && load.over100) ...[const SizedBox(height: 12), LoadWarning(load: load, would: true)],
        const SizedBox(height: 12),
        Text(
          'Applies to income recorded from now on. Plans already made keep their amounts.',
          style: SkText.body(12, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 18),
        SkButton(
          _busy ? 'Saving…' : (_rule == null ? 'Add rule' : 'Save changes'),
          size: SkButtonSize.large,
          expand: true,
          onPressed: canSave ? () => _save(draft) : null,
        ),
        if (_rule != null) ...[
          const SizedBox(height: 8),
          SkButton(
            'Delete rule',
            icon: 'trash',
            variant: SkButtonVariant.danger,
            expand: true,
            onPressed: _busy ? null : () => _delete(finance),
          ),
        ],
      ],
    );
  }

  Future<void> _save(RuleDraft draft) async {
    final before = _rule;
    setState(() => _busy = true);
    final ok = await runGoalWrite(context, ref, (w) async {
      if (before == null) {
        await w.createRule(draft);
      } else {
        await w.updateRule(before.id, draft);
      }
    }, pop: false);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  /// Deletes the rule, with Undo. Its plans stay.
  Future<void> _delete(FinanceEngine? finance) async {
    final r = _rule!;
    setState(() => _busy = true);
    final ok = await runGoalWrite(
      context,
      ref,
      (w) => w.deleteRule(r.id),
      done: 'Deleted ${ruleTitle(finance, r)}',
      undo: (w) => w.restoreRule(r.id),
      pop: false,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }
}

/// The over-100% warning ([AllocationLoad.over100]) on the Rules page, or in the editor ([would])
/// as you type: allowed, never changed. Fixed amounts are said apart.
class LoadWarning extends ConsumerWidget {
  const LoadWarning({super.key, required this.load, this.would = false});
  final AllocationLoad load;
  final bool would;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeEngineProvider).value;
    final category = load.categoryId == null
        ? null
        : [
            for (final c in ref.watch(allCategoriesProvider).value ?? const <CategoryOut>[])
              if (c.id == load.categoryId) c.label,
          ].firstOrNull;
    final account = load.accountId == null ? null : finance?.account(load.accountId!)?.name;
    final text = overLoadSentence(
      load,
      category: category,
      account: account,
      would: would,
      currency: ref.watch(meProvider).currency,
    );
    return Container(
      key: const Key('rule-load-warning'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SkColors.pendingSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkIcon('alert', size: 18, color: SkPalette.pendingInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: SkText.body(13, 600, color: SkPalette.pendingInk)),
          ),
        ],
      ),
    );
  }
}
