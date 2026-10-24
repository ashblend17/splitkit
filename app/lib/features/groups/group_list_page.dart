import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/local/writes.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

class GroupListPage extends ConsumerStatefulWidget {
  const GroupListPage({super.key});

  @override
  ConsumerState<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends ConsumerState<GroupListPage> {
  final _search = TextEditingController();
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (GoRouterState.of(context).uri.queryParameters['new'] == '1') _newGroup();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newGroup() async {
    final created = await showNewGroupSheet(context);
    if (created != null && mounted) context.go('/groups/${created.id}');
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final archived = ref.watch(archivedGroupsProvider).value ?? const <GroupOut>[];
    final q = _search.text.trim().toLowerCase();
    bool matches(GroupOut g) => g.name.toLowerCase().contains(q);
    final wide = isWideLayout(context);
    final search = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SkColors.line),
      ),
      child: Row(
        children: [
          SkIcon('search', size: 18, color: SkColors.ink2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              style: SkText.body(15, 400),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search groups',
                hintStyle: SkText.body(15, 400, color: SkColors.ink2),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.brand,
          onRefresh: () async {
            refreshLedger(ref.invalidate);
            await ref.read(groupsProvider.future);
          },
          child: ListView(
            padding: tabPagePadding(context),
            children: [
              TabPageWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('Groups', style: SkText.title)),
                        ),
                        // Desktop: search beside the title, as on Home.
                        if (wide) ...[SizedBox(width: 320, child: search), const SizedBox(width: 12)],
                        SkButton(
                          'New group',
                          icon: 'plus',
                          variant: SkButtonVariant.strong,
                          size: SkButtonSize.small,
                          onPressed: _newGroup,
                        ),
                      ],
                    ),
                    if (!wide) ...[const SizedBox(height: 16), search],
                    const SizedBox(height: 16),
                    AsyncBody(
                      value: groups,
                      onRetry: () => ref.invalidate(groupsProvider),
                      builder: (all) {
                        final shown = all.where(matches).toList();
                        final shownArchived = archived.where(matches).toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (all.isEmpty)
                              EmptyState(
                                title: 'No groups yet',
                                body: 'Make a group for your flat, a trip or a dinner, then add what people paid.',
                                actionLabel: 'New group',
                                onAction: _newGroup,
                              )
                            else if (shown.isEmpty && shownArchived.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No group called “${_search.text.trim()}”',
                                  textAlign: TextAlign.center,
                                  style: SkText.body(15, 500, color: SkColors.ink2),
                                ),
                              ),
                            if (shown.isNotEmpty)
                              CardColumns(minWidth: 340, gap: 10, children: [for (final g in shown) _card(g)]),
                            if (shownArchived.isNotEmpty) ..._archived(shownArchived, searching: q.isNotEmpty),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Archived groups, folded away under the others (open while searching finds one).
  List<Widget> _archived(List<GroupOut> groups, {required bool searching}) {
    final open = _showArchived || searching;
    return [
      const SizedBox(height: 16),
      Semantics(
        button: true,
        expanded: open,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: searching ? null : () => setState(() => _showArchived = !_showArchived),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(child: Text('Archived (${groups.length})', style: SkText.body(14, 600, color: SkColors.ink2))),
                if (!searching) SkIcon(open ? 'up' : 'down', size: 18, color: SkColors.ink2),
              ],
            ),
          ),
        ),
      ),
      if (open)
        CardColumns(minWidth: 340, gap: 10, children: [for (final g in groups) Opacity(opacity: 0.7, child: _card(g))]),
    ];
  }

  Widget _card(GroupOut g) {
    final n = g.members.length;
    return GroupCard(
      name: g.name,
      glyph: glyphOr(g.icon, 'groups'),
      meta: '$n ${n == 1 ? 'member' : 'members'} · ${money(g.totalSpentMinor, g.currency)} spent',
      label: groupNetLabel(g.myNetMinor),
      amount: money(g.myNetMinor.abs(), g.currency),
      tone: toneFor(g.myNetMinor),
      lastActive: activityLabel(g.lastActivityAt),
      members: [for (final m in g.members) personOf(m.user)],
      onTap: () => context.go('/groups/${g.id}'),
    );
  }
}

const _groupIcons = [
  ('groups', 'General'),
  ('travel', 'Trip'),
  ('rent', 'Home'),
  ('food', 'Food'),
  ('shopping', 'Shopping'),
  ('entertainment', 'Fun'),
];

/// Name, icon and currency for a new group. Returns the created group.
Future<GroupOut?> showNewGroupSheet(BuildContext context) =>
    showAppBottomSheet<GroupOut>(context, title: 'New group', child: const _NewGroupForm());

class _NewGroupForm extends ConsumerStatefulWidget {
  const _NewGroupForm();

  @override
  ConsumerState<_NewGroupForm> createState() => _NewGroupFormState();
}

class _NewGroupFormState extends ConsumerState<_NewGroupForm> {
  final _name = TextEditingController();
  String _icon = 'groups';
  late String _currency = ref.read(meProvider).currency;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the group a name');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(writesProvider)
          .createGroup(
            GroupIn(
              name: _name.text.trim(),
              icon: GroupInIconEnum.fromJson(_icon)!,
              currency: GroupInCurrencyEnum.fromJson(_currency)!,
            ),
          );
      final g = await ref.read(groupProvider(id).future);
      if (mounted) Navigator.of(context).pop(g);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkTextField(
            label: 'Name',
            controller: _name,
            hint: 'Goa Trip, Flatmates…',
            autofocus: true,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 14),
          Text('Icon', style: SkText.body(13, 600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (glyph, label) in _groupIcons)
                SelectableChip(
                  label: label,
                  icon: glyph,
                  selected: _icon == glyph,
                  onTap: () => setState(() => _icon = glyph),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Currency', style: SkText.body(13, 600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final c in supportedCurrencies.keys)
                SelectableChip(
                  label: '$c ${currencySymbol(c)}',
                  selected: _currency == c,
                  onTap: () => setState(() => _currency = c),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SkButton(
            _busy ? 'Creating…' : 'Create group',
            onPressed: _busy ? null : _create,
            size: SkButtonSize.large,
            expand: true,
          ),
        ],
      ),
    );
  }
}
