import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'surfaces.dart';

/// A group with your position in it (GroupList). [label] is the words ("you are owed"),
/// [amount] the formatted figure; both take [tone]'s colour.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.name,
    required this.glyph,
    required this.meta,
    required this.label,
    required this.amount,
    required this.tone,
    required this.lastActive,
    this.members = const [],
    this.onTap,
  });

  final String name;
  final String glyph;

  /// "6 members · ₹48,260 spent"
  final String meta;
  final String label;
  final String amount;
  final MoneyTone tone;
  final String lastActive;
  final List<SkPerson> members;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone == MoneyTone.settled ? SkColors.ink2 : tone.fg;
    return SkCard(
      onTap: onTap,
      semanticLabel: '$name. $meta. $label $amount. $lastActive',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(glyph, background: SkColors.brandSoft, foreground: SkColors.brandInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: SkText.body(16, 700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(meta, style: SkText.body(13, 400, color: SkColors.ink2)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(label, style: SkText.body(12, 600, color: color)),
                    const SizedBox(height: 2),
                    Text(amount, style: SkText.display(18, 700, color: color)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (members.isNotEmpty) AvatarStack(members),
                const Spacer(),
                Text(lastActive, style: SkText.body(12, 400, color: SkColors.ink3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.person, required this.subtitle, this.trailing, this.onTap});

  final SkPerson person;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SkCard(
      onTap: onTap,
      semanticLabel: '${person.name}, $subtitle',
      child: Row(
        children: [
          Avatar(person, size: 48, fontSize: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: SkText.body(15, 700)),
                Text(subtitle, style: SkText.body(12, 400, color: SkColors.ink2)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
