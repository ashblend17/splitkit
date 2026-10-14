import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

enum StatusTone {
  youOwe,
  owedToYou,
  settled,
  pending,
  group,
  personal,
  income,
  expense,

  /// Expense detail share states.
  paid,
  settledShare;

  Color get background => switch (this) {
    youOwe => SkColors.oweSoft,
    owedToYou || income || settledShare => SkColors.owedSoft,
    settled => SkColors.settledSoft,
    pending => SkColors.pendingSoft,
    group => SkColors.brandSoft,
    personal => SkColors.personalSoft,
    expense || paid => SkColors.sunken,
  };

  Color get foreground => switch (this) {
    youOwe => SkColors.owe,
    owedToYou || income => SkColors.owed,
    settled => SkColors.settled,
    pending => SkColors.pending,
    group => SkColors.brandInk,
    personal => SkColors.personalInk,
    expense => SkColors.ink,
    paid => SkColors.ink2,
    settledShare => SkColors.owedInk,
  };
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
