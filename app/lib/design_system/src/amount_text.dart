import 'package:flutter/widgets.dart';

import '../../core/money/money.dart';
import '../../core/theme/theme.dart';

enum AmountSize {
  hero(44, 800),
  title(28, 700),
  section(20, 700),
  card(19, 700),
  inline(16, 700);

  const AmountSize(this.fontSize, this.weight);
  final double fontSize;
  final int weight;
}

/// An amount in minor units, formatted ("₹1,550") in the display face with tabular figures.
/// Colour comes from [tone]; the caller always puts words next to it.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amountMinor, {
    super.key,
    this.currency = 'INR',
    this.size = AmountSize.card,
    this.tone,
    this.color,
    this.signed = false,
    this.absolute = true,
  });

  final int amountMinor;
  final String currency;
  final AmountSize size;
  final MoneyTone? tone;
  final Color? color;

  /// Prefix positive amounts with "+" (income).
  final bool signed;

  /// Show the magnitude only: direction is carried by the words beside it.
  final bool absolute;

  @override
  Widget build(BuildContext context) {
    final value = absolute ? amountMinor.abs() : amountMinor;
    return Text(
      formatMinor(value, currency: currency, signed: signed),
      style: SkText.display(
        size.fontSize,
        size.weight,
        color: color ?? tone?.fg ?? SkColors.ink,
        height: size == AmountSize.hero ? 1 : null,
      ),
      maxLines: 1,
    );
  }
}
