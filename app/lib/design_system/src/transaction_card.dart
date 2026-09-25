import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'sk_icon.dart';
import 'surfaces.dart';

enum TxnScope { group, personal }

/// One card, seven tones (designs/TxnCard.dc.html). Purely presentational: the screen writes
/// the copy ("Rahul paid ₹1,800 · split 4 ways", "you owe", "₹450").
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.when,
    required this.label,
    required this.amount,
    required this.glyph,
    required this.tone,
    this.scope = TxnScope.group,
    this.adminBadge = false,
    this.onTap,
  });

  final String title;
  final String subtitle;

  /// Group name, category or "Personal", shown as a pill.
  final String tag;
  final String when;
  final String label;
  final String amount;
  final String glyph;
  final MoneyTone tone;
  final TxnScope scope;

  /// Shows the "Admin" badge for entries written in admin mode.
  final bool adminBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final personal = scope == TxnScope.personal;
    return SkCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semanticLabel: '$title. $subtitle. $label $amount${adminBadge ? '. Edited by an admin' : ''}',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80 - 28 - 2),
          child: Row(
            children: [
              IconTile(glyph, background: tone.tileBg, foreground: tone.tileFg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: SkText.body(16, 600, height: 1.25),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: SkText.body(13, 400, color: SkColors.ink2, height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: _Pill(
                            tag,
                            background: personal ? SkColors.personalSoft : SkColors.brandSoft,
                            foreground: personal ? SkColors.personalInk : SkColors.brandInk,
                          ),
                        ),
                        if (adminBadge) ...[
                          const SizedBox(width: 6),
                          const _Pill('Admin', background: SkColors.adminBand, foreground: SkColors.adminInk),
                        ],
                        const SizedBox(width: 6),
                        Text(when, style: SkText.body(12, 400, color: SkColors.ink3)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: SkText.body(12, 600, color: tone.fg)),
                  const SizedBox(height: 2),
                  Text(amount, style: SkText.display(19, 700, color: tone.fg, tracking: -0.01)),
                  if (tone == MoneyTone.settled) ...[const SizedBox(height: 2), const _SettledBadge()],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.background, required this.foreground});
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(SkRadius.chip)),
      child: Text(
        text,
        style: SkText.body(12, 600, color: foreground),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SettledBadge extends StatelessWidget {
  const _SettledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(SkRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkIcon('check', size: 12, color: SkColors.ink2),
          const SizedBox(width: 4),
          Text('Settled', style: SkText.body(11, 600, color: SkColors.ink2)),
        ],
      ),
    );
  }
}
