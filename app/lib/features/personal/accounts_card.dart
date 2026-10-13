import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/integrations.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// Overview's accounts: the latest balance each bank reported in its SMS, newest first. A tap
/// shows that account's entries. Nothing when no bank has reported a balance (cards report a
/// limit), or when the feature is off.
class AccountsCard extends ConsumerWidget {
  const AccountsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featuresProvider).accountBalances) return const SizedBox.shrink();
    final accounts = [
      for (final a in ref.watch(personalAccountsProvider).value ?? const <AccountOut>[])
        if (a.balanceMinor != null) a,
    ];
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('Accounts', style: SkText.section)),
          const SizedBox(height: 8),
          SkCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, a) in accounts.indexed)
                  Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => context.go('/personal/transactions?account=${Uri.encodeQueryComponent(a.account)}'),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          border: i == accounts.length - 1
                              ? null
                              : const Border(bottom: BorderSide(color: SkPalette.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.account, style: SkText.body(15, 600)),
                                  Text(
                                    'Balance on ${dayLabel(a.balanceAt!.toLocal())}',
                                    style: SkText.body(12, 400, color: SkColors.ink2),
                                  ),
                                ],
                              ),
                            ),
                            Text(money(a.balanceMinor!, a.currency), style: SkText.display(16, 700)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
