import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/local/writes.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../../core/sms/sms.dart';
import '../sms/sms_importer.dart';
import 'account_sheet.dart';
import 'holdings_section.dart';
import 'txn_actions.dart';

/// Add a personal entry, or open one ([existing]) to edit or delete it. [type] is what a new one
/// starts as, the API's type ('expense', 'income', 'transfer', 'refund'…); [refundOf] starts a
/// refund of that spend. Half of a transfer opens the whole transfer; a balance correction opens
/// read-only.
Future<void> showPersonalTxnSheet(
  BuildContext context, {
  String type = 'expense',
  PersonalTxnOut? existing,
  PersonalTxnOut? refundOf,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _PersonalTxnSheet(
    type: existing?.type.value ?? (refundOf == null ? type : 'refund'),
    existing: existing,
    refundOf: refundOf,
  ),
);

/// What each type is called in the sheet's title and Save button.
const _nouns = {
  'expense': 'expense',
  'income': 'income',
  'transfer': 'transfer',
  'refund': 'refund',
  'investment_contribution': 'investment',
  'investment_withdrawal': 'withdrawal',
};

/// The types behind "More", with their chip labels.
const _moreTypes = {'investment_contribution': 'Invested', 'investment_withdrawal': 'Withdrew'};

/// More accounts than this and the account is picked from a list, not chips.
const _maxAccountChips = 6;

class _PersonalTxnSheet extends ConsumerStatefulWidget {
  const _PersonalTxnSheet({required this.type, this.existing, this.refundOf});
  final String type;
  final PersonalTxnOut? existing;
  final PersonalTxnOut? refundOf;

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
  late final _description = TextEditingController(
    text: widget.existing?.description ?? widget.refundOf?.description ?? '',
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late int? _amount = widget.existing?.amountMinor;
  late String? _categoryId = widget.existing?.category?.id ?? widget.refundOf?.category?.id;

  /// Once you pick (or when editing, or refunding a spend), the category stops following what
  /// you type.
  late bool _categoryChosen = _editing || widget.refundOf != null;
  late String? _channel = widget.existing?.channel?.value;
  late DateTime _date = widget.existing?.date ?? appClock.now();

  /// The account of anything but a transfer (null: no account).
  late String? _accountId = widget.existing?.accountId ?? widget.refundOf?.accountId;

  /// A transfer's accounts as picked; until then, as [_sides] has them.
  String? _pickedFrom, _pickedTo;

  /// The spend a refund gives money back for, if any.
  late String? _refundOfId = widget.existing?.refundOfId ?? widget.refundOf?.id;

  /// The holding an investment or a withdrawal is into or out of, if any.
  late String? _holdingId = widget.existing?.holdingId;
  bool _busy = false;

  /// What names accounts and pairs transfer halves, as of the last build.
  FinanceEngine? _finance;

  bool get _editing => widget.existing != null;

  /// The entry opened is half of a transfer.
  bool get _wasTransfer =>
      widget.existing?.type == PersonalTxnOutTypeEnum.transfer && widget.existing?.transferGroupId != null;

  /// A balance correction: Reconcile made it, so it can only be deleted here.
  bool get _readOnly => widget.existing?.type == PersonalTxnOutTypeEnum.adjustment;

  bool get _transfer => _type == 'transfer';
  bool get _investment => _moreTypes.containsKey(_type);
  bool get _comesIn => const {'income', 'refund', 'investment_withdrawal'}.contains(_type);
  bool get _suggests => const {'expense', 'income', 'refund'}.contains(_type);
  String? get _notesText => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  /// Linked to a split or a payment: it can only be a spend or an income.
  bool get _linked => widget.existing?.expenseId != null || widget.existing?.settlementId != null;

  void _suggestCategory() {
    if (_categoryChosen || !_suggests) return;
    _categoryId = suggestCategory(ref, _description.text, scope: 'personal', income: _type == 'income');
  }

  /// A tap on the suggested chip keeps it (it's what you meant); otherwise chips toggle.
  void _pickCategory(String id) => setState(() {
    final confirming = !_categoryChosen && id == _categoryId;
    _categoryChosen = true;
    if (!confirming) _categoryId = id == _categoryId ? null : id;
  });

  void _setType(String type) => setState(() {
    _type = type;
    _suggestCategory();
  });

  /// The live halves of the transfer opened, out first, or null.
  (FinEntry, FinEntry)? _legs() {
    final group = widget.existing?.transferGroupId;
    if (group == null || _finance == null) return null;
    final legs = [
      for (final e in _finance!.transferLegs(group))
        if (!e.deleted && e.txnType == TxnType.transfer) e,
    ];
    if (legs.length != 2) return null;
    return legs[0].flow == MoneyFlow.outflow ? (legs[0], legs[1]) : (legs[1], legs[0]);
  }

  /// A transfer's accounts before any pick: the transfer's own, or the entry's account on its
  /// side (the side money left by, for a spend).
  (String?, String?) _sides() {
    final t = widget.existing;
    if (t == null) return (null, null);
    if (_legs() case (final out, final into)) return (out.accountId, into.accountId);
    return t.direction == PersonalTxnOutDirectionEnum.out_ ? (t.accountId, null) : (null, t.accountId);
  }

  String? get _from => _pickedFrom ?? _sides().$1;
  String? get _to => _pickedTo ?? _sides().$2;

  @override
  void initState() {
    super.initState();
    // A refund of a spend goes where the spend came from, while that account is open.
    if (widget.refundOf?.accountId case final from?) {
      final accounts = ref.read(accountsProvider).value ?? const <FinAccount>[];
      if (!accounts.any((a) => a.id == from && !a.closed)) _accountId = null;
    }
    _description.addListener(() => setState(_suggestCategory));
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
    final features = ref.watch(featuresProvider);
    _finance = ref.watch(financeEngineProvider).value;
    final accounts = features.accounts
        ? ref.watch(accountsProvider).value ?? const <FinAccount>[]
        : const <FinAccount>[];
    final active = accounts.where((a) => !a.closed).length;
    final noun = _nouns[_type] ?? 'entry';
    final canSave =
        !_busy &&
        (_amount ?? 0) > 0 &&
        _description.text.trim().isNotEmpty &&
        (!_transfer || (_from != null && _to != null && _from != _to));
    final unchangedType = widget.existing?.type.value == _type;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.94),
        decoration: BoxDecoration(
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
                            _readOnly ? 'Balance correction' : '${_editing ? 'Edit' : 'Add'} $noun',
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
                            SkIcon('lock', size: 14, color: SkColors.personalInk),
                            const SizedBox(width: 6),
                            Text('Only you', style: SkText.body(12, 700, color: SkColors.personalInk)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.existing case final t? when t.source_ == PersonalTxnOutSource_Enum.sms) ...[
                    const SizedBox(height: 6),
                    Text(smsOrigin(t), style: SkText.body(13, 400, color: SkColors.ink2)),
                    _SmsMessage(entryId: t.id),
                  ],
                  if (_readOnly)
                    ..._correction(widget.existing!)
                  else ...[
                    const SizedBox(height: 14),
                    _typeChips(features, active),
                    if (features.transfers && features.accounts && active < 2 && !_transfer) _addAccountHint(),
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
                      label: switch (_type) {
                        'income' => 'Where from?',
                        'transfer' => 'What was it?',
                        'refund' => 'What came back?',
                        'investment_contribution' => 'What did you invest in?',
                        'investment_withdrawal' => 'What did you take out?',
                        _ => 'What was it for?',
                      },
                      controller: _description,
                      hint: switch (_type) {
                        'income' => 'Salary, refund…',
                        'transfer' => 'Card bill, savings…',
                        'refund' => 'Amazon return…',
                        'investment_contribution' => 'Index fund SIP…',
                        'investment_withdrawal' => 'Fund redemption…',
                        _ => 'Groceries, taxi…',
                      },
                    ),
                    if (_type == 'refund' && features.refunds) ...[const SizedBox(height: 16), _refundOf(me.currency)],
                    if (_investment && features.holdings)
                      if (_holdingPicker(widget.existing?.currency ?? me.currency) case final picker?) ...[
                        const SizedBox(height: 16),
                        picker,
                      ],
                    if (!_transfer) ...[
                      const SizedBox(height: 16),
                      Text('Category', style: SkText.body(14, 600)),
                      const SizedBox(height: 8),
                      _categoryChips(),
                    ],
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (_transfer) ...[
                        _accountPicker(
                          key: const ValueKey('account-picker:from'),
                          label: 'From',
                          accounts: accounts,
                          selected: _from,
                          other: _to,
                          onPick: (id) => setState(() => _pickedFrom = id),
                        ),
                        const SizedBox(height: 16),
                        _accountPicker(
                          key: const ValueKey('account-picker:to'),
                          label: 'To',
                          accounts: accounts,
                          selected: _to,
                          other: _from,
                          onPick: (id) => setState(() => _pickedTo = id),
                        ),
                      ] else
                        _accountPicker(
                          key: const ValueKey('account-picker:account'),
                          label: _comesIn ? 'Received in' : 'Paid from',
                          accounts: accounts,
                          selected: _accountId,
                          allowNone: true,
                          onPick: (id) => setState(() => _accountId = id),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(_comesIn ? 'Received by' : 'Paid with', style: SkText.body(14, 600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final MapEntry(key: key, value: label) in channelLabels.entries)
                          // ATM is what bank SMS say for cash withdrawals; not offered otherwise.
                          if (key != 'atm' || _channel == 'atm')
                            SelectableChip(
                              label: label,
                              selected: key == _channel,
                              accent: ChipAccent.personal,
                              onTap: () => setState(() => _channel = key == _channel ? null : key),
                            ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _dateButton()),
                        const SizedBox(width: 8),
                        Expanded(child: _notesField()),
                      ],
                    ),
                    // What it can become, for the entry as it is (not once another type is picked).
                    if (widget.existing case final t? when unchangedType) ...[
                      const SizedBox(height: 18),
                      EntryActions(txn: t, leave: () => Navigator.of(context).pop()),
                      TxnInSplit(txn: t),
                    ],
                    const SizedBox(height: 18),
                    SkButton(
                      _busy ? 'Saving…' : (_editing ? 'Save changes' : 'Save $noun'),
                      size: SkButtonSize.large,
                      expand: true,
                      onPressed: canSave ? _save : null,
                    ),
                  ],
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

  /// Expense · Income · Transfer · Refund · More (Invested, Withdrew), as the features allow. A
  /// transfer needs two open accounts; an entry linked to Split stays a spend or an income.
  Widget _typeChips(Features features, int activeAccounts) {
    final more = _moreTypes[_type];
    final canTransfer = _transfer || (activeAccounts >= 2 && !_linked);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (type, label) in [('expense', 'Expense'), ('income', 'Income')])
          SelectableChip(
            label: label,
            selected: _type == type,
            accent: ChipAccent.personal,
            onTap: () => _setType(type),
          ),
        if (features.transfers && features.accounts || _transfer)
          SelectableChip(
            label: 'Transfer',
            selected: _transfer,
            accent: ChipAccent.personal,
            onTap: canTransfer ? () => _setType('transfer') : null,
          ),
        if (features.refunds || _type == 'refund')
          SelectableChip(
            label: 'Refund',
            selected: _type == 'refund',
            accent: ChipAccent.personal,
            onTap: _linked ? null : () => _setType('refund'),
          ),
        if (features.investmentTypes || more != null)
          SelectableChip(
            label: more ?? 'More',
            icon: more == null ? 'down' : null,
            selected: more != null,
            accent: ChipAccent.personal,
            onTap: _linked ? null : _pickMore,
          ),
      ],
    );
  }

  Future<void> _pickMore() async {
    final picked = await showAppBottomSheet<String>(
      context,
      title: 'What kind of entry?',
      child: Column(
        children: [
          for (final (type, label, about) in [
            ('investment_contribution', 'Invested', 'Money put into an investment: a SIP, shares, a deposit'),
            ('investment_withdrawal', 'Withdrew', 'Money taken back out of an investment'),
          ])
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(type),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: SkText.body(15, 600)),
                            Text(about, style: SkText.body(13, 400, color: SkColors.ink2)),
                          ],
                        ),
                      ),
                      if (_type == type) SkIcon('check', size: 20, color: SkColors.personal),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null && mounted) _setType(picked);
  }

  /// "Transfers need two accounts · Add account": the new account is the one picked.
  Widget _addAccountHint() => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Flexible(
          child: Text('Transfers need two accounts.', style: SkText.body(13, 400, color: SkColors.ink2)),
        ),
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () async {
            final id = await showAccountSheet(context);
            if (id != null && mounted) setState(() => _accountId = id);
          },
          child: Text('Add account', style: SkText.body(13, 700, color: SkColors.personalInk)),
        ),
      ],
    ),
  );

  Widget _categoryChips() {
    final categories = ref.watch(personalCategoriesProvider);
    final income = _type == 'income' || _type == 'investment_withdrawal';
    return AsyncBody(
      value: categories,
      onRetry: () => ref.invalidate(personalCategoriesProvider),
      skeletonRows: 1,
      builder: (cats) {
        final shown = cats.where((c) => income ? c.key == 'income' || c.ownerId != null : c.key != 'income').toList();
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
                onTap: () => _pickCategory(c.id),
              ),
          ],
        );
      },
    );
  }

  /// "Paid from", "Received in", or a transfer's From and To: your open accounts as chips (and a
  /// closed one the entry is already in), or a list to pick from when there are more than
  /// [_maxAccountChips]. [allowNone] offers "No account"; [other] (the transfer's other side)
  /// can't be picked.
  Widget _accountPicker({
    required Key key,
    required String label,
    required List<FinAccount> accounts,
    required String? selected,
    required ValueChanged<String?> onPick,
    bool allowNone = false,
    String? other,
  }) {
    final shown = [
      for (final a in accounts)
        if (!a.closed || a.id == selected) a,
    ];
    final picked = shown.where((a) => a.id == selected).firstOrNull;
    return KeyedSubtree(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: SkText.body(14, 600)),
          const SizedBox(height: 8),
          if (shown.where((a) => !a.closed).length > _maxAccountChips)
            _pickerButton(
              glyph: picked == null ? 'wallet' : accountGlyph(picked.type),
              text: picked?.name ?? (allowNone ? 'No account' : 'Pick an account'),
              onTap: () async {
                final id = await showAppBottomSheet<(String?,)>(
                  context,
                  title: label,
                  child: _scrolling([
                    if (allowNone) _accountOption(null, 'No account', 'wallet', selected == null),
                    for (final a in shown)
                      if (a.id != other) _accountOption(a.id, a.name, accountGlyph(a.type), a.id == selected),
                  ]),
                );
                if (id != null) onPick(id.$1);
              },
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (allowNone)
                  SelectableChip(
                    label: 'No account',
                    selected: selected == null,
                    accent: ChipAccent.personal,
                    onTap: () => onPick(null),
                  ),
                for (final a in shown)
                  SelectableChip(
                    label: a.name,
                    icon: accountGlyph(a.type),
                    selected: a.id == selected,
                    accent: ChipAccent.personal,
                    onTap: a.id == other ? null : () => onPick(a.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// A list in a sheet ([showAppBottomSheet]'s child) that scrolls when it's longer than the screen.
  Widget _scrolling(List<Widget> children) => Flexible(
    child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );

  Widget _accountOption(String? id, String name, String glyph, bool selected) => Builder(
    builder: (sheet) => InkWell(
      onTap: () => Navigator.of(sheet).pop((id,)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            SkIcon(glyph, size: 18, color: SkColors.ink2),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: SkText.body(15, 600))),
            if (selected) SkIcon('check', size: 20, color: SkColors.personal),
          ],
        ),
      ),
    ),
  );

  /// A field-like button that opens a list: an account, or the spend a refund is for.
  Widget _pickerButton({required String glyph, required String text, String? detail, required VoidCallback onTap}) =>
      Material(
        color: SkColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: SkColors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SkIcon(glyph, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(text, style: SkText.body(14, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (detail != null) Text(detail, style: SkText.body(12, 400, color: SkColors.ink2)),
                      ],
                    ),
                  ),
                  const SkIcon('down', size: 18),
                ],
              ),
            ),
          ),
        ),
      );

  /// What's left to refund of spend [id] (adding back this refund, when editing one of it).
  int? _leftOf(String id) {
    final spend = _finance?.entry(id);
    if (spend == null) return null;
    final own = widget.existing;
    return _finance!.refundableMinor(spend) + (own != null && own.refundOfId == id ? own.amountMinor : 0);
  }

  /// "Refund of": optionally, the spend this gives money back for, from your spends in the weeks
  /// before (Features.refundMatchDays) with something left to refund. Picking one takes its
  /// account and category.
  Widget _refundOf(String currency) {
    final id = _refundOfId;
    final spend = id == null ? null : ref.watch(personalTxnProvider(id)).value;
    final left = id == null ? null : _leftOf(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Refund of', style: SkText.body(14, 600)),
        const SizedBox(height: 8),
        _pickerButton(
          glyph: spend == null ? 'refresh' : glyphOr(spend.category?.icon),
          text: id == null ? 'A spend (optional)' : spend?.description ?? 'A spend',
          detail: spend == null
              ? null
              : [
                  dayLabel(spend.date),
                  money(spend.amountMinor, spend.currency),
                  if (left != null) '${money(left, spend.currency)} left to refund',
                ].join(' · '),
          onTap: _pickRefundOf,
        ),
      ],
    );
  }

  Future<void> _pickRefundOf() async {
    final days = ref.read(featuresProvider).refundMatchDays;
    final query = PersonalQuery(
      type: 'expense',
      start: _date.subtract(Duration(days: days)),
      end: _date,
      limit: 50,
    );
    final List<PersonalTxnOut> spends;
    try {
      spends = (await ref.read(personalListProvider(query).future)).items;
    } catch (e) {
      if (mounted) showMessage(context, apiErrorMessage(e));
      return;
    }
    if (!mounted) return;
    final candidates = [
      for (final s in spends)
        if (s.id == _refundOfId || (_leftOf(s.id) ?? 0) > 0) s,
    ];
    final picked = await showAppBottomSheet<(PersonalTxnOut?,)>(
      context,
      title: 'Refund of',
      child: _scrolling([
        Builder(builder: (sheet) => _spendOption(sheet, null, 'No particular spend', null, _refundOfId == null)),
        if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No spends in the last $days days with anything left to refund.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            ),
          ),
        for (final s in candidates)
          Builder(
            builder: (sheet) {
              final left = _leftOf(s.id);
              return _spendOption(
                sheet,
                s,
                s.description,
                [
                  dayLabel(s.date),
                  ?categoryLabel(s),
                  if (left != null && left < s.amountMinor) '${money(left, s.currency)} left',
                ].join(' · '),
                s.id == _refundOfId,
                amount: money(s.amountMinor, s.currency),
              );
            },
          ),
      ]),
    );
    if (picked == null || !mounted) return;
    final spend = picked.$1;
    final accounts = ref.read(accountsProvider).value ?? const <FinAccount>[];
    setState(() {
      _refundOfId = spend?.id;
      if (spend == null) return;
      // Money back goes where the spend came from, while that account is open.
      final from = accounts.where((a) => a.id == spend.accountId && !a.closed).firstOrNull;
      _accountId = from?.id;
      _categoryId = spend.category?.id;
      _categoryChosen = true;
    });
  }

  Widget _spendOption(
    BuildContext sheet,
    PersonalTxnOut? spend,
    String title,
    String? detail,
    bool selected, {
    String? amount,
  }) => InkWell(
    onTap: () => Navigator.of(sheet).pop((spend,)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: SkText.body(15, 600)),
                if (detail != null) Text(detail, style: SkText.body(13, 400, color: SkColors.ink2)),
              ],
            ),
          ),
          if (amount != null) Text(amount, style: SkText.body(15, 700)),
          if (selected) ...[const SizedBox(width: 8), SkIcon('check', size: 20, color: SkColors.personal)],
        ],
      ),
    ),
  );

  /// The holdings an investment or a withdrawal can name: any of your live ones in [currency]
  /// (the entry is on the account the money moved from or to, the holding in an investment
  /// account; service.py _check_holding), those in the account picked first, and the one it
  /// names already, even deleted (an edit keeps it).
  List<FinHolding> _holdingChoices(String currency) {
    final f = _finance;
    if (f == null) return const [];
    final live = [
      for (final h in f.holdings)
        if (h.currency == currency) h,
    ];
    final current = _holdingId == null ? null : f.holding(_holdingId!);
    return [
      if (current != null && !live.contains(current)) current,
      ...live.where((h) => h.accountId == _accountId),
      ...live.where((h) => h.accountId != _accountId),
    ];
  }

  /// "Holding": optionally, the holding the money went into or came out of. Nothing when you have
  /// none.
  Widget? _holdingPicker(String currency) {
    final choices = _holdingChoices(currency);
    if (choices.isEmpty) return null;
    final picked = choices.where((h) => h.id == _holdingId).firstOrNull;
    String detail(FinHolding h) => [
      _finance?.account(h.accountId)?.name ?? 'An account',
      if (h.deleted) 'Deleted' else holdingTypeLabel(h.type),
    ].join(' · ');
    Widget option(String? id, String title, String? about) => Builder(
      builder: (sheet) => InkWell(
        onTap: () => Navigator.of(sheet).pop((id,)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: SkText.body(15, 600)),
                    if (about != null) Text(about, style: SkText.body(13, 400, color: SkColors.ink2)),
                  ],
                ),
              ),
              if (id == _holdingId) SkIcon('check', size: 20, color: SkColors.personal),
            ],
          ),
        ),
      ),
    );
    return Column(
      key: const ValueKey('holding-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Holding', style: SkText.body(14, 600)),
        const SizedBox(height: 8),
        _pickerButton(
          glyph: 'chart',
          text: picked?.name ?? 'A holding (optional)',
          detail: picked == null ? null : detail(picked),
          onTap: () async {
            final id = await showAppBottomSheet<(String?,)>(
              context,
              title: 'Holding',
              child: _scrolling([
                option(null, 'No particular holding', null),
                for (final h in choices) option(h.id, h.name, detail(h)),
              ]),
            );
            if (id != null && mounted) setState(() => _holdingId = id.$1);
          },
        ),
      ],
    );
  }

  /// A balance correction, read-only: what it did, and Delete (below).
  List<Widget> _correction(PersonalTxnOut t) {
    final v = personalView(t, finance: _finance);
    return [
      const SizedBox(height: 6),
      Text(
        "A balance correction from Reconcile: it brought the account to what the bank said. "
        "Delete it to undo that.",
        style: SkText.body(14, 400, color: SkColors.ink2, height: 1.4),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.subtitle, style: SkText.body(15, 600)),
                  Text(formDateLabel(t.date), style: SkText.body(13, 400, color: SkColors.ink2)),
                ],
              ),
            ),
            Text(v.amount, style: SkText.display(20, 700)),
          ],
        ),
      ),
      const SizedBox(height: 10),
    ];
  }

  Widget _dateButton() => Material(
    color: SkColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: SkColors.line, width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: appClock.now().add(const Duration(days: 365)),
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
        hintText: 'Note',
        hintStyle: SkText.body(14, 400, color: SkColors.ink3),
      ),
    ),
  );

  /// [base] with what the sheet shows, for anything but a transfer. Saving it counts as having
  /// looked at it.
  PersonalTxnIn _body(PersonalTxnIn base) {
    final features = ref.read(featuresProvider);
    return base
      ..type = PersonalTxnInTypeEnum.fromJson(_type)!
      ..amountMinor = _amount!
      ..description = _description.text.trim()
      ..date = apiDate(_date)
      ..categoryId = _categoryId
      ..notes = _notesText
      ..channel = PersonalTxnInChannelEnum.fromJson(_channel)
      ..accountId = features.accounts ? _accountId : base.accountId
      ..refundOfId = _type == 'refund' ? _refundOfId : null
      ..holdingId = _investment ? _holdingId : null
      ..transferGroupId = null
      ..reviewed = true;
  }

  /// Whether the amount, words, date, note or how it was paid changed from [t].
  bool _detailsChanged(PersonalTxnOut t) =>
      _amount != t.amountMinor ||
      _description.text.trim() != t.description ||
      !DateUtils.isSameDay(_date, t.date) ||
      _notesText != t.notes ||
      _channel != t.channel?.value;

  Future<void> _save() async {
    final existing = widget.existing;
    // Editing a refund: the device checks it against what's left of the spend (a new one is
    // checked by recordRefund).
    if (existing != null && _type == 'refund' && _refundOfId != null) {
      final left = _leftOf(_refundOfId!);
      if (left != null && _amount! > left) {
        showMessage(context, 'Only ${money(left, existing.currency)} of this spend is left to refund');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final writes = ref.read(writesProvider);
      if (existing == null) {
        await _create(writes);
      } else if (_wasTransfer) {
        await _saveTransfer(writes, existing);
      } else if (_transfer) {
        await _convert(writes, existing);
      } else {
        // An edit starts from the entry as it is, so what this sheet doesn't show (where it came
        // from, a link to a split) goes back unchanged.
        await writes.updatePersonal(existing.id, _body(personalBody(existing)));
      }
      refreshPersonal(ref.invalidate);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }

  Future<void> _create(LocalWrites writes) async {
    final description = _description.text.trim();
    switch (_type) {
      case 'transfer':
        await writes.createTransfer(
          fromAccountId: _from!,
          toAccountId: _to!,
          amountMinor: _amount!,
          date: _date,
          description: description,
          notes: _notesText,
          channel: _channel,
        );
      case 'refund':
        await writes.recordRefund(
          amountMinor: _amount!,
          date: _date,
          description: description,
          refundOfId: _refundOfId,
          accountId: _accountId,
          categoryId: _categoryId,
          notes: _notesText,
          channel: _channel,
        );
      default:
        await writes.createPersonal(
          _body(
            PersonalTxnIn(
              type: PersonalTxnInTypeEnum.expense,
              amountMinor: 0,
              description: '',
              date: apiDate(_date),
              source_: PersonalTxnInSource_Enum.manual,
            ),
          ),
        );
    }
  }

  /// Half of a transfer: both halves change together; as another type, the transfer is undone
  /// first (unpairTransfer keeps this half) and this half then saved as that.
  Future<void> _saveTransfer(LocalWrites writes, PersonalTxnOut leg) async {
    final group = leg.transferGroupId!;
    if (_transfer) {
      final (from, to) = _sides();
      if (!_detailsChanged(leg) && _from == from && _to == to) return;
      await writes.updateTransfer(
        group,
        fromAccountId: _from == from ? null : _from,
        toAccountId: _to == to ? null : _to,
        amountMinor: _amount == leg.amountMinor ? null : _amount,
        // Left out, each half keeps its own date (two bank SMS may be a day apart).
        date: DateUtils.isSameDay(_date, leg.date) ? null : _date,
        description: _description.text.trim() == leg.description ? null : _description.text.trim(),
        notes: _notesText == leg.notes ? null : _notesText ?? '',
        channel: _channel == leg.channel?.value ? null : _channel ?? '',
      );
      return;
    }
    await writes.unpairTransfer(group, keepId: leg.id);
    // unpairTransfer leaves it a spend or an income by its direction, with no category.
    final natural = leg.direction == PersonalTxnOutDirectionEnum.in_ ? 'income' : 'expense';
    if (_type == natural && _categoryId == null && _accountId == leg.accountId && !_detailsChanged(leg)) return;
    await writes.updatePersonal(leg.id, _body(personalBody(leg)));
  }

  /// A spend or an income becomes half of a transfer (convertToTransfer), on its own side: the
  /// side money left by, for a spend. Other changes to it are saved first.
  Future<void> _convert(LocalWrites writes, PersonalTxnOut t) async {
    final out = t.direction == PersonalTxnOutDirectionEnum.out_;
    final (own, other) = out ? (_from, _to) : (_to, _from);
    if (_detailsChanged(t) || own != t.accountId || !t.reviewed) {
      await writes.updatePersonal(
        t.id,
        personalBody(t)
          ..amountMinor = _amount!
          ..description = _description.text.trim()
          ..date = apiDate(_date)
          ..notes = _notesText
          ..channel = PersonalTxnInChannelEnum.fromJson(_channel)
          ..accountId = own
          ..reviewed = true,
      );
    }
    await writes.convertToTransfer(t.id, otherAccountId: other!);
  }

  Future<void> _delete() async {
    final t = widget.existing!;
    final api = ref.read(writesProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // Half of a transfer takes the other half with it; restoring either brings both back.
      _wasTransfer ? await api.deleteTransfer(t.transferGroupId!) : await api.deletePersonal(t.id);
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

/// "Show the message": the SMS an entry was read from, from the phone that read it (the
/// message never leaves it).
class _SmsMessage extends ConsumerStatefulWidget {
  const _SmsMessage({required this.entryId});
  final String entryId;

  @override
  ConsumerState<_SmsMessage> createState() => _SmsMessageState();
}

class _SmsMessageState extends ConsumerState<_SmsMessage> {
  Future<RawSms?>? _message;

  @override
  Widget build(BuildContext context) {
    if (_message == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          // A block, not `=>`: setState refuses a callback that returns the Future.
          onPressed: () => setState(() {
            _message = ref.read(smsImporterProvider).messageFor(widget.entryId);
          }),
          child: Text('Show the message', style: SkText.body(13, 700, color: SkColors.personalInk)),
        ),
      );
    }
    return FutureBuilder<RawSms?>(
      future: _message,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 24);
        final sms = snap.data;
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
          child: Text(
            sms == null ? 'The message stays on the phone that read it.' : '${sms.address}: ${sms.body}',
            style: SkText.body(13, 400, color: sms == null ? SkColors.ink2 : SkColors.ink, height: 1.4),
          ),
        );
      },
    );
  }
}
