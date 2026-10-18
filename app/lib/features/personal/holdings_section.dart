/// An investment account's holdings on the Accounts page (finance revamp design §5.2): what it's
/// worth by them and what that includes, each holding with its value, how old the value is and
/// its gain when its cost is known, and Add holding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/copy/copy.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/holding_providers.dart';
import '../../core/integrations.dart';
import '../../core/money/money.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'account_sheet.dart';
import 'holding_sheet.dart';

/// "Mutual fund", "Shares"…: what a holding is, in words.
String holdingTypeLabel(HoldingType t) => switch (t) {
  HoldingType.mutualFund => 'Mutual fund',
  HoldingType.stock => 'Shares',
  HoldingType.fd => 'Fixed deposit',
  HoldingType.gold => 'Gold',
  HoldingType.other => 'Other',
};

/// A gain in basis points as a percentage of the cost: 1408 is "+14.08%", -250 "−2.5%".
String gainPercent(int bp) {
  final abs = bp.abs();
  final cents = (abs % 100).toString().padLeft(2, '0').replaceFirst(RegExp(r'0+$'), '');
  final sign = bp < 0 ? minus : (bp > 0 ? '+' : '');
  return '$sign${abs ~/ 100}${cents.isEmpty ? '' : '.$cents'}%';
}

/// A holding's gain, only when its cost is known: "+₹8,450 · +14.08%", or null.
String? gainLabel(HoldingView v) {
  final gain = v.gainMinor;
  if (gain == null) return null;
  final money = formatMinor(gain, currency: v.holding.currency, signed: true);
  return v.gainBp == null ? money : '$money · ${gainPercent(v.gainBp!)}';
}

/// How old a holding's value is, and what's been added at cost since: "Value as of 15 Aug ·
/// incl. ₹5,000 added since".
String valueAsOf(HoldingView v) {
  final c = v.holding.currency, added = v.addedSinceMinor;
  return [
    'Value as of ${dayKeyLabel(v.holding.valuationDay)}',
    if (added > 0) 'incl. ${money(added, c)} added since',
    if (added < 0) 'after ${money(-added, c)} taken out since',
  ].join(' · ');
}

/// What an account valued by its holdings is worth, and what that includes: "Holdings ₹85,750 ·
/// incl. ₹5,000 added since 15 Aug" (the earliest of their valuations).
String holdingsLine(AccountValue v) {
  final c = v.account.currency, added = v.addedSinceMinor;
  final since = v.asOfDay == null ? null : dayKeyLabel(v.asOfDay!);
  return [
    'Holdings ${money(v.valueMinor, c)}',
    if (since != null)
      if (added > 0)
        'incl. ${money(added, c)} added since $since'
      else if (added < 0)
        'after ${money(-added, c)} taken out since $since'
      else
        'as of $since',
  ].join(' · ');
}

/// Under investment account [accountId] on the Accounts page: its holdings, each opening its sheet
/// ([showHoldingSheet]), and Add holding while the account is open. Nothing while
/// Features.holdings is off, or for an account that isn't an investment account.
class HoldingsSection extends ConsumerWidget {
  const HoldingsSection(this.accountId, {super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featuresProvider).holdings) return const SizedBox.shrink();
    final values = ref.watch(accountValuesProvider).value ?? const <AccountValue>[];
    final value = values.where((v) => v.account.id == accountId).firstOrNull;
    if (value == null || value.account.type != AccountType.investment) return const SizedBox.shrink();
    final a = value.account;
    final canAdd = !a.closed;
    if (value.holdings.isEmpty && !canAdd) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('holdings:$accountId'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                value.holdings.isEmpty
                    ? 'Add what you hold here (a fund, shares, gold) to value this account.'
                    : holdingsLine(value),
                style: SkText.body(12, value.holdings.isEmpty ? 400 : 600, color: SkColors.ink2),
              ),
            ),
            for (final h in value.holdings) _HoldingRow(h),
            if (canAdd)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SkButton(
                    'Add holding',
                    icon: 'plus',
                    size: SkButtonSize.small,
                    variant: SkButtonVariant.secondary,
                    onPressed: () => showHoldingSheet(context, accountId: accountId),
                  ),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// One holding: name (Stale when its value is old), type and how old its value is; its value,
/// and its gain when known. A tap opens it.
class _HoldingRow extends StatelessWidget {
  const _HoldingRow(this.view);

  final HoldingView view;

  @override
  Widget build(BuildContext context) {
    final h = view.holding;
    final gain = gainLabel(view);
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey('holding:${h.id}'),
        onTap: () => showHoldingSheet(context, accountId: h.accountId, existing: h),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: SkPalette.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            h.name,
                            style: SkText.body(14, 600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (view.stale) ...[
                          const SizedBox(width: 8),
                          const StatusChip('Stale', tone: StatusTone.pending, showDot: false),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${holdingTypeLabel(h.type)} · ${valueAsOf(view)}',
                      style: SkText.body(12, 400, color: SkColors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(view.valueMinor, h.currency), style: SkText.display(15, 700)),
                  if (gain != null) Text(gain, style: SkText.body(12, 600, color: textColorFor(view.gainMinor!))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
