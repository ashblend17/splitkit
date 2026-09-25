import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

enum StatusTone {
  youOwe(SkColors.oweSoft, SkColors.owe),
  owedToYou(SkColors.owedSoft, SkColors.owed),
  settled(SkColors.settledSoft, SkColors.settled),
  pending(SkColors.pendingSoft, SkColors.pending),
  group(SkColors.brandSoft, SkColors.brandInk),
  personal(SkColors.personalSoft, SkColors.personalInk),
  income(SkColors.owedSoft, SkColors.owed),
  expense(SkColors.sunken, SkColors.ink),

  /// Expense detail share states.
  paid(SkColors.sunken, SkColors.ink2),
  settledShare(SkColors.owedSoft, SkColors.owedInk);

  const StatusTone(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

/// Dot plus words; the dot repeats the colour, the words carry the meaning.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.tone, this.showDot = true});

  final String label;
  final StatusTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(SkRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tone.foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: SkText.body(12, 700, color: tone.foreground)),
        ],
      ),
    );
  }
}
