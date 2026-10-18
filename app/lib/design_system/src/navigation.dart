import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'sk_icon.dart';

class NavDestination {
  const NavDestination({required this.key, required this.label, required this.glyph});
  final String key;
  final String label;
  final String glyph;

  /// Split's tabs: Home, Groups, Profile, plus Admin for admins.
  static List<NavDestination> split({bool admin = false}) => [
    const NavDestination(key: 'home', label: 'Home', glyph: 'home'),
    const NavDestination(key: 'groups', label: 'Groups', glyph: 'groups'),
    ..._shared(admin),
  ];

  /// Personal's tabs: Overview, Transactions, Goals (unless [goals] is off), Insights, Profile,
  /// plus Admin for admins.
  static List<NavDestination> personal({bool admin = false, bool goals = true}) => [
    const NavDestination(key: 'overview', label: 'Overview', glyph: 'wallet'),
    const NavDestination(key: 'transactions', label: 'Transactions', glyph: 'swap'),
    if (goals) const NavDestination(key: 'goals', label: 'Goals', glyph: 'target'),
    const NavDestination(key: 'insights', label: 'Insights', glyph: 'chart'),
    ..._shared(admin),
  ];

  static List<NavDestination> _shared(bool admin) => [
    const NavDestination(key: 'profile', label: 'Profile', glyph: 'user'),
    if (admin) const NavDestination(key: 'admin', label: 'Admin', glyph: 'shield'),
  ];
}

/// A mode's colour in the navigation: brand for Split, personal for Personal.
enum NavAccent {
  brand,
  personal;

  /// The add button.
  Color get fill => this == brand ? SkColors.brand : SkColors.personal;

  /// The selected tab's icon and label.
  Color get ink => this == brand ? SkColors.brandInk : SkColors.personalInk;

  /// The pill behind the selected tab.
  Color get soft => this == brand ? SkColors.brandSoft : SkColors.personalSoft;

  Color fg(bool on) => on ? ink : SkColors.ink2;
}

/// Mobile tab bar (under 600px): 84px, pill behind the active icon.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.destinations,
    required this.current,
    required this.onSelected,
    this.accent = NavAccent.brand,
  });

  final List<NavDestination> destinations;
  final String current;
  final ValueChanged<String> onSelected;
  final NavAccent accent;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = bottomInset > 20 ? bottomInset : 20.0;
    return Semantics(
      container: true,
      label: 'Primary',
      child: Container(
        height: 64 + bottom,
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottom),
        decoration: BoxDecoration(
          color: SkColors.surface,
          border: Border(top: BorderSide(color: SkColors.line)),
        ),
        child: Row(
          children: [
            for (final d in destinations)
              Expanded(
                child: _Tab(d, on: d.key == current, accent: accent, onTap: () => onSelected(d.key)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.d, {required this.on, required this.accent, required this.onTap});
  final NavDestination d;
  final bool on;
  final NavAccent accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: d.label,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, box) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  // 56 wide, narrower when six tabs share a small phone (an admin's Personal tabs).
                  width: math.max(0, math.min(56, box.maxWidth - 4)),
                  height: 30,
                  decoration: BoxDecoration(
                    color: on ? accent.soft : Colors.transparent,
                    borderRadius: BorderRadius.circular(SkRadius.chip),
                  ),
                  alignment: Alignment.center,
                  child: SkIcon(d.glyph, size: 22, color: accent.fg(on)),
                ),
                const SizedBox(height: 4),
                // One line, shrunk rather than wrapped when five tabs share a narrow phone.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    d.label,
                    maxLines: 1,
                    softWrap: false,
                    style: SkText.body(11, on ? 700 : 500, color: accent.fg(on)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size, required this.radius, required this.iconSize});
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: SkColors.ink, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: SkIcon('settle', size: iconSize, color: SkColors.onFill),
    );
  }
}

