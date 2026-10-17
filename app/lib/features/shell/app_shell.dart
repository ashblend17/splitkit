import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/layout/layout.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../home/activity_filters.dart';
import '../personal/personal_txn_sheet.dart';
import '../sms/sms_watcher.dart';
import 'app_mode.dart';

/// Signed-in shell: tab bar under 600px, navigation rail up to 1279px (HomeTablet), sidebar
/// from 1280px (HomeDesktop).
///
/// The app has two modes, Split and Personal, each with its own tabs, add button and accent.
/// The Split | Personal switch sits above every tab on a phone, and in the rail and sidebar.
/// Profile and Admin belong to both modes. The rail and sidebar carry the add button; on
/// phones it floats on Home and a group's page (Split) and on Overview and Transactions
/// (Personal).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell, required this.location});

  final StatefulNavigationShell shell;

  /// Current path, so "Add split" inside a group starts in that group.
  final String location;

  /// One per shell branch, in the router's order.
  static const _keys = ['home', 'groups', 'overview', 'transactions', 'insights', 'profile', 'admin'];

  /// The tabs that belong to one mode. The others (Profile, Admin) keep whichever is on.
  static const _owner = {
    'home': AppMode.split,
    'groups': AppMode.split,
    'overview': AppMode.personal,
    'transactions': AppMode.personal,
    'insights': AppMode.personal,
  };

  /// Tab roots: where a phone shows the mode switch above the page.
  static const _roots = {'/home', '/groups', '/personal', '/personal/transactions', '/personal/insights', '/profile', '/admin'};
  static final _inGroup = RegExp(r'^/groups/([^/]+)');

  /// A group's tabs, where the phone floats "Add split" for that group.
  static final _groupPage = RegExp(r'^/groups/([^/]+)(/(balances|analytics|members))?$');

  void _select(String key) {
    final index = _keys.indexOf(key);
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  /// Switches mode, back to the tab you last used in it.
  void _switchTo(WidgetRef ref, AppMode mode) {
    final modes = ref.read(appModeProvider.notifier);
    modes.set(mode);
    _select(modes.lastTab(mode));
  }

  void _add(BuildContext context, AppMode mode) {
    if (mode == AppMode.personal) {
      showPersonalTxnSheet(context);
      return;
    }
    final group = _inGroup.firstMatch(location)?.group(1);
    context.push(group == null ? '/expenses/new' : '/expenses/new?group=$group');
  }

  /// The phone's floating add button. It sits on this scaffold rather than the pages' own so
  /// snackbars (which show here, on the outermost scaffold) move up above it, not over it.
  Widget? _fab(BuildContext context, WidgetRef ref) {
    if (location == '/personal' || location == '/personal/transactions') {
      return AddSplitFab(label: 'Add entry', color: SkColors.personal, onPressed: () => showPersonalTxnSheet(context));
    }
    if (location == '/home') {
      final groupId = ref.watch(activityFiltersProvider.select((f) => f.groupId));
      return AddSplitFab(
        onPressed: () => context.push(groupId == null ? '/expenses/new' : '/expenses/new?group=$groupId'),
      );
    }
    final groupId = _groupPage.firstMatch(location)?.group(1);
    final group = groupId == null ? null : ref.watch(groupProvider(groupId)).value;
    if (group == null) return null;
    return Semantics(
      label: 'Add expense to ${group.name}',
      child: AddSplitFab(onPressed: () => context.push('/expenses/new?group=${group.id}')),
    );
  }

  /// The branch as a semantics container of its own. A page's route barrier hides from
  /// screen readers everything painted before it in the same container, which beside the
  /// branch would be the rail or sidebar.
  static Widget _contained(Widget branch) => Semantics(container: true, child: branch);

  @override
  Widget build(BuildContext context, WidgetRef ref) => SmsWatcher(child: _shell(context, ref));

  Widget _shell(BuildContext context, WidgetRef ref) {
    final current = _keys[shell.currentIndex];
    final owner = _owner[current];
    final saved = ref.watch(appModeProvider);
    final mode = owner ?? saved;
    if (owner != null) {
      final modes = ref.read(appModeProvider.notifier)..visited(owner, current);
      // A tab of the other mode was opened (a link, Back): that mode is on now.
      if (owner != saved) WidgetsBinding.instance.addPostFrameCallback((_) => modes.set(owner));
    }
    final personal = mode == AppMode.personal;
    final admin = ref.watch(meProvider).role == 'admin';
    final destinations = personal ? NavDestination.personal(admin: admin) : NavDestination.split(admin: admin);
    final accent = personal ? NavAccent.personal : NavAccent.brand;
    final addLabel = personal ? 'Add entry' : 'Add split';
    void onMode(bool toPersonal) => _switchTo(ref, toPersonal ? AppMode.personal : AppMode.split);
    switch (SkLayout.of(context)) {
      case SkLayout.compact:
        return Scaffold(
          // In the app bar slot, not above the body in a Column: the slot paints after the
          // body, so the pages' route barriers don't hide the switch from screen readers,
          // and the branch keeps its place (and state) whether or not the switch shows.
          appBar: _roots.contains(location) ? _ModeBar(personal: personal, onChanged: onMode) : null,
          body: shell,
          floatingActionButton: _fab(context, ref),
          bottomNavigationBar: BottomNav(
            destinations: destinations,
            current: current,
            onSelected: _select,
            accent: accent,
          ),
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
                  onAdd: () => _add(context, mode),
                  addLabel: addLabel,
                  accent: accent,
                  modeSwitch: SizedBox(
                    width: 72,
                    child: ModeSwitch(personal: personal, onChanged: onMode, direction: Axis.vertical),
                  ),
                ),
              ),
              Expanded(child: _contained(shell)),
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
                onAdd: () => _add(context, mode),
                addLabel: addLabel,
                accent: accent,
                modeSwitch: ModeSwitch(personal: personal, onChanged: onMode, expand: true),
                user: SkPerson(id: me.id, name: me.name),
                role: me.role == 'admin' ? 'Administrator' : 'Personal account',
              ),
              Expanded(child: _contained(shell)),
            ],
          ),
        );
    }
  }
}

/// The phone's Split | Personal switch, above every tab root.
class _ModeBar extends StatelessWidget implements PreferredSizeWidget {
  const _ModeBar({required this.personal, required this.onChanged});
  final bool personal;
  final ValueChanged<bool> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Center(child: ModeSwitch(personal: personal, onChanged: onChanged)),
    ),
  );
}
