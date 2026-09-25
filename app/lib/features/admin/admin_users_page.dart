import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';
import 'view_as.dart';

const _roles = <(String, String?)>[('Any role', null), ('Admins', 'admin'), ('Users', 'user')];

/// Screen 17 (AdminUsers): search, the users table and the selected user's panel.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late String _q = widget.initialQuery;
  String? _role;
  String? _selectedId;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _q = text);
    });
  }

  AdminUsersQuery get _query => (q: _q, role: _role);

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(adminUsersProvider(_query));
    return AdminPage(
      children: [
        AdminTitle('Users', crumb: 'Admin', onCrumb: () => context.go('/admin')),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminSearchField(
              hint: 'Name or email',
              controller: _search,
              width: 320,
              onChanged: _onSearch,
              onSubmitted: (t) => setState(() => _q = t),
            ),
            for (final (label, role) in _roles)
              SkFilterChip(label: label, selected: _role == role, onTap: () => setState(() => _role = role)),
            if (page.value case final p?)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  p.total == 1 ? '1 user' : '${p.total} users',
                  style: SkText.body(13, 400, color: SkColors.ink2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncBody(
          value: page,
          onRetry: () => ref.invalidate(adminUsersProvider(_query)),
          skeletonRows: 5,
          builder: (p) {
            if (p.items.isEmpty) {
              return const EmptyState(
                glyph: 'search',
                title: 'No one matches',
                body: 'Try part of a name or an email address.',
              );
            }
            final selected = p.items.where((u) => u.id == _selectedId).firstOrNull ?? p.items.first;
            return LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 1000;
                final table = SkCard(
                  padding: EdgeInsets.zero,
                  child: _UsersTable(
                    users: p.items,
                    selectedId: wide ? selected.id : null,
                    onSelect: (u) {
                      if (wide) {
                        setState(() => _selectedId = u.id);
                      } else {
                        showAppBottomSheet<void>(context, title: u.name, child: UserPanel(user: u, showHeader: false));
                      }
                    },
                  ),
                );
                if (!wide) return table;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: table),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: SkCard(padding: const EdgeInsets.all(20), child: UserPanel(user: selected))),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Whether the admin can open the app as [u]: not admins, not people without an account.
bool canViewAs(AdminUserOut u) => u.role != 'admin' && !u.isPlaceholder;

class _UsersTable extends ConsumerWidget {
  const _UsersTable({required this.users, required this.selectedId, required this.onSelect});
  final List<AdminUserOut> users;
  final String? selectedId;
  final ValueChanged<AdminUserOut> onSelect;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final full = box.maxWidth >= 720;
        Widget cells(List<(double?, Widget)> cols) => Row(
          children: [
            for (final (i, (width, child)) in cols.indexed) ...[
              if (i > 0) const SizedBox(width: _gap),
              width == null ? Expanded(child: child) : SizedBox(width: width, child: child),
            ],
          ],
        );
        Text head(String t) => Text(t, style: SkText.body(12, 700, color: SkColors.ink2, letterSpacing: 12 * 0.05));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: SkPalette.tableHead,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: cells([
                (null, head('USER')),
                if (full) ...[(70.0, head('GROUPS')), (80.0, head('EXPENSES')), (110.0, head('LAST ACTIVE'))],
                (120.0, head('NET BALANCE')),
                (104.0, const SizedBox()),
              ]),
            ),
            for (final u in users)
              Material(
                color: u.id == selectedId ? SkPalette.brandWash : SkColors.surface,
                child: InkWell(
                  onTap: () => onSelect(u),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: SkPalette.divider))),
                    alignment: Alignment.centerLeft,
                    child: cells([
                      (null, _identity(u)),
                      if (full) ...[
                        (70.0, Text('${u.groupCount}', style: SkText.body(14, 400))),
                        (80.0, Text('${u.expenseCount}', style: SkText.body(14, 400))),
                        (110.0, Text(lastActiveLabel(u.lastActiveAt), style: SkText.body(14, 400, color: SkColors.ink2))),
                      ],
                      (
                        120.0,
                        Text(netLabel(u.balances), style: SkText.display(14, 700, color: netColor(u.balances))),
                      ),
                      (
                        104.0,
                        Align(
                          alignment: Alignment.centerRight,
                          child: canViewAs(u) ? ViewAsButton(user: u) : const SizedBox(),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _identity(AdminUserOut u) => Row(
    children: [
      Avatar(SkPerson(id: u.id, name: u.name), size: 36),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: u.name, style: SkText.body(14, 700)),
                  if (u.role == 'admin')
                    TextSpan(text: '  ADMIN', style: SkText.body(11, 700, color: SkPalette.pendingInk)),
                  if (u.isPlaceholder)
                    TextSpan(text: '  NO ACCOUNT', style: SkText.body(11, 700, color: SkColors.ink2)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              u.email ?? 'Added by name only',
              style: SkText.body(12, 400, color: SkColors.ink2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Outlined "View as" button for a users-table row.
class ViewAsButton extends ConsumerWidget {
  const ViewAsButton({super.key, required this.user});
  final AdminUserOut user;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    button: true,
    label: 'View as ${user.name}',
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SkColors.adminInk, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(viewAsLauncherProvider)(context, user),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkIcon('eye', size: 16, color: SkColors.adminInk),
                const SizedBox(width: 6),
                Text('View as', style: SkText.body(13, 700, color: SkColors.adminInk)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The selected user: joined, currency, what they have, and "View app as …".
class UserPanel extends ConsumerWidget {
  const UserPanel({super.key, required this.user, this.showHeader = true});
  final AdminUserOut user;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    Widget fact(String k, String v) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SkColors.paper, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: SkText.body(13, 400, color: SkColors.ink2)),
            Text(v, style: SkText.body(13, 700)),
          ],
        ),
      ),
    );
    final inspect = [
      ('Groups', '${u.groupCount}', 'groups'),
      ('Expenses', '${u.expenseCount}', 'bills'),
      ('Settlements', '${u.settlementCount}', 'settle'),
      ('Personal transactions', '${u.personalCount}', 'wallet'),
      ('Balance', netLabel(u.balances), 'swap'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Avatar(SkPerson(id: u.id, name: u.name), size: 52, fontSize: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name, style: SkText.display(20, 700)),
                    Text(u.email ?? 'No account yet', style: SkText.body(13, 400, color: SkColors.ink2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            fact('Joined', DateFormat('d MMM y').format(u.createdAt.toLocal())),
            const SizedBox(width: 8),
            fact('Currency', u.currency),
          ],
        ),
        const SizedBox(height: 14),
        const Overline('Inspect'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SkColors.line),
          ),
          child: Column(
            children: [
              for (final (i, (label, count, glyph)) in inspect.indexed)
                Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : const Border(top: BorderSide(color: SkPalette.divider)),
                  ),
                  child: Row(
                    children: [
                      SkIcon(glyph, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(label, style: SkText.body(14, 600))),
                      Text(
                        count,
                        style: SkText.body(14, 500, color: label == 'Balance' ? netColor(u.balances) : SkColors.ink2),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (canViewAs(u))
          Material(
            color: SkColors.adminInk,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ref.read(viewAsLauncherProvider)(context, u),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SkIcon('eye', size: 18, color: SkColors.adminBand),
                    const SizedBox(width: 8),
                    Text(
                      'View app as ${firstName(u.name)}',
                      style: SkText.body(15, 700, color: SkColors.adminBand),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Text(
            u.role == 'admin'
                ? "Admins can't be viewed as."
                : "${firstName(u.name)} doesn't have an account, so there's nothing to view as them.",
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
      ],
    );
  }
}