/// Tablet rail (600–1279px): logo, the mode switch, a square add button, destinations with
/// pills.
class NavRail extends StatelessWidget {
  const NavRail({
    super.key,
    required this.destinations,
    required this.current,
    required this.onSelected,
    required this.onAdd,
    this.addLabel = 'Add split',
    this.accent = NavAccent.brand,
    this.modeSwitch,
  });

  final List<NavDestination> destinations;
  final String current;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final String addLabel;
  final NavAccent accent;

  /// Shown between the logo and the add button.
  final Widget? modeSwitch;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Primary',
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: SkColors.surface,
          border: Border(right: BorderSide(color: SkColors.line)),
        ),
        child: Column(
          children: [
            const _BrandMark(size: 40, radius: 12, iconSize: 20),
            const SizedBox(height: 20),
            if (modeSwitch case final modeSwitch?) ...[modeSwitch, const SizedBox(height: 16)],
            Semantics(
              button: true,
              label: addLabel,
              child: Material(
                color: accent.fill,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAdd,
                  child: SizedBox.square(
                    dimension: 56,
                    child: Center(child: SkIcon('plus', size: 26, color: SkColors.onFill)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (final d in destinations) ...[
              SizedBox(
                width: 72,
                child: Semantics(
                  button: true,
                  selected: d.key == current,
                  label: d.label,
                  child: InkWell(
                    onTap: () => onSelected(d.key),
                    borderRadius: BorderRadius.circular(12),
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 32,
                              decoration: BoxDecoration(
                                color: d.key == current ? accent.soft : Colors.transparent,
                                borderRadius: BorderRadius.circular(SkRadius.chip),
                              ),
                              alignment: Alignment.center,
                              child: SkIcon(d.glyph, size: 22, color: accent.fg(d.key == current)),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                d.label,
                                maxLines: 1,
                                softWrap: false,
                                style: SkText.body(12, d.key == current ? 700 : 500, color: accent.fg(d.key == current)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Desktop sidebar (1280px and up).
class WebSidebar extends StatelessWidget {
  const WebSidebar({
    super.key,
    required this.destinations,
    required this.current,
    required this.onSelected,
    required this.onAdd,
    required this.user,
    required this.role,
    this.addLabel = 'Add split',
    this.accent = NavAccent.brand,
    this.modeSwitch,
  });

  final List<NavDestination> destinations;
  final String current;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final SkPerson user;
  final String addLabel;
  final NavAccent accent;

  /// Shown between the logo and the add button.
  final Widget? modeSwitch;

  /// "Administrator" or "Personal account".
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: SkColors.surface,
        border: Border(right: BorderSide(color: SkColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const _BrandMark(size: 32, radius: 10, iconSize: 18),
                const SizedBox(width: 10),
                Text('Splitkit', style: SkText.display(22, 700)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (modeSwitch case final modeSwitch?) ...[modeSwitch, const SizedBox(height: 16)],
          Material(
            color: accent.fill,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdd,
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkIcon('plus', size: 20, color: SkColors.onFill),
                    const SizedBox(width: 8),
                    Text(addLabel, style: SkText.body(15, 700, color: SkColors.onFill)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            container: true,
            label: 'Primary',
            child: Column(
              children: [
                for (final d in destinations) ...[
                  _SidebarItem(d, on: d.key == current, accent: accent, onTap: () => onSelected(d.key)),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SkColors.paper, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Avatar(user, size: 36, fontSize: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: SkText.body(14, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(role, style: SkText.body(12, 400, color: SkColors.ink2)),
                    ],
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(this.d, {required this.on, required this.accent, required this.onTap});
  final NavDestination d;
  final bool on;
  final NavAccent accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: d.label,
      child: Material(
        color: on ? accent.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SkIcon(d.glyph, size: 20, color: accent.fg(on)),
                  const SizedBox(width: 12),
                  Text(d.label, style: SkText.body(15, on ? 700 : 500, color: accent.fg(on))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
