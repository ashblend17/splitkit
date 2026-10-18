import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/finance/holding_providers.dart';
import '../../core/integrations.dart';
import '../../core/local/writes.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'holdings_section.dart';

/// Add one of your accounts, or open one ([existing]): edit it, set it to what the bank says,
/// see its entries, close or reopen it, or delete it while nothing is in it. Resolves to the new
/// account's id when one was added, else null. Self-contained, so any screen can offer "Add
/// account" (the entry sheet does).
Future<String?> showAccountSheet(BuildContext context, {FinAccount? existing}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _AccountSheet(existing: existing),
);

/// "Bank account", "Credit card"…: what an account is, in words.
String accountTypeLabel(AccountType t) => switch (t) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank account',
  AccountType.creditCard => 'Credit card',
  AccountType.loan => 'Loan',
  AccountType.investment => 'Investment',
  AccountType.otherAsset => 'Other asset',
};

/// The glyph an account of type [t] shows.
String accountGlyph(AccountType t) => switch (t) {
  AccountType.cash => 'wallet',
  AccountType.bank => 'shield',
  AccountType.creditCard || AccountType.loan => 'bills',
  AccountType.investment => 'chart',
  AccountType.otherAsset => 'grid',
};

/// An account's balance in words: "₹96,135" (less than zero when overdrawn), or for a card or
/// loan, what you owe: "₹340 owed", or "₹200 in credit" when it's been overpaid. [minor], when
/// given, is what it's worth instead (NetWorth.valueOf: an investment account by its holdings).
String accountBalanceLabel(AccountBalance b, {int? minor}) {
  final a = b.account, m = minor ?? b.balanceMinor;
  if (!a.type.isLiability) return money(m, a.currency);
  return m < 0 ? '${money(-m, a.currency)} in credit' : '${money(m, a.currency)} owed';
}

/// The colour [accountBalanceLabel] is shown in: what you owe, or an overdrawn account, in the
/// owe colour; the rest in ink.
Color accountBalanceColor(AccountBalance b, {int? minor}) {
  final m = minor ?? b.balanceMinor;
  final owing = b.account.type.isLiability ? m > 0 : m < 0;
  return owing ? SkColors.owe : SkColors.ink;
}

/// "23 Sep" for a day key (20260923).
String dayKeyLabel(int day) => DateFormat('d MMM').format(DateTime(day ~/ 10000, day ~/ 100 % 100, day % 100));

/// Makes [b]'s account agree with what the bank says ([bankSaysMinor]: what it holds, or for a
/// card or loan, what you owe) with a balance correction: at the bank's last reported balance
/// ([at], dated that day) or, without, as of today. Says what was recorded, with Undo, or why
/// it was refused. Resolves to whether a correction was queued.
Future<bool> reconcileAccount(BuildContext context, AccountBalance b, int bankSaysMinor, {Checkpoint? at}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final writes = container.read(writesProvider);
  final a = b.account;
  final delta = reconcileDelta(b, bankSaysMinor, atCheckpoint: at != null);
  try {
    final id = await writes.reconcile(a.id, bankSaysMinor: bankSaysMinor, checkpointDay: at?.day);
    refreshPersonal(container.invalidate);
    if (id == null || delta == null) {
      _say(messenger, '${a.name} already matches');
      return false;
    }
    _say(
      messenger,
      'Recorded a ${money(delta.amountMinor, a.currency)} correction to ${a.name}',
      undo: () async {
        await writes.deletePersonal(id);
        refreshPersonal(container.invalidate);
      },
    );
    return true;
  } catch (e) {
    _say(messenger, apiErrorMessage(e));
    return false;
  }
}

