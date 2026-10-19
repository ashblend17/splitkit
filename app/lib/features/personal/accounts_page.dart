import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
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
import '../sms/sms_setup_page.dart';
import '../sms/sms_source.dart';
import 'account_sheet.dart';
import 'holdings_section.dart';

/// How the Accounts page groups accounts.
enum _Group {
  cashAndBank('Cash & bank'),
  cardsAndLoans('Cards & loans'),
  investmentsAndOther('Investments & other');

  const _Group(this.label);
  final String label;

  static _Group of(AccountType t) => switch (t) {
    AccountType.cash || AccountType.bank => cashAndBank,
    AccountType.creditCard || AccountType.loan => cardsAndLoans,
    AccountType.investment || AccountType.otherAsset => investmentsAndOther,
  };
}

/// Personal → Accounts (/personal/accounts, from Overview): your net worth, then each account at
/// what it's worth (its balance worked out from its entries, or for an investment account with
/// holdings, by them, listed under it: [HoldingsSection]), grouped, with closed accounts folded
/// away at the end.
/// Where the bank's last reported balance isn't what the entries add up to, it says so and
/// offers Reconcile; where nothing ever checked a balance read from SMS, it says that too
/// (ISS-126, ISS-127). Accounts that look like one are offered for linking, and bank accounts a
/// credit card's messages went into for making credit cards. An account linked to another is
/// listed under it. A tap opens the account ([showAccountSheet]).
class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final worth = ref.watch(netWorthProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back to overview',
                            onPressed: () => context.go('/personal'),
                          ),
                        ),
                        Expanded(
                          child: Semantics(header: true, child: Text('Accounts', style: SkText.display(20, 700))),
                        ),
                        SkButton(
                          'Add',
                          icon: 'plus',
                          variant: SkButtonVariant.strong,
                          size: SkButtonSize.small,
                          onPressed: () => showAccountSheet(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AsyncBody(value: worth, onRetry: () => ref.invalidate(netWorthProvider), builder: _body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(NetWorth worth) {
    final all = [...worth.accounts, ...worth.otherCurrency];
    if (all.isEmpty) {
      final features = ref.watch(featuresProvider);
      final reading =
          features.smsImport &&
          ref.watch(smsSourceProvider).available &&
          ref.watch(smsSetupProvider).value?.settings != null;
      return EmptyState(
        glyph: 'wallet',
        title: 'No accounts yet',
        body: [
          'Add your bank, card or cash to see balances and net worth.',
          if (reading) 'Accounts appear as bank SMS are read.',
        ].join(' '),
        actionLabel: 'Add account',
        onAction: () => showAccountSheet(context),
      );
    }
    final open = <_Group, List<AccountBalance>>{}, closed = <AccountBalance>[];
    for (final b in all) {
      if (b.account.closed) {
        closed.add(b);
      } else {
        (open[_Group.of(b.account.type)] ??= []).add(b);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _worthCard(worth),
        ..._suggestions(),
        for (final group in _Group.values)
          if (open[group] case final shown?) ...[
            const SizedBox(height: 20),
            Overline(group.label),
            const SizedBox(height: 8),
            _list(shown, worth),
          ],
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Semantics(
            button: true,
            expanded: _showClosed,
            child: InkWell(
              onTap: () => setState(() => _showClosed = !_showClosed),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(child: Overline('Closed (${closed.length})')),
                    SkIcon(_showClosed ? 'up' : 'down', size: 18, color: SkColors.ink2),
                  ],
                ),
              ),
            ),
          ),
          if (_showClosed) ...[const SizedBox(height: 4), _list(closed, worth)],
        ],
      ],
    );
  }

  /// Net worth, and what it's made of.
  Widget _worthCard(NetWorth w) {
    final currency = ref.watch(meProvider).currency;
    final owing = w.accounts.any((b) => b.account.type.isLiability);
    final others = {for (final b in w.otherCurrency) b.account.currency}.toList()..sort();
    Widget line(String label, String value, Color color) => Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: SkText.body(13, 600, color: SkColors.ink2)),
              ),
              Text(value, style: SkText.body(13, 700, color: color)),
            ],
          ),
        ),
      ),
    );
    return SkCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Net worth', style: SkText.body(14, 600, color: SkColors.ink2)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(w.totalMinor, currency), maxLines: 1, style: SkText.display(40, 800, height: 1)),
          ),
          const SizedBox(height: 6),
          line('Assets', money(w.assetsMinor, currency), SkColors.ink),
          if (owing) line('Owed on cards and loans', money(w.liabilitiesMinor, currency), SkColors.ink),
          if (w.splitCounted)
            line(
              'With friends (Split)',
              formatMinor(w.splitMinor, currency: currency, signed: true),
              textColorFor(w.splitMinor),
            ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "Accounts in ${others.join(', ')} aren't in net worth: it counts $currency only.",
              style: SkText.body(12, 400, color: SkColors.ink2),
            ),
          ],
        ],
      ),
    );
  }

  /// Accounts that look like one ("Link"), and bank accounts that look like credit cards.
  List<Widget> _suggestions() {
    final same = ref.watch(sameAccountsProvider).value ?? const <SameAccount>[];
    final cards = ref.watch(looksLikeCardsProvider).value ?? const <LooksLikeCard>[];
    return [
      for (final pair in same)
        _suggestion(
          key: ValueKey('account:same:${pair.key}'),
          title: 'Same account?',
          body:
              '${pair.part.name} looks like part of ${pair.whole.name}: ${pair.why}. Linked, its entries count in '
              "${pair.whole.name}'s balance.",
          yes: 'Link',
          onYes: () => linkAccounts(context, pair.part, pair.whole),
          no: 'Not the same',
          onNo: () => ref.read(notSameAccountProvider.notifier).dismiss(pair),
        ),
      for (final card in cards)
        _suggestion(
          key: ValueKey('account:card:${card.account.id}'),
          title: 'A credit card?',
          body:
              '${card.account.name} looks like a credit card: its bills say “${card.label}”. As one, its spends '
              'are what you owe.',
          yes: 'Make it a credit card',
          onYes: () => _makeCard(card.account),
          no: "It's a bank account",
          onNo: () => ref.read(notCardProvider.notifier).dismiss(card),
        ),
    ];
  }

  Widget _suggestion({
    required Key key,
    required String title,
    required String body,
    required String yes,
    required VoidCallback onYes,
    required String no,
    required VoidCallback onNo,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 12),
    child: SkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: SkText.body(15, 700)),
          const SizedBox(height: 4),
          Text(body, style: SkText.body(13, 400, color: SkColors.ink2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SkButton(yes, size: SkButtonSize.small, variant: SkButtonVariant.strong, onPressed: onYes),
              SkButton(no, size: SkButtonSize.small, variant: SkButtonVariant.secondary, onPressed: onNo),
            ],
          ),
        ],
      ),
    ),
  );

  /// [a] becomes a credit card, with Undo. An opening worked out from what its bank reported
  /// (a balance, read as an asset's) goes back to zero: you set what you owe after.
  Future<void> _makeCard(FinAccount a) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final writes = ref.read(writesProvider);
    try {
      await writes.updateAccount(a.id, type: AccountType.creditCard, openingMinor: a.openingMinor == 0 ? null : 0);
      refreshPersonal(container.invalidate);
      if (!mounted) return;
      showMessage(
        context,
        '${a.name} is a credit card now',
        actionLabel: 'Undo',
        onAction: () async {
          await writes.updateAccount(a.id, type: a.type, openingMinor: a.openingMinor == 0 ? null : a.openingMinor);
          refreshPersonal(container.invalidate);
        },
      );
    } catch (e) {
      if (mounted) showMessage(context, apiErrorMessage(e));
    }
  }

  Widget _list(List<AccountBalance> accounts, NetWorth worth) => SkCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, b) in accounts.indexed)
          _row(
            b,
            worth.valueOf(b),
            byHoldings: worth.values[b.account.id]?.byHoldings ?? false,
            last: i == accounts.length - 1,
          ),
      ],
    ),
  );

  /// Account [b] at what it's worth ([value]: an investment account by its holdings, listed
  /// under it), with what its bank last said when that isn't its balance. One valued by its
  /// holdings isn't reconciled: a correction would count at cost on top of their values.
  Widget _row(AccountBalance b, int value, {required bool byHoldings, required bool last}) {
    final a = b.account;
    final checks = ref.watch(featuresProvider).accountBalances && !a.closed && !byHoldings;
    final check = checks ? b.lastReported : null;
    final gap = check != null && check.gapMinor != 0 ? check : null;
    // Added up from SMS and never checked: a card's SMS report a limit, and some banks' none.
    final fromSms = a.smsLabel != null || b.linked.any((l) => l.smsLabel != null);
    final since = checks && gap == null && fromSms && b.unchecked ? b.firstActivityDay : null;
    return Container(
      key: ValueKey('account:${a.id}'),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: SkPalette.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => showAccountSheet(context, existing: a),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  IconTile(
                    accountGlyph(a.type),
                    background: SkColors.personalSoft,
                    foreground: SkColors.personalInk,
                    size: 36,
                    radius: 10,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: SkText.body(15, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          [
                            accountTypeLabel(a.type),
                            if (a.smsLabel case final label? when label != a.name) label,
                            if (b.linked.isNotEmpty) 'with ${b.linked.map((l) => l.name).join(', ')}',
                          ].join(' · '),
                          style: SkText.body(12, 400, color: SkColors.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    accountBalanceLabel(b, minor: value),
                    style: SkText.display(16, 700, color: accountBalanceColor(b, minor: value)),
                  ),
                ],
              ),
            ),
          ),
          if (a.type == AccountType.investment) HoldingsSection(a.id),
          if (gap != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(color: SkColors.pendingSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bank said ${money(gap.reportedMinor, a.currency)} on ${dayKeyLabel(gap.day)} · '
                        '${money(gap.gapMinor.abs(), a.currency)} off',
                        style: SkText.body(13, 600, color: SkPalette.pendingInk),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SkButton(
                      'Reconcile',
                      size: SkButtonSize.small,
                      variant: SkButtonVariant.secondary,
                      onPressed: () => reconcileAccount(context, b, gap.reportedMinor, at: gap),
                    ),
                  ],
                ),
              ),
            ),
          if (since != null)
            Padding(
              key: ValueKey('account:unchecked:${a.id}'),
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(color: SkColors.pendingSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.type.isLiability
                            ? 'Added up from SMS since ${dayKeyLabel(since)}, never checked'
                            : "Added up from SMS since ${dayKeyLabel(since)}; the bank hasn't said its balance",
                        style: SkText.body(13, 600, color: SkPalette.pendingInk),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SkButton(
                      a.type.isLiability ? 'Set owed' : 'Set balance',
                      size: SkButtonSize.small,
                      variant: SkButtonVariant.secondary,
                      onPressed: () => showAccountSheet(context, existing: a),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
