import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/copy/copy.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
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
/// offers Reconcile. A tap opens the account ([showAccountSheet]).
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
    final check = ref.watch(featuresProvider).accountBalances && !a.closed && !byHoldings ? b.lastReported : null;
    final gap = check != null && check.gapMinor != 0 ? check : null;
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
        ],
      ),
    );
  }
}
