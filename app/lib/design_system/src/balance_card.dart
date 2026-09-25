import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/theme/theme.dart';
import 'surfaces.dart';

enum BalanceCardLayout {
  /// Home (mobile): 44px hero, two tiles side by side, optional footer (friend chips).
  hero,

  /// Components gallery / narrow columns: 38px, compact tiles.
  compact,

  /// Tablet / desktop side column: 40px, tiles stacked as rows.
  stacked,
}

/// Overall balance. The headline words follow the sign so colour never stands alone:
/// "Overall, you are owed" (green), "Overall, you owe" (red), "You're all settled up" (grey).
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.netMinor,
    required this.youOweMinor,
    required this.youAreOwedMinor,
    this.currency = 'INR',
    this.layout = BalanceCardLayout.hero,
    this.footer,
  });

  final int netMinor;
  final int youOweMinor;
  final int youAreOwedMinor;
  final String currency;
  final BalanceCardLayout layout;
  final Widget? footer;

  static String headline(int net) => net > 0
      ? 'Overall, you are owed'
      : net < 0
      ? 'Overall, you owe'
      : "You're all settled up";

  @override
  Widget build(BuildContext context) {
    final tone = MoneyTone.forNet(netMinor);
    final (padding, radius, heroSize, labelSize) = switch (layout) {
      BalanceCardLayout.hero => (20.0, 20.0, 44.0, 14.0),
      BalanceCardLayout.compact => (18.0, 18.0, 38.0, 13.0),
      BalanceCardLayout.stacked => (18.0, 18.0, 40.0, 13.0),
    };
    final amount = formatMinor(netMinor.abs(), currency: currency);
    final headlineText = headline(netMinor);
    return SkCard(
      padding: EdgeInsets.all(padding),
      radius: radius,
      semanticLabel: '$headlineText $amount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headlineText, style: SkText.body(labelSize, 600, color: SkColors.ink2)),
                SizedBox(height: layout == BalanceCardLayout.hero ? 4 : 12),
                Text(
                  amount,
                  style: SkText.display(
                    heroSize,
                    800,
                    color: tone == MoneyTone.settled ? SkColors.ink2 : tone.fg,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: layout == BalanceCardLayout.hero ? 16 : 12),
          _tiles(),
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }

  Widget _tiles() {
    final owe = formatMinor(youOweMinor, currency: currency);
    final owed = formatMinor(youAreOwedMinor, currency: currency);
    switch (layout) {
      case BalanceCardLayout.hero:
      case BalanceCardLayout.compact:
        final hero = layout == BalanceCardLayout.hero;
        Widget tile(String label, String value, Color bg, Color labelColor, Color valueColor) => Expanded(
          child: Container(
            padding: EdgeInsets.all(hero ? 12 : 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(hero ? 12 : 10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SkText.body(hero ? 12 : 11, 600, color: labelColor)),
                SizedBox(height: hero ? 2 : 0),
                Text(value, style: SkText.display(hero ? 20 : 16, 700, color: valueColor)),
              ],
            ),
          ),
        );
        return Row(
          children: [
            tile('You owe', owe, SkColors.oweSoft, SkColors.oweInk, SkColors.owe),
            SizedBox(width: hero ? 8 : 6),
            tile(hero ? 'You are owed' : 'Owed', owed, SkColors.owedSoft, SkColors.owedInk, SkColors.owed),
          ],
        );
      case BalanceCardLayout.stacked:
        Widget row(String label, String value, Color bg, Color labelColor, Color valueColor) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: SkText.body(13, 600, color: labelColor)),
              ),
              Text(value, style: SkText.display(16, 600, color: valueColor)),
            ],
          ),
        );
        return Column(
          children: [
            row('You owe', owe, SkColors.oweSoft, SkColors.oweInk, SkColors.owe),
            const SizedBox(height: 6),
            row('You are owed', owed, SkColors.owedSoft, SkColors.owedInk, SkColors.owed),
          ],
        );
    }
  }
}
