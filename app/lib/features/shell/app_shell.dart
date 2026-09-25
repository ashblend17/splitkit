import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/layout.dart';
import '../../core/session/session.dart';
import '../../design_system/design_system.dart';

/// Signed-in shell: tab bar under 600px, navigation rail up to 1279px (HomeTablet), sidebar
/// from 1280px (HomeDesktop). The rail and sidebar carry "Add split"; on phones each page
/// shows its own floating button.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell, required this.location});

  final StatefulNavigationShell shell;

  /// Current path, so "Add split" inside a group starts in that group.
  final String location;

  static const _keys = ['home', 'groups', 'personal', 'profile', 'admin'];
  static final _inGroup = RegExp(r'^/groups/([^/]+)');

  void _select(String key) {
    final index = _keys.indexOf(key);
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  void _add(BuildContext context) {
    final group = _inGroup.firstMatch(location)?.group(1);
    context.push(group == null ? '/expenses/new' : '/expenses/new?group=$group');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The Admin tab arrives with the admin area (build step 8).
    final destinations = NavDestination.primary();
    final current = _keys[shell.currentIndex];
    switch (SkLayout.of(context)) {
      case SkLayout.compact:
        return Scaffold(
          body: shell,
          bottomNavigationBar: BottomNav(destinations: destinations, current: current, onSelected: _select),
        );
      case SkLayout.medium:
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavRail(
                  destinations: destinations,
                  current: current,
                  onSelected: _select,
                  onAdd: () => _add(context),
                ),
              ),
              Expanded(child: shell),
            ],
          ),
        );
      case SkLayout.expanded:
        final me = ref.watch(meProvider);
        return Scaffold(
          body: Row(
            children: [
              WebSidebar(
                destinations: destinations,
                current: current,
                onSelected: _select,
                onAdd: () => _add(context),
                user: SkPerson(id: me.id, name: me.name),
                role: me.role == 'admin' ? 'Administrator' : 'Personal account',
              ),
              Expanded(child: shell),
            ],
          ),
        );
    }
  }
}
