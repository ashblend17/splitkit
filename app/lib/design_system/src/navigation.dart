import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'sk_icon.dart';

class NavDestination {
  const NavDestination({required this.key, required this.label, required this.glyph});
  final String key;
  final String label;
  final String glyph;

  /// Home, Groups, Personal, Profile, plus Admin for admins.
  static List<NavDestination> primary({bool admin = false}) => [
    const NavDestination(key: 'home', label: 'Home', glyph: 'home'),
    const NavDestination(key: 'groups', label: 'Groups', glyph: 'groups'),
    const NavDestination(key: 'personal', label: 'Personal', glyph: 'wallet'),
    const NavDestination(key: 'profile', label: 'Profile', glyph: 'user'),
    if (admin) const NavDestination(key: 'admin', label: 'Admin', glyph: 'shield'),
  ];
}

Color _fg(bool on) => on ? SkColors.brandInk : SkColors.ink2;

/// Mobile tab bar (under 600px): 84px, pill behind the active icon.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.destinations, required this.current, required this.onSelected});

  final List<NavDestination> destinations;
  final String current;
  final ValueChanged<String> onSelected;

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
        decoration: const BoxDecoration(
          color: SkColors.surface,
          border: Border(top: BorderSide(color: SkColors.line)),
        ),
        child: Row(
          children: [
            for (final d in destinations)
              Expanded(
                child: _Tab(d, on: d.key == current, onTap: () => onSelected(d.key)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.d, {required this.on, required this.onTap});
  final NavDestination d;
  final bool on;
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: on ? SkColors.brandSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(SkRadius.chip),
                ),
                alignment: Alignment.center,
                child: SkIcon(d.glyph, size: 22, color: _fg(on)),
              ),
              const SizedBox(height: 4),
              Text(d.label, style: SkText.body(11, on ? 700 : 500, color: _fg(on))),
            ],
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
      child: SkIcon('settle', size: iconSize, color: Colors.white),
    );
  }
}

/// Tablet rail (600–1279px): logo, square "Add split", destinations with pills.
class NavRail extends StatelessWidget {
  const NavRail({
    super.key,
    required this.destinations,
    required this.current,
    required this.onSelected,
    required this.onAdd,
  });

  final List<NavDestination> destinations;
  final String current;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Primary',
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: SkColors.surface,
          border: Border(right: BorderSide(color: SkColors.line)),
        ),
        child: Column(
          children: [
            const _BrandMark(size: 40, radius: 12, iconSize: 20),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Add split',
              child: Material(
                color: SkColors.brand,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAdd,
                  child: const SizedBox.square(
                    dimension: 56,
                    child: Center(child: SkIcon('plus', size: 26, color: Colors.white)),
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
                                color: d.key == current ? SkColors.brandSoft : Colors.transparent,
                                borderRadius: BorderRadius.circular(SkRadius.chip),
                              ),
                              alignment: Alignment.center,
                              child: SkIcon(d.glyph, size: 22, color: _fg(d.key == current)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.label,
                              style: SkText.body(12, d.key == current ? 700 : 500, color: _fg(d.key == current)),
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
  });

  final List<NavDestination> destinations;
  final String current;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final SkPerson user;

  /// "Administrator" or "Personal account".
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: const BoxDecoration(
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
          Material(
            color: SkColors.brand,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdd,
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SkIcon('plus', size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Add split', style: SkText.body(15, 700, color: Colors.white)),
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
                  _SidebarItem(d, on: d.key == current, onTap: () => onSelected(d.key)),
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
  const _SidebarItem(this.d, {required this.on, required this.onTap});
  final NavDestination d;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: d.label,
      child: Material(
        color: on ? SkColors.brandSoft : Colors.transparent,
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
                  SkIcon(d.glyph, size: 20, color: _fg(on)),
                  const SizedBox(width: 12),
                  Text(d.label, style: SkText.body(15, on ? 700 : 500, color: _fg(on))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
