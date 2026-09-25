import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'split_config_page.dart';

/// Add split, or edit one when [editExpenseId] is set.
class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key, this.groupId, this.editExpenseId});
  final String? groupId;
  final String? editExpenseId;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _amountText = TextEditingController();
  String? _groupId;
  int? _amount;
  String? _categoryId;
  String? _payerId;
  DateTime _date = DateTime.now();
  SplitController? _split;
  String? _splitGroupId;
  bool _prefilled = false;
  bool _allCategories = false;
  bool _busy = false;

  bool get _editing => widget.editExpenseId != null;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    _notes.dispose();
    _amountText.dispose();
    _split?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final groups = ref.watch(groupsProvider);
    final expense = _editing ? ref.watch(expenseProvider(widget.editExpenseId!)) : null;

    Widget body;
    if (groups.hasError || (expense?.hasError ?? false)) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorState(
          title: "Couldn't load this",
          body: apiErrorMessage(groups.error ?? expense!.error!),
          onRetry: () => refreshLedger(ref.invalidate),
        ),
      );
    } else if (!groups.hasValue || (expense != null && !expense.hasValue)) {
      body = const Padding(padding: EdgeInsets.all(16), child: LoadingSkeleton());
    } else if (groups.value!.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          title: 'Make a group first',
          body: 'Splits live in a group: your flat, a trip, a dinner.',
          actionLabel: 'Create a group',
          onAction: () => context.go('/groups?new=1'),
        ),
      );
    } else {
      _prepare(me, groups.value!, expense?.value);
      body = _form(me, groups.value!.firstWhere((g) => g.id == _groupId));
    }

    final group = groups.value?.where((g) => g.id == _groupId).firstOrNull;
    return Scaffold(
      backgroundColor: SkColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SkColors.line)),
              ),
              child: Row(
                children: [
                  HeaderIconButton(
                    glyph: 'close',
                    label: 'Close',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  Expanded(
                    child: Center(
                      child: Semantics(
                        header: true,
                        child: Text(_editing ? 'Edit split' : 'Add split', style: SkText.display(18, 700)),
                      ),
                    ),
                  ),
                  if (group != null)
                    _GroupChip(name: group.name, onTap: _editing ? null : () => _pickGroup(groups.value!))
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(child: body),
            if (_split != null && group != null) _footer(me, group),
          ],
        ),
      ),
    );
  }

  /// Picks the group, builds the split for its members, and pre-fills when editing.
  void _prepare(UserOut me, List<GroupOut> groups, ExpenseOut? editing) {
    _groupId ??= editing?.groupId ?? widget.groupId ?? _mostRecent(groups).id;
    if (!groups.any((g) => g.id == _groupId)) _groupId = _mostRecent(groups).id;
    final group = groups.firstWhere((g) => g.id == _groupId);
    if (_splitGroupId == group.id) return;

    final people = [for (final m in group.members) _person(m.user, me.id)];
    if (editing != null) {
      for (final s in editing.splits) {
        if (!people.any((p) => p.id == s.user.id)) people.add(_person(s.user, me.id));
      }
    }
    // The viewer first, as in the mockups.
    people.sort(
      (a, b) => a.id == me.id
          ? -1
          : b.id == me.id
          ? 1
          : 0,
    );

    _split?.dispose();
    if (editing != null && !_prefilled) {
      _prefilled = true;
      _amount = editing.amountMinor;
      _amountText.text = money(
        editing.amountMinor,
        editing.currency,
      ).substring(currencySymbol(editing.currency).length);
      _description.text = editing.description;
      _notes.text = editing.notes ?? '';
      _categoryId = editing.category?.id;
      _payerId = editing.payer.id;
      _date = editing.date;
      final method = editing.splitMethod;
      String text(SplitOut s) => method == 'exact'
          ? money(s.shareMinor, editing.currency).substring(currencySymbol(editing.currency).length)
          : s.inputValue ?? '';
      _split = SplitController(
        people: people,
        totalMinor: editing.amountMinor,
        currency: editing.currency,
        method: method,
        included: method == 'equal' ? {for (final s in editing.splits) s.user.id} : null,
        values: method == 'equal'
            ? null
            : {
                method: {for (final s in editing.splits) s.user.id: text(s)},
              },
      );
    } else {
      _payerId = people.any((p) => p.id == _payerId) ? _payerId : me.id;
      _split = SplitController(people: people, totalMinor: _amount ?? 0, currency: group.currency);
    }
    _split!.addListener(() => setState(() {}));
    _splitGroupId = group.id;
  }

  GroupOut _mostRecent(List<GroupOut> groups) => groups.reduce((a, b) {
    final at = a.lastActivityAt ?? a.createdAt;
    final bt = b.lastActivityAt ?? b.createdAt;
    return bt.isAfter(at) ? b : a;
  });

  SkPerson _person(UserBrief u, String meId) =>
      SkPerson(id: u.id, name: displayName(u, meId), initials: initialsFor(u.name));

  Widget _form(UserOut me, GroupOut group) {
    final categories = ref.watch(groupCategoriesProvider);
    final payer = _split!.people.firstWhere((p) => p.id == _payerId, orElse: () => _split!.people.first);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: AmountInput(
                  controller: _amountText,
                  currency: group.currency,
                  autofocus: !_editing,
                  onChanged: (m) => setState(() {
                    _amount = m;
                    _split!.totalMinor = m ?? 0;
                  }),
                ),
              ),
              const SizedBox(height: 20),
              SkTextField(
                label: 'What was it for?',
                controller: _description,
                size: SkFieldSize.large,
                hint: 'Dinner, taxi, rent…',
              ),
              const SizedBox(height: 20),
              Text('Category', style: SkText.body(14, 600)),
              const SizedBox(height: 8),
              AsyncBody(
                value: categories,
                onRetry: () => ref.invalidate(groupCategoriesProvider),
                skeletonRows: 1,
                builder: (cats) {
                  final shown = _allCategories || cats.length <= 7 ? cats : cats.take(6).toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in shown)
                        SelectableChip(
                          label: c.label,
                          icon: glyphOr(c.icon),
                          selected: c.id == _categoryId,
                          onTap: () => setState(() => _categoryId = c.id == _categoryId ? null : c.id),
                        ),
                      if (cats.length > 7)
                        SelectableChip(
                          label: _allCategories ? 'Less' : 'More',
                          icon: 'other',
                          selected: false,
                          onTap: () => setState(() => _allCategories = !_allCategories),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SkColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _row(
                      label: 'Paid by',
                      onTap: () => _pickPayer(me),
                      child: Row(
                        children: [
                          Avatar(payer, size: 28, fontSize: 11),
                          const SizedBox(width: 12),
                          Expanded(child: Text(payer.name, style: SkText.body(15, 600))),
                        ],
                      ),
                      trailing: const SkIcon('next', size: 18),
                    ),
                    _row(
                      label: 'Split',
                      onTap: () => _openSplit(payer),
                      child: _splitSummary(),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [_validBadge(), const SizedBox(width: 8), const SkIcon('next', size: 18)],
                      ),
                    ),
                    _row(
                      label: 'Date',
                      onTap: _pickDate,
                      child: Text(formDateLabel(_date), style: SkText.body(15, 600)),
                      trailing: const SkIcon('calendar', size: 18),
                    ),
                    _row(
                      label: 'Notes',
                      last: true,
                      child: TextField(
                        controller: _notes,
                        style: SkText.body(15, 400),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Optional',
                          hintStyle: SkText.body(15, 400, color: SkColors.ink3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row({
    required String label,
    required Widget child,
    VoidCallback? onTap,
    Widget? trailing,
    bool last = false,
  }) {
    return Material(
      color: SkColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: SkColors.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(label, style: SkText.body(14, 400, color: SkColors.ink2)),
              ),
              Expanded(child: child),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _splitSummary() {
    final c = _split!;
    final v = c.validation;
    final (title, sub) = switch (c.method) {
      'equal' => (
        'Equally · ${c.inputs.length} ${c.inputs.length == 1 ? 'person' : 'people'}',
        v.ok ? '${money(c.shares!.first.shareMinor, c.currency)} each' : null,
      ),
      'exact' => ('Exact amounts', v.ok ? null : v.message),
      'percent' => ('By percentage', v.ok ? null : v.message),
      _ => ('By shares', v.ok ? null : v.message),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SkText.body(15, 600)),
          if (sub != null && (_amount ?? 0) > 0) Text(sub, style: SkText.body(13, 400, color: SkColors.ink2)),
        ],
      ),
    );
  }

  Widget _validBadge() {
    final ok = _split!.validation.ok;
    if ((_amount ?? 0) == 0) return const SizedBox.shrink();
    final color = ok ? SkColors.owed : SkColors.pending;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkIcon(ok ? 'check' : 'alert', size: 14, color: color),
        const SizedBox(width: 4),
        Text(ok ? 'Valid' : 'Fix', style: SkText.body(12, 700, color: color)),
      ],
    );
  }

  Widget _footer(UserOut me, GroupOut group) {
    final c = _split!;
    final v = c.validation;
    final amount = _amount ?? 0;
    final payer = c.people.firstWhere((p) => p.id == _payerId, orElse: () => c.people.first);

    ({String text, String? figure, Color bg, Color fg, Color figureColor}) summary;
    if (amount == 0) {
      summary = (
        text: 'Enter an amount',
        figure: null,
        bg: SkColors.sunken,
        fg: SkColors.ink2,
        figureColor: SkColors.ink2,
      );
    } else if (!v.ok) {
      summary = (
        text: v.message,
        figure: null,
        bg: SkColors.pendingSoft,
        fg: SkColors.pending,
        figureColor: SkColors.pending,
      );
    } else {
      final myShare = c.shares!.where((s) => s.userId == me.id).firstOrNull?.shareMinor ?? 0;
      if (payer.id == me.id) {
        final owed = amount - myShare;
        summary = owed == 0
            ? (
                text: 'Only you are in this split',
                figure: null,
                bg: SkColors.settledSoft,
                fg: SkColors.ink2,
                figureColor: SkColors.ink2,
              )
            : (
                text: 'You will be owed',
                figure: money(owed, c.currency),
                bg: SkColors.owedSoft,
                fg: SkColors.owedInk,
                figureColor: SkColors.owed,
              );
      } else if (myShare > 0) {
        summary = (
          text: 'You will owe ${payer.name}',
          figure: money(myShare, c.currency),
          bg: SkColors.oweSoft,
          fg: SkColors.oweInk,
          figureColor: SkColors.owe,
        );
      } else {
        summary = (
          text: "You're not part of this split",
          figure: null,
          bg: SkColors.settledSoft,
          fg: SkColors.ink2,
          figureColor: SkColors.ink2,
        );
      }
    }

    final canSave = !_busy && amount > 0 && v.ok && _description.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      decoration: const BoxDecoration(
        color: SkColors.surface,
        border: Border(top: BorderSide(color: SkColors.line)),
      ),
      child: ContentWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: summary.bg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(summary.text, style: SkText.body(14, 600, color: summary.fg)),
                    ),
                    if (summary.figure != null)
                      Text(summary.figure!, style: SkText.display(20, 800, color: summary.figureColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SkButton(
              _busy ? 'Saving…' : (_editing ? 'Save changes' : 'Save split'),
              size: SkButtonSize.large,
              expand: true,
              onPressed: canSave ? () => _save(group) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSplit(SkPerson payer) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SplitConfigPage(
          controller: _split!,
          description: _description.text.trim(),
          payerId: payer.id,
          payerName: payer.name,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickPayer(UserOut me) async {
    final picked = await showAppBottomSheet<String>(
      context,
      title: 'Paid by',
      child: Column(
        children: [
          for (final p in _split!.people)
            Builder(
              builder: (sheet) =>
                  SheetPersonOption(person: p, selected: p.id == _payerId, onTap: () => Navigator.of(sheet).pop(p.id)),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _payerId = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickGroup(List<GroupOut> groups) async {
    final picked = await showAppBottomSheet<String>(
      context,
      title: 'Which group?',
      child: Column(
        children: [
          for (final g in groups)
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(g.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      SkIcon(glyphOr(g.icon, 'groups'), size: 20, color: SkColors.brandInk),
                      const SizedBox(width: 10),
                      Expanded(child: Text(g.name, style: SkText.body(15, 600))),
                      if (g.id == _groupId) const SkIcon('check', size: 20, color: SkColors.brand),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null && picked != _groupId) setState(() => _groupId = picked);
  }

  Future<void> _save(GroupOut group) async {
    setState(() => _busy = true);
    final c = _split!;
    final body = ExpenseIn(
      description: _description.text.trim(),
      amountMinor: _amount!,
      payerId: _payerId!,
      date: apiDate(_date),
      categoryId: _categoryId,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      split: SplitIn(
        method: c.method,
        inputs: [for (final i in c.inputs) SplitInputIn(userId: i.userId, value: i.value?.toString())],
      ),
    );
    try {
      final api = ref.read(apiProvider);
      final saved = _editing
          ? await api.expenses.updateExpense(widget.editExpenseId!, body)
          : await api.expenses.createExpense(group.id, body);
      refreshLedger(ref.invalidate);
      if (!mounted) return;
      if (_editing) {
        context.pop();
      } else {
        context.pushReplacement('/expenses/${saved!.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.name, required this.onTap});
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Group: $name',
      child: Material(
        color: SkColors.brandSoft,
        shape: const StadiumBorder(side: BorderSide(color: SkColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: SkText.body(13, 700, color: SkColors.brandInk),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const SkIcon('down', size: 14, color: SkColors.brandInk),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
