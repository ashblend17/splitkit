import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'avatar.dart';

Color _stateColor(MoneyTone tone) => tone == MoneyTone.settled ? SkColors.ink2 : tone.fg;

/// A friend and where you stand ("You owe ₹500", "Aman owes you ₹850", "Settled").
class FriendBalanceRow extends StatelessWidget {
  const FriendBalanceRow({
    super.key,
    required this.person,
    required this.state,
    required this.tone,
    this.onTap,
    this.dense = false,
    this.showDivider = true,
    this.trailing,
  });

  final SkPerson person;
  final String state;
  final MoneyTone tone;
  final VoidCallback? onTap;

  /// 54px rows (tablet friends list) instead of 58px.
  final bool dense;
  final bool showDivider;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '${person.name}, $state',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: dense ? 54 : 58),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: showDivider ? const Border(bottom: BorderSide(color: SkPalette.divider)) : null,
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Avatar(person, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(person.name, style: SkText.body(14, 700)),
                      Text(state, style: SkText.body(13, 600, color: _stateColor(tone))),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact friend pill used in the Home balance card.
class FriendBalanceChip extends StatelessWidget {
  const FriendBalanceChip({super.key, required this.person, required this.state, required this.tone, this.onTap});

  final SkPerson person;
  final String state;
  final MoneyTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '${person.name}, $state',
      child: Material(
        color: SkColors.paper,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(person, size: 32, fontSize: 12),
                    const SizedBox(width: 8),
                    Text(person.name, style: SkText.body(13, 600)),
                    const SizedBox(width: 8),
                    Text(state, style: SkText.body(13, 600, color: _stateColor(tone))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
