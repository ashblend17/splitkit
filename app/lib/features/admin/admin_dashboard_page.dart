import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'admin_providers.dart';
import 'admin_users_page.dart' show canViewAs;
import 'admin_widgets.dart';
import 'view_as.dart';

/// Recent-activity tabs and the audit entity kinds each one shows.
const activityTabs = <(String, String)>[
  ('All', ''),
  ('Expenses', 'expense'),
  ('Settlements', 'settlement'),
  ('Users', 'user,group,admin_session'),
  ('Imports', 'import_batch'),
];

const _planned = ['Error monitoring', 'System health', 'Suspend user', 'Data repair tools'];

/// Screen 16 (AdminDashboard): view-as picker, totals, recent activity and system facts.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  String _tab = '';
  AdminUserOut? _viewAs;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(adminDashboardProvider);
    return AdminPage(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminTitle(
              'Admin',
              subtitle: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SkIcon('shield', size: 16, color: SkColors.ink2),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Master account · every admin action is written to the audit log',
                      style: SkText.body(13, 400, color: SkColors.ink2),
                    ),
                  ),
                ],
              ),
            ),
            AdminSearchField(
              hint: 'Search users by name or email',
              onChanged: (_) {},
              onSubmitted: (q) => context.go(q.trim().isEmpty ? '/admin/users' : '/admin/users?q=${Uri.encodeQueryComponent(q.trim())}'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _switcher(),
        const SizedBox(height: 20),
        AsyncBody(
          value: dashboard,
          onRetry: () => ref.invalidate(adminDashboardProvider),
          skeletonRows: 4,
          builder: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stats(d),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final activity = _activity(d);
                  final side = _side(d);
                  if (box.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [activity, const SizedBox(height: 16), side],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: activity),
                      const SizedBox(width: 16),
                      Expanded(child: side),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "View the app as a user": everyone who can be viewed as (not admins, not placeholders).
  Widget _switcher() {
    final users = ref.watch(adminUsersProvider((q: '', role: 'user'))).value?.items ?? const <AdminUserOut>[];
    final targets = users.where(canViewAs).toList();
    final selected = _viewAs ?? (targets.isEmpty ? null : targets.first);
    return UserSwitcher(
      users: [for (final u in targets) SkPerson(id: u.id, name: u.name)],
      selected: selected == null ? null : SkPerson(id: selected.id, name: selected.name),
      onChanged: (p) => setState(() => _viewAs = targets.firstWhere((u) => u.id == p.id)),
      onOpen: selected == null ? null : () => ref.read(viewAsLauncherProvider)(context, selected),
    );
  }

  Widget _stats(AdminDashboardOut d) {
    String volume(List<MoneyTotal> v) =>
        v.isEmpty ? 'nothing yet' : '${v.map((m) => money(m.amountMinor, m.currency)).join(' · ')} total';
    final tiles = [
      ('Users', '${d.users}', d.admins == 1 ? '1 admin' : '${d.admins} admins', () => context.go('/admin/users')),
      ('Groups', '${d.groups}', '${d.groupsActiveWeek} active this week', null),
      ('Expenses', '${d.expenses}', '${d.expensesImported} imported', null),
      ('Settlements', '${d.settlements}', volume(d.settlementVolume), null),
      (
        'Personal txns',
        '${d.personalTransactions}',
        'across ${d.personalUsers} ${d.personalUsers == 1 ? 'user' : 'users'}',
        null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth >= 900 ? 5 : (box.maxWidth >= 520 ? 3 : 2);
        final width = (box.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value, note, onTap) in tiles)
              SizedBox(
                width: width,
                child: SkCard(
                  radius: 14,
                  onTap: onTap,
                  semanticLabel: '$label: $value, $note',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: SkText.body(13, 600, color: SkColors.ink2)),
                        const SizedBox(height: 4),
                        Text(value, style: SkText.display(30, 800)),
                        const SizedBox(height: 4),
                        Text(note, style: SkText.body(12, 400, color: SkColors.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _activity(AdminDashboardOut d) {
    final entries = _tab.isEmpty
        ? AsyncValue.data(d.recent)
        : ref.watch(adminAuditProvider((entities: _tab, adminOnly: false, limit: 8, offset: 0))).whenData((p) => p.items);
    return AdminSection(
      title: 'Recent activity',
      trailing: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final (label, entities) in activityTabs)
            _Tab(label: label, selected: _tab == entities, onTap: () => setState(() => _tab = entities)),
          _Tab(label: 'Audit log', icon: 'next', selected: false, onTap: () => context.go('/admin/audit')),
        ],
      ),
      child: AsyncBody(
        value: entries,
        onRetry: () => ref.invalidate(adminAuditProvider),
        builder: (list) => AuditTable(entries: list),
      ),
    );
  }

  Widget _side(AdminDashboardOut d) {
    final s = d.system;
    final facts = [
      ('API', 'v${s.apiVersion} · healthy'),
      ('Database', '${s.database} · ${_size(s.databaseBytes)}'),
      ('View-as sessions', d.openSessions == 0 ? 'none open' : '${d.openSessions} open'),
      (
        'Last import',
        s.lastImportAt == null
            ? 'none yet'
            : '${_source(s.lastImportSource)} · ${dayLabel(s.lastImportAt!.toLocal()).toLowerCase()}',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text('System', style: SkText.display(18, 700))),
              for (final (k, v) in facts) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(k, style: SkText.body(14, 400, color: SkColors.ink2))),
                    Flexible(child: Text(v, style: SkText.body(14, 600), textAlign: TextAlign.end)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SkPalette.tableHead,
            borderRadius: BorderRadius.circular(SkRadius.card),
            border: Border.all(color: SkColors.lineStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Planned tools', style: SkText.body(14, 700, color: SkColors.ink2)),
              for (final p in _planned) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(p, style: SkText.body(14, 400, color: SkColors.ink2))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(SkRadius.chip)),
                      child: Text('Later', style: SkText.body(11, 700, color: SkColors.ink2)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _size(int bytes) => bytes >= 1 << 30
      ? '${(bytes / (1 << 30)).toStringAsFixed(1)} GB'
      : '${(bytes / (1 << 20)).round()} MB';

  static String _source(String? source) =>
      source == null || source.isEmpty ? 'Import' : '${source[0].toUpperCase()}${source.substring(1)}';
}

/// Pill tab in the Recent activity header ("All" dark when selected).
class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : SkColors.ink2;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SkColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // No alignment: a Container with one fills the width it's given, and in the
          // header's Wrap that put every tab on its own line.
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: SkText.body(13, 600, color: fg)),
                if (icon != null) ...[const SizedBox(width: 4), SkIcon(icon!, size: 14, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
