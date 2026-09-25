import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'sk_icon.dart';

/// Amber band shown on every screen while an admin is viewing as someone. Not dismissible:
/// only Exit ends it.
class AdminBanner extends StatelessWidget {
  const AdminBanner({
    super.key,
    required this.viewingAs,
    required this.onExit,
    this.wide = false,
    this.modeNote = 'Read-only · any change is logged as Admin',
    this.onSwitchUser,
  });

  final String viewingAs;
  final VoidCallback onExit;

  /// Desktop layout: adds the mode note and "Switch user".
  final bool wide;
  final String modeNote;
  final VoidCallback? onSwitchUser;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showNote = wide && constraints.maxWidth >= 720;
        final showSwitch = wide && onSwitchUser != null && constraints.maxWidth >= 480;
        return Semantics(
          container: true,
          liveRegion: true,
          label: 'Admin mode. Viewing as $viewingAs',
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            decoration: const BoxDecoration(
              color: SkColors.adminBand,
              border: Border(bottom: BorderSide(color: SkColors.adminInk, width: 2)),
            ),
            child: Row(
              children: [
                const SkIcon('shield', size: 20, color: SkColors.adminInk),
                const SizedBox(width: 10),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ADMIN MODE',
                          style: SkText.body(11, 800, color: SkColors.adminInk, height: 1.2, letterSpacing: 11 * 0.08),
                        ),
                        Text(
                          'Viewing as $viewingAs',
                          style: SkText.body(14, 600, color: SkColors.adminInk, height: 1.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                if (showNote) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SkRadius.chip),
                        border: Border.all(color: SkColors.adminInk, width: 1.5),
                      ),
                      child: Text(
                        modeNote,
                        style: SkText.body(13, 500, color: SkColors.adminInk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                if (showSwitch) ...[
                  const SizedBox(width: 10),
                  _BannerButton(
                    label: 'Switch user',
                    icon: 'swap',
                    onTap: onSwitchUser!,
                    background: const Color(0x141B1403),
                    foreground: SkColors.adminInk,
                    weight: 600,
                  ),
                ],
                const SizedBox(width: 10),
                _BannerButton(
                  label: 'Exit',
                  onTap: onExit,
                  background: SkColors.adminInk,
                  foreground: SkColors.adminBand,
                  weight: 700,
                  minWidth: 64,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.weight,
    this.icon,
    this.minWidth = 0,
  });

  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final int weight;
  final String? icon;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          constraints: BoxConstraints(minWidth: minWidth),
          padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[SkIcon(icon!, size: 16, color: foreground), const SizedBox(width: 6)],
              Text(label, style: SkText.body(14, weight, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the whole viewport in the 4px amber frame while impersonating.
class AdminFrame extends StatelessWidget {
  const AdminFrame({super.key, required this.active, required this.child, this.radius = 0});

  final bool active;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SkColors.adminBand, width: 4),
        borderRadius: radius == 0 ? null : BorderRadius.circular(radius),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius == 0 ? 0 : radius - 4), child: child),
    );
  }
}

/// "View the app as a user" panel from the admin dashboard.
class UserSwitcher extends StatelessWidget {
  const UserSwitcher({
    super.key,
    required this.users,
    required this.selected,
    required this.onChanged,
    required this.onOpen,
  });

  final List<SkPerson> users;
  final SkPerson? selected;
  final ValueChanged<SkPerson> onChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final picker = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Viewing as', style: SkText.body(12, 600, color: SkColors.ink2)),
        const SizedBox(height: 4),
        Container(
          height: 44,
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SkColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SkColors.lineStrong, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selected?.id,
              icon: const SkIcon('down', size: 16),
              style: SkText.body(14, 600),
              items: [for (final u in users) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (id) => onChanged(users.firstWhere((u) => u.id == id)),
            ),
          ),
        ),
      ],
    );
    final open = Material(
      color: SkColors.adminInk,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Text(
            selected == null ? 'Open' : 'Open as ${selected!.name.split(' ').first}',
            style: SkText.body(14, 700, color: SkColors.adminBand),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: SkColors.adminSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkPalette.adminBorder, width: 1.5),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: SkColors.adminBand, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const SkIcon('eye', size: 20, color: SkColors.adminInk),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View the app as a user', style: SkText.body(15, 700)),
                      const SizedBox(height: 2),
                      Text(
                        'Opens their full view read-only, with an admin banner. Edits need an explicit switch and are logged as you.',
                        style: SkText.body(13, 400, color: SkColors.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          picker,
          open,
        ],
      ),
    );
  }
}
