import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/copy/copy.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'account_sheet.dart';

/// Overview's accounts: net worth (with your investments and how many of their values are stale,
/// once you have holdings), your three biggest accounts at what they're worth (a tap shows that
/// account's entries), how many disagree with what the bank last said, and All accounts
/// (/personal/accounts). With no accounts yet, an offer to add one. Nothing while
/// Features.accounts is off.
class AccountsCard extends ConsumerWidget {
  const AccountsCard({super.key});

  /// How many balances the card shows.
  static const shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    if (!features.accounts) return const SizedBox.shrink();
    final worth = ref.watch(netWorthProvider).value;
    if (worth == null) return const SizedBox.shrink();
    final currency = ref.watch(meProvider).currency;
    final open = [
      for (final b in [...worth.accounts, ...worth.otherCurrency])
        if (!b.account.closed) b,
    ];
    final none = worth.accounts.isEmpty && worth.otherCurrency.isEmpty;
    final top = [...open.indexed]..sort((x, y) => _biggestFirst(worth, x, y));
    // "Investments ₹85,750 · as of 15 Aug" and "1 value is stale", once there are holdings.
    final investments = features.holdings ? worth.asOfDay : null;
    // One valued by its holdings isn't checked against its bank (accounts_page.dart).
    final toCheck = features.accountBalances
        ? open
              .where((b) => (b.lastReported?.gapMinor ?? 0) != 0 && !(worth.values[b.account.id]?.byHoldings ?? false))
              .length
        : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text('Accounts', style: SkText.section)),
              ),
              if (!none)
                InkWell(
                  onTap: () => context.go('/personal/accounts'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('All accounts', style: SkText.body(14, 700, color: SkColors.brandInk)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (none)
            SkCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('See balances and net worth', style: SkText.body(15, 700)),
                  const SizedBox(height: 4),
                  Text(
                    'Add your bank, card or cash, and each entry can say where the money went.',
                    style: SkText.body(13, 400, color: SkColors.ink2),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SkButton(
                      'Add account',
                      icon: 'plus',
                      size: SkButtonSize.small,
                      variant: SkButtonVariant.secondary,
                      onPressed: () => showAccountSheet(context),
                    ),
                  ),
                ],
              ),
            )
          else
            SkCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => context.go('/personal/accounts'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Net worth', style: SkText.body(13, 600, color: SkColors.ink2)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    money(worth.totalMinor, currency),
                                    maxLines: 1,
                                    style: SkText.display(24, 800),
                                  ),
                                ),
                                if (investments != null) ...[
                                  Text(
                                    'Investments ${money(worth.investmentsMinor, currency)} · '
                                    'as of ${dayKeyLabel(investments)}',
                                    style: SkText.body(13, 400, color: SkColors.ink2),
                                  ),
                                  if (worth.staleCount > 0)
                                    Text(
                                      worth.staleCount == 1 ? '1 value is stale' : '${worth.staleCount} values are stale',
                                      style: SkText.body(13, 600, color: SkPalette.pendingInk),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          if (toCheck > 0) StatusChip('$toCheck to check', tone: StatusTone.pending),
                        ],
                      ),
                    ),
                  ),
                  for (final (_, b) in top.take(shown)) _row(context, b, worth.valueOf(b)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The biggest value first ([NetWorth.valueOf]), whichever way it counts (what you owe too), then
  /// in the API's order (the index each came at).
  static int _biggestFirst(NetWorth worth, (int, AccountBalance) x, (int, AccountBalance) y) {
    final c = worth.valueOf(y.$2).abs().compareTo(worth.valueOf(x.$2).abs());
    return c != 0 ? c : x.$1.compareTo(y.$1);
  }

  Widget _row(BuildContext context, AccountBalance b, int value) => Semantics(
    button: true,
    child: InkWell(
      onTap: () => context.go('/personal/transactions?account_id=${b.account.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: SkPalette.divider)),
        ),
        child: Row(
          children: [
            IconTile(
              accountGlyph(b.account.type),
              background: SkColors.personalSoft,
              foreground: SkColors.personalInk,
              size: 32,
              radius: 9,
              iconSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.account.name, style: SkText.body(15, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(accountTypeLabel(b.account.type), style: SkText.body(12, 400, color: SkColors.ink2)),
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
  );
}