/// [showMessage] through a messenger held from before a sheet closed.
void _say(ScaffoldMessengerState messenger, String text, {VoidCallback? undo}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: Text(text),
      action: undo == null ? null : SnackBarAction(label: 'Undo', textColor: SkColors.brandSoft, onPressed: undo),
    ),
  );

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.existing});
  final FinAccount? existing;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late AccountType _type = widget.existing?.type ?? AccountType.bank;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _opening = TextEditingController(text: _initialOpening);
  late final _label = TextEditingController(text: widget.existing?.smsLabel ?? '');
  final _bankSays = TextEditingController();
  bool _busy = false;

  bool get _editing => widget.existing != null;

  /// The opening balance as the field first shows it (empty for none).
  late final String _initialOpening = switch (widget.existing) {
    final a? when a.openingMinor != 0 => _amountText(a.openingMinor.abs(), a.currency),
    _ => '',
  };

  static String _amountText(int minor, String currency) =>
      money(minor, currency).substring(currencySymbol(currency).length);

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _opening, _bankSays]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _opening, _label, _bankSays]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.existing?.currency ?? ref.watch(meProvider).currency;
    final features = ref.watch(featuresProvider);
    final balance = switch (widget.existing) {
      final a? => ref.watch(accountBalancesProvider).value?.where((b) => b.account.id == a.id).firstOrNull,
      null => null,
    };
    // As it is now (closed or not), once its balance is known.
    final account = balance?.account ?? widget.existing;
    // An investment account with holdings is worth what they are (holdings_section.dart).
    final value = switch (widget.existing) {
      final a? => ref.watch(accountValuesProvider).value?.where((v) => v.account.id == a.id).firstOrNull,
      null => null,
    };
    final byHoldings = value?.byHoldings ?? false;
    final opening = _opening.text.trim().isEmpty ? 0 : parseMinor(_opening.text, currency: currency);
    final canSave = !_busy && _name.text.trim().isNotEmpty && opening != null;
    final liability = _type.isLiability;
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
                            account?.name ?? 'Add account',
                            style: SkText.display(22, 700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _OnlyYou(),
                    ],
                  ),
                  if (account != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        accountTypeLabel(account.type),
                        if (account.closed) 'Closed',
                        if (balance != null) balance.entryCount == 1 ? '1 entry' : '${balance.entryCount} entries',
                      ].join(' · '),
                      style: SkText.body(13, 400, color: SkColors.ink2),
                    ),
                  ],
                  if (balance != null) ...[
                    const SizedBox(height: 14),
                    Text(byHoldings ? 'Value' : 'Balance', style: SkText.body(13, 600, color: SkColors.ink2)),
                    const SizedBox(height: 2),
                    Text(
                      accountBalanceLabel(balance, minor: value?.valueMinor),
                      style: SkText.display(
                        30,
                        800,
                        color: accountBalanceColor(balance, minor: value?.valueMinor),
                        height: 1.1,
                      ),
                    ),
                    if (byHoldings) ...[
                      const SizedBox(height: 4),
                      Text(holdingsLine(value!), style: SkText.body(13, 400, color: SkColors.ink2)),
                    ],
                  ],
                  const SizedBox(height: 18),
                  Text('Type', style: SkText.body(14, 600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in AccountType.values)
                        SelectableChip(
                          label: accountTypeLabel(t),
                          icon: accountGlyph(t),
                          selected: t == _type,
                          accent: ChipAccent.personal,
                          onTap: () => setState(() => _type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SkTextField(label: 'Name', controller: _name, hint: 'HDFC savings, Wallet…'),
                  const SizedBox(height: 14),
                  SkTextField(
                    label: liability ? 'Owed when you started' : 'Opening balance',
                    controller: _opening,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AmountFormatter(currency: currency)],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    liability
                        ? 'What you owed on it before your first entry here.'
                        : 'What it held before your first entry here.',
                    style: SkText.body(12, 400, color: SkColors.ink2),
                  ),
                  const SizedBox(height: 14),
                  SkTextField(label: 'Bank SMS label (optional)', controller: _label, hint: 'HDFC ··4821'),
                  const SizedBox(height: 6),
                  Text(
                    'Entries read from bank SMS with this label go to this account.',
                    style: SkText.body(12, 400, color: SkColors.ink2),
                  ),
                  const SizedBox(height: 18),
                  SkButton(
                    _busy ? 'Saving…' : (_editing ? 'Save changes' : 'Add account'),
                    size: SkButtonSize.large,
                    expand: true,
                    onPressed: canSave ? () => _save(opening) : null,
                  ),
                  if (account != null) ..._manage(account, balance, features, byHoldings: byHoldings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What can be done with an account that exists. One valued by its holdings isn't matched to
  /// what a bank says: a correction would count at cost on top of its holdings' values.
  List<Widget> _manage(FinAccount a, AccountBalance? b, Features features, {required bool byHoldings}) {
    final says = parseMinor(_bankSays.text, currency: a.currency);
    final cantDelete = _cantDelete(a);
    return [
      if (b != null && !a.closed && features.accountBalances && !byHoldings) ...[
        const SizedBox(height: 24),
        Text('The bank says…', style: SkText.body(14, 600)),
        const SizedBox(height: 4),
        Text(
          a.type.isLiability
              ? 'Type what the statement says you owe. A correction dated today makes this match.'
              : 'Type the balance your bank shows now. A correction dated today makes this match.',
          style: SkText.body(12, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SkTextField(
                label: a.type.isLiability ? 'Owed' : 'Balance',
                controller: _bankSays,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AmountFormatter(currency: a.currency)],
              ),
            ),
            const SizedBox(width: 8),
            SkButton(
              'Match',
              variant: SkButtonVariant.secondary,
              onPressed: _busy || says == null ? null : () => _match(b, says),
            ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: SkButton(
              'See entries',
              variant: SkButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : () => _seeEntries(a),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SkButton(
              a.closed ? 'Reopen' : 'Close account',
              variant: SkButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : () => a.closed ? _reopen(a) : _close(a, b),
            ),
          ),
        ],
      ),
      // Only while nothing is in it: an account with entries is closed instead. One a goal follows
      // or with holdings can't be deleted (ISS-107), so it says why instead.
      if (b != null && b.entryCount == 0)
        if (cantDelete != null) ...[
          const SizedBox(height: 10),
          Text(
            cantDelete,
            key: const ValueKey('account:cant-delete'),
            style: SkText.body(13, 400, color: SkColors.ink2),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const SizedBox(height: 8),
          SkButton(
            'Delete',
            icon: 'trash',
            variant: SkButtonVariant.danger,
            expand: true,
            onPressed: _busy ? null : () => _delete(a),
          ),
        ],
    ];
  }

  /// Why [a] can't be deleted, as the server would refuse it (accounts.py change_deleted), or
  /// null: a goal that isn't deleted follows it (archived ones too), or it has live holdings.
  String? _cantDelete(FinAccount a) {
    final finance = ref.watch(financeEngineProvider).value;
    if (finance == null) return null;
    final goal = finance.liveGoals.where((g) => g.linkedAccountId == a.id).firstOrNull;
    if (goal != null) return "${goal.name} follows this account's balance, so it can't be deleted.";
    if (finance.holdings.any((h) => h.accountId == a.id)) {
      return "It has holdings, so it can't be deleted. Delete them first.";
    }
    return null;
  }

  Future<void> _save(int? opening) async {
    final name = _name.text.trim(), label = _label.text.trim();
    final writes = ref.read(writesProvider);
    final before = widget.existing;
    setState(() => _busy = true);
    try {
      String? made;
      if (before == null) {
        made = await writes.createAccount(
          name: name,
          type: _type,
          openingMinor: opening ?? 0,
          smsLabel: label.isEmpty ? null : label,
        );
      } else {
        // Only what changed: an opening the field can't show (less than zero) stays as it is.
        await writes.updateAccount(
          before.id,
          name: name == before.name ? null : name,
          type: _type == before.type ? null : _type,
          openingMinor: _opening.text == _initialOpening ? null : opening,
          smsLabel: label == (before.smsLabel ?? '') ? null : label,
        );
      }
      refreshPersonal(ref.invalidate);
      if (mounted) Navigator.of(context).pop(made);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }

  Future<void> _match(AccountBalance b, int says) async {
    setState(() => _busy = true);
    final done = await reconcileAccount(context, b, says);
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  void _seeEntries(FinAccount a) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/personal/transactions?account_id=${a.id}');
  }

  /// Closing an account with a balance zeroes it first, with a correction, so it stops counting.
  Future<void> _close(FinAccount a, AccountBalance? b) async {
    final left = b?.balanceMinor ?? 0;
    final ok = await showConfirmDialog(
      context,
      title: left == 0 ? 'Close ${a.name}?' : 'Record a ${money(left.abs(), a.currency)} correction and close?',
      body: left == 0
          ? 'It takes no new entries. Its entries stay, and you can reopen it.'
          : '${a.name} shows ${accountBalanceLabel(b!)}. A correction dated today brings it to zero, then it '
                'takes no new entries. Its entries stay, and you can reopen it.',
      confirmLabel: left == 0 ? 'Close account' : 'Correct and close',
      destructive: false,
    );
    if (!ok || !mounted) return;
    await _run((w) => w.closeAccount(a.id, zeroFirst: left != 0), 'Closed ${a.name}');
  }

  Future<void> _reopen(FinAccount a) => _run((w) => w.reopenAccount(a.id), 'Reopened ${a.name}');

  /// Deleted, with Undo. Its SMS label stays its own, so the bank's messages don't make a new one.
  Future<void> _delete(FinAccount a) {
    final container = ProviderScope.containerOf(context, listen: false);
    final writes = ref.read(writesProvider);
    return _run(
      (w) => w.deleteAccount(a.id),
      'Deleted ${a.name}',
      undo: () async {
        await writes.restoreAccount(a.id);
        refreshPersonal(container.invalidate);
      },
    );
  }

  /// Runs [write]; done, closes the sheet and says [done] (with [undo]); refused, says why.
  Future<void> _run(Future<void> Function(LocalWrites w) write, String done, {VoidCallback? undo}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await write(ref.read(writesProvider));
      refreshPersonal(ref.invalidate);
      if (!mounted) return;
      Navigator.of(context).pop();
      _say(messenger, done, undo: undo);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }
}

/// "Only you": accounts are private to you.
class _OnlyYou extends StatelessWidget {
  const _OnlyYou();

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: SkColors.personalSoft, borderRadius: BorderRadius.circular(SkRadius.chip)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkIcon('lock', size: 14, color: SkColors.personalInk),
        const SizedBox(width: 6),
        Text('Only you', style: SkText.body(12, 700, color: SkColors.personalInk)),
      ],
    ),
  );
}
