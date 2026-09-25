import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// Add a personal expense or income, or edit/delete one ([existing]).
Future<void> showPersonalTxnSheet(BuildContext context, {String type = 'expense', PersonalTxnOut? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalTxnSheet(type: existing?.type.value ?? type, existing: existing),
    );

class _PersonalTxnSheet extends ConsumerStatefulWidget {
  const _PersonalTxnSheet({required this.type, this.existing});
  final String type;
  final PersonalTxnOut? existing;

  @override
  ConsumerState<_PersonalTxnSheet> createState() => _PersonalTxnSheetState();
}

class _PersonalTxnSheetState extends ConsumerState<_PersonalTxnSheet> {
  late String _type = widget.type;
  late final _amountText = TextEditingController(
    text: widget.existing == null
        ? ''
        : money(
            widget.existing!.amountMinor,
            widget.existing!.currency,
          ).substring(currencySymbol(widget.existing!.currency).length),
  );
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late int? _amount = widget.existing?.amountMinor;
  late String? _categoryId = widget.existing?.category?.id;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountText.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final categories = ref.watch(personalCategoriesProvider);
    final income = _type == 'income';
    final canSave = !_busy && (_amount ?? 0) > 0 && _description.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.94),
        decoration: const BoxDecoration(
          color: SkColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SkRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: ContentWidth(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: SkColors.lineStrong,
                        borderRadius: BorderRadius.circular(SkRadius.chip),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _editing
                                ? (income ? 'Edit income' : 'Edit expense')
                                : (income ? 'Add income' : 'Add expense'),
                            style: SkText.display(22, 700),
                          ),
                        ),
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
                            Text('Only you', style: SkText.body(12, 700, color: SkColors.personalInk)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      SelectableChip(
                        label: 'Expense',
                        selected: !income,
                        accent: ChipAccent.personal,
                        onTap: () => setState(() => _type = 'expense'),
                      ),
                      SelectableChip(
                        label: 'Income',
                        selected: income,
                        accent: ChipAccent.personal,
                        onTap: () => setState(() => _type = 'income'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AmountInput(
                    controller: _amountText,
                    currency: me.currency,
                    autofocus: !_editing,
                    symbolSize: 30,
                    fontSize: 52,
                    showCurrencyChip: false,
                    onChanged: (m) => setState(() => _amount = m),
                  ),
                  const SizedBox(height: 18),
                  SkTextField(
                    label: income ? 'Where from?' : 'What was it for?',
                    controller: _description,
                    hint: income ? 'Salary, refund…' : 'Groceries, taxi…',
                  ),
                  const SizedBox(height: 16),
                  Text('Category', style: SkText.body(14, 600)),
                  const SizedBox(height: 8),
                  AsyncBody(
                    value: categories,
                    onRetry: () => ref.invalidate(personalCategoriesProvider),
                    skeletonRows: 1,
                    builder: (cats) {
                      final shown = cats
                          .where((c) => income ? c.key == 'income' || c.ownerId != null : c.key != 'income')
                          .toList();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in shown)
                            SelectableChip(
                              label: c.label,
                              icon: glyphOr(c.icon),
                              selected: c.id == _categoryId,
                              accent: ChipAccent.personal,
                              onTap: () => setState(() => _categoryId = c.id == _categoryId ? null : c.id),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _dateButton()),
                      const SizedBox(width: 8),
                      Expanded(child: _notesField()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SkButton(
                    _busy ? 'Saving…' : (_editing ? 'Save changes' : (income ? 'Save income' : 'Save expense')),
                    size: SkButtonSize.large,
                    expand: true,
                    onPressed: canSave ? _save : null,
                  ),
                  if (_editing) ...[
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton() => Material(
    color: SkColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: SkColors.line, width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SkIcon('calendar', size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(formDateLabel(_date), style: SkText.body(14, 600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _notesField() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: SkColors.line, width: 1.5),
    ),
    alignment: Alignment.centerLeft,
    child: TextField(
      controller: _notes,
      style: SkText.body(14, 400),
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: 'Note (UPI, card…)',
        hintStyle: SkText.body(14, 400, color: SkColors.ink3),
      ),
    ),
  );

  Future<void> _save() async {
    setState(() => _busy = true);
    final body = PersonalTxnIn(
      type: PersonalTxnInTypeEnum.fromJson(_type)!,
      amountMinor: _amount!,
      description: _description.text.trim(),
      date: apiDate(_date),
      categoryId: _categoryId,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      final api = ref.read(apiProvider).personal;
      _editing ? await api.updatePersonal(widget.existing!.id, body) : await api.createPersonal(body);
      refreshPersonal(ref.invalidate);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }

  Future<void> _delete() async {
    final t = widget.existing!;
    final api = ref.read(apiProvider).personal;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await api.deletePersonal(t.id);
      refreshPersonal(ref.invalidate);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('“${t.description}” deleted'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: SkColors.brandSoft,
            onPressed: () async {
              await api.restorePersonal(t.id);
              refreshPersonal(container.invalidate);
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }
}
