import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/local/writes.dart';
import '../../core/layout/layout.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../analytics/group_analytics_tab.dart';
import '../common/common.dart';
import '../expenses/activity_table.dart';
import '../expenses/feed_list.dart';
import '../home/home_wide.dart' show ListCard;
import '../settlements/settlement_sheet.dart';
import '../tricount_sync/tricount_status_line.dart';
import 'group_balances_tab.dart';
import 'settle_plan.dart';

/// A group's tabs. Each has its own address (`/groups/<id>`, `/groups/<id>/balances`, ...), and
/// all of them are this one page, so the header, tabs and width stay put and only what's under
/// the tabs changes.
enum GroupTab {
  expenses('Expenses'),
  balances('Balances'),
  analytics('Analytics'),
  members('Members');

  const GroupTab(this.label);
  final String label;

  String path(String groupId) => this == expenses ? '/groups/$groupId' : '/groups/$groupId/$name';
}

class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({super.key, required this.groupId, this.tab = GroupTab.expenses});
  final String groupId;
  final GroupTab tab;

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  GroupTab get _tab => widget.tab;

  void _open(GroupTab tab) {
    if (tab != _tab) context.go(tab.path(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    final layout = SkLayout.of(context);
    if (layout == SkLayout.expanded) {
      return Scaffold(
        body: AsyncBody(value: group, onRetry: () => ref.invalidate(groupProvider(widget.groupId)), builder: _desktop),
      );
    }
    // On phones the shell floats "Add split" over this page.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.brand,
          onRefresh: () async {
            refreshLedger(ref.invalidate);
            if (_tab == GroupTab.analytics) ref.invalidate(groupDashboardProvider(widget.groupId));
            await ref.read(groupProvider(widget.groupId).future);
          },
          child: CustomScrollView(
            slivers: paddedSlivers(const EdgeInsets.fromLTRB(16, 8, 16, 120), switch (AsyncBody.dataOf(group)) {
              final g? => _content(g),
              null => [
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: AsyncBody(
                      value: group,
                      onRetry: () => ref.invalidate(groupProvider(widget.groupId)),
                      builder: (_) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            }),
          ),
        ),
      ),
    );
  }

  /// The group on a phone: its header, then the tab (the expenses as a list that builds only
  /// the cards on screen).
  List<Widget> _content(GroupOut g) => [
    SliverToBoxAdapter(child: ContentWidth(child: _head(g))),
    if (_tab == GroupTab.expenses)
      ..._expenses(g)
    else
      SliverToBoxAdapter(
        child: ContentWidth(
          child: switch (_tab) {
            GroupTab.balances => GroupBalancesTab(group: g),
            GroupTab.analytics => GroupAnalyticsTab(groupId: g.id),
            GroupTab.members => _MembersTab(group: g),
            GroupTab.expenses => const SizedBox.shrink(), // above
          },
        ),
      ),
  ];

  Widget _head(GroupOut g) {
    final n = g.members.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(-8, 0),
                child: HeaderIconButton(glyph: 'back', label: 'Back to groups', onPressed: () => context.go('/groups')),
              ),
              const Spacer(),
              Transform.translate(
                offset: const Offset(8, 0),
                child: HeaderIconButton(glyph: 'more', label: 'Group settings', onPressed: () => _menu(g)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(g.name, style: SkText.display(30, 800))),
        const SizedBox(height: 6),
        Row(
          children: [
            AvatarStack([for (final m in g.members) personOf(m.user)], size: 26, ringColor: SkColors.paper),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$n ${n == 1 ? 'member' : 'members'} · ${money(g.totalSpentMinor, g.currency)} total',
                style: SkText.body(13, 400, color: SkColors.ink2),
              ),
            ),
          ],
        ),
        _archivedLine(g),
        TricountStatusLine(groupId: g.id),
        const SizedBox(height: 16),
        _summary(g),
        const SizedBox(height: 16),
        _tabs(),
        const SizedBox(height: 16),
      ],
    );
  }

  /// GroupDesktop: breadcrumb header, section tabs, the tab (the expense table first) and your
  /// balances beside it on every tab.
  Widget _desktop(GroupOut g) {
    final n = g.members.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      label: 'Breadcrumb',
                      child: Row(
                        children: [
                          Semantics(
                            link: true,
                            child: InkWell(
                              onTap: () => context.go('/groups'),
                              child: Text('Groups', style: SkText.body(13, 600, color: SkColors.brandInk)),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              ' / ${g.name}',
                              style: SkText.body(13, 400, color: SkColors.ink2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(header: true, child: Text(g.name, style: SkText.display(32, 800))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        AvatarStack([for (final m in g.members) personOf(m.user)], size: 28, ringColor: SkColors.paper),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            '$n ${n == 1 ? 'member' : 'members'} · ${money(g.totalSpentMinor, g.currency)} total',
                            style: SkText.body(14, 400, color: SkColors.ink2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SkButton(
                          'Invite',
                          variant: SkButtonVariant.secondary,
                          size: SkButtonSize.small,
                          onPressed: () => addGroupMember(context, g),
                        ),
                      ],
                    ),
                    _archivedLine(g),
                    TricountStatusLine(groupId: g.id),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              HeaderIconButton(glyph: 'more', label: 'Group settings', onPressed: () => _menu(g)),
              const SizedBox(width: 8),
              SkButton(
                'Add expense',
                icon: 'plus',
                size: SkButtonSize.large,
                onPressed: () => context.push('/expenses/new?group=${g.id}'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _tabs(),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: switch (_tab) {
                    GroupTab.expenses => SkCard(padding: EdgeInsets.zero, child: _expenseTable(g)),
                    GroupTab.balances => SingleChildScrollView(child: GroupBalancesTab(group: g)),
                    GroupTab.analytics => SingleChildScrollView(child: GroupAnalyticsTab(groupId: g.id)),
                    GroupTab.members => SingleChildScrollView(child: _MembersTab(group: g)),
                  },
                ),
                const SizedBox(width: 16),
                SizedBox(width: 360, child: SingleChildScrollView(child: _balancesAside(g))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseTable(GroupOut g) {
    final feed = ref.watch(feedProvider((groupId: g.id, deleted: false, limit: ref.watch(feedLimitProvider('group:${g.id}')))));
    return AsyncBody(
      value: feed,
      onRetry: () => ref.invalidate(feedProvider),
      builder: (items) => items.isEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                title: 'No expenses yet',
                body: "Add the first one and we'll keep the balances.",
                actionLabel: 'Add expense',
                onAction: () => context.push('/expenses/new?group=${g.id}'),
              ),
            )
          : ActivityTable(items: items, onHome: false, footer: ShowOlder(list: 'group:${g.id}', shown: items.length)),
    );
  }

  Widget _balancesAside(GroupOut g) {
    final balances = ref.watch(groupBalancesProvider(g.id));
    return AsyncBody(
      value: balances,
      onRetry: () => ref.invalidate(groupBalancesProvider(g.id)),
      builder: (b) {
        final me = ref.watch(meProvider);
        final tone = toneFor(b.netMinor);
        final (bg, ink) = switch (tone) {
          MoneyTone.owe => (SkColors.oweSoft, SkColors.oweInk),
          MoneyTone.owed => (SkColors.owedSoft, SkColors.owedInk),
          _ => (SkColors.settledSoft, SkColors.ink2),
        };
        final headline = b.netMinor > 0
            ? 'In ${g.name}, you are owed'
            : b.netMinor < 0
            ? 'In ${g.name}, you owe'
            : "In ${g.name}, you're all square";
        final plan = SettlePlan(b, me.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkCard(
              color: bg,
              borderColor: bg,
              padding: const EdgeInsets.all(18),
              semanticLabel: '$headline ${money(b.netMinor.abs(), g.currency)}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: SkText.body(13, 600, color: ink)),
                    const SizedBox(height: 4),
                    Text(
                      money(b.netMinor.abs(), g.currency),
                      style: SkText.display(34, 800, color: textColorFor(b.netMinor)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You pay ${money(plan.youPayMinor, g.currency)} · You get ${money(plan.youGetMinor, g.currency)}',
                      style: SkText.body(13, 400, color: ink),
                    ),
                  ],
                ),
              ),
            ),
            if (plan.mine.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListCard(
                title: 'To settle up',
                children: [
                  for (final (n, p) in plan.mine.indexed)
                    if (p.fromUser.id == me.id)
                      FriendBalanceRow(
                        person: SkPerson(id: p.toUser.id, name: firstName(p.toUser.name)),
                        state: 'You pay ${money(p.amountMinor, g.currency)}',
                        tone: MoneyTone.owe,
                        showDivider: n < plan.mine.length - 1,
                        onTap: () => showGroupPaymentSheet(context, plan.target(g, p)),
                        trailing: SkButton(
                          'Settle',
                          variant: SkButtonVariant.strong,
                          size: SkButtonSize.small,
                          onPressed: () => showGroupPaymentSheet(context, plan.target(g, p)),
                        ),
                      )
                    else
                      FriendBalanceRow(
                        person: SkPerson(id: p.fromUser.id, name: firstName(p.fromUser.name)),
                        state: 'Pays you ${money(p.amountMinor, g.currency)}',
                        tone: MoneyTone.owed,
                        showDivider: n < plan.mine.length - 1,
                        onTap: () => showGroupPaymentSheet(context, plan.target(g, p)),
                      ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _summary(GroupOut g) {
    final balances = ref.watch(groupBalancesProvider(g.id));
    Widget figure(String label, String value, Color color, {int weight = 700}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SkText.body(12, 600, color: SkColors.ink2)),
          const SizedBox(height: 2),
          // Shrinks rather than wraps when three big amounts share a phone's width.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: SkText.display(20, weight, color: color)),
          ),
        ],
      ),
    );
    return SkCard(
      radius: 18,
      child: Column(
        children: [
          AsyncBody(
            value: balances,
            onRetry: () => ref.invalidate(groupBalancesProvider(g.id)),
            skeletonRows: 1,
            builder: (b) {
              final plan = SettlePlan(b, ref.watch(meProvider).id);
              return Row(
                children: [
                  figure(
                    'You pay',
                    money(plan.youPayMinor, g.currency),
                    plan.youPayMinor == 0 ? SkColors.ink2 : SkColors.owe,
                  ),
                  const SizedBox(width: 8),
                  figure(
                    'You get',
                    money(plan.youGetMinor, g.currency),
                    plan.youGetMinor == 0 ? SkColors.ink2 : SkColors.owed,
                  ),
                  const SizedBox(width: 8),
                  figure(
                    'Net',
                    formatMinor(b.netMinor, currency: g.currency, signed: true),
                    textColorFor(b.netMinor),
                    weight: 800,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SkButton(
                  'Settle up',
                  icon: 'settle',
                  variant: SkButtonVariant.strong,
                  size: SkButtonSize.small,
                  expand: true,
                  onPressed: balances.hasValue ? () => _settleUp(g, balances.value!) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SkButton(
                  'View balances',
                  variant: SkButtonVariant.secondary,
                  size: SkButtonSize.small,
                  expand: true,
                  onPressed: () => _open(GroupTab.balances),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens your largest payment in the group's fewest-payments plan.
  void _settleUp(GroupOut g, GroupBalancesOut b) {
    final plan = SettlePlan(b, ref.read(meProvider).id);
    if (plan.mine.isEmpty) {
      showMessage(context, "You're all square in ${g.name}");
      return;
    }
    showGroupPaymentSheet(context, plan.target(g, plan.mine.first));
  }

  Widget _tabs() {
    Widget tab(GroupTab t) {
      final on = _tab == t;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: () => _open(t),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: on ? SkColors.brand : Colors.transparent, width: 2.5)),
            ),
            alignment: Alignment.center,
            child: Text(t.label, style: SkText.body(14, on ? 700 : 600, color: on ? SkColors.brandInk : SkColors.ink2)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: SkColors.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, t) in GroupTab.values.indexed) ...[if (i > 0) const SizedBox(width: 4), tab(t)],
          ],
        ),
      ),
    );
  }

  List<Widget> _expenses(GroupOut g) {
    final feed = ref.watch(feedProvider((groupId: g.id, deleted: false, limit: ref.watch(feedLimitProvider('group:${g.id}')))));
    if (AsyncBody.dataOf(feed) case final items? when items.isNotEmpty) {
      return [
        SliverFeedList(items: items, onHome: false, byDay: false, frame: (row) => ContentWidth(child: row)),
        SliverToBoxAdapter(child: ContentWidth(child: ShowOlder(list: 'group:${g.id}', shown: items.length))),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: ContentWidth(
          child: AsyncBody(
            value: feed,
            onRetry: () => ref.invalidate(feedProvider),
            builder: (_) => g.members.length < 2
                ? EmptyState(
                    title: 'Just you so far',
                    body: "Add the people you're splitting with, then add what you spend.",
                    actionLabel: 'Add people',
                    onAction: () => addGroupMember(context, g),
                  )
                : EmptyState(
                    title: 'No expenses yet',
                    body: "Add the first one and we'll keep the balances.",
                    actionLabel: 'Add split',
                    onAction: () => context.push('/expenses/new?group=${g.id}'),
                  ),
          ),
        ),
      ),
    ];
  }

  Future<void> _menu(GroupOut g) async {
    final choice = await showAppBottomSheet<String>(
      context,
      title: g.name,
      child: Column(
        children: [
          for (final (key, glyph, label) in [
            ('members', 'groups', 'Members'),
            ('deleted', 'trash', 'Deleted items'),
            ('tricount', 'swap', 'Sync with Tricount'),
            ('leave', 'logout', 'Leave group'),
            ('archive', 'file', g.archivedAt == null ? 'Archive group' : 'Unarchive group'),
          ])
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(key),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      SkIcon(glyph, size: 20),
                      const SizedBox(width: 12),
                      Text(label, style: SkText.body(15, 600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'members':
        _open(GroupTab.members);
      case 'deleted':
        context.go('/groups/${g.id}/deleted');
      case 'tricount':
        context.go('/groups/${g.id}/tricount');
      case 'leave':
        await _leave(g);
      case 'archive':
        await _setArchived(g, g.archivedAt == null);
    }
  }

  /// Archiving goes back to the list, where the group now sits under "Archived".
  Future<void> _setArchived(GroupOut g, bool archived) async {
    final writes = ref.read(writesProvider);
    await writes.setGroupArchived(g.id, archived);
    if (!mounted) return;
    if (!archived) return showMessage(context, '${g.name} is back');
    showMessage(context, '${g.name} archived', actionLabel: 'Undo', onAction: () => writes.setGroupArchived(g.id, false));
    context.go('/groups');
  }

  /// "Archived · Unarchive" under the name of an archived group.
  Widget _archivedLine(GroupOut g) {
    if (g.archivedAt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SkIcon('file', size: 14, color: SkColors.ink2),
          const SizedBox(width: 6),
          Text('Archived', style: SkText.body(13, 600, color: SkColors.ink2)),
          const SizedBox(width: 4),
          TextButton(onPressed: () => _setArchived(g, false), child: const Text('Unarchive')),
        ],
      ),
    );
  }

  Future<void> _leave(GroupOut g) async {
    final me = ref.read(meProvider);
    final ok = await showConfirmDialog(
      context,
      title: 'Leave ${g.name}?',
      body: "You'll stop seeing it. You need to be settled up with everyone in it first.",
      confirmLabel: 'Leave group',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(apiProvider).groups.removeMember(g.id, me.id);
      refreshLedger(ref.invalidate);
      if (mounted) {
        showMessage(context, 'You left ${g.name}');
        context.go('/groups');
      }
    } catch (e) {
      if (mounted) showMessage(context, apiErrorMessage(e));
    }
  }
}

/// Take someone out of the group (the owner only; they need to be settled up).
Future<void> removeGroupMember(BuildContext context, WidgetRef ref, GroupOut group, MemberOut m) async {
  final name = firstName(m.user.name);
  final ok = await showConfirmDialog(
    context,
    title: 'Remove $name from ${group.name}?',
    body: 'They stop seeing the group; their past expenses stay. They need to be settled up first.',
    confirmLabel: 'Remove',
  );
  if (!ok || !context.mounted) return;
  try {
    await ref.read(apiProvider).groups.removeMember(group.id, m.user.id);
    refreshLedger(ref.invalidate);
    if (context.mounted) showMessage(context, '$name is no longer in ${group.name}');
  } catch (e) {
    if (context.mounted) showMessage(context, apiErrorMessage(e));
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.group});
  final GroupOut group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final owner = group.members.any((m) => m.user.id == me.id && m.role == 'owner');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in group.members) ...[
          UserCard(
            person: personOf(m.user),
            subtitle: [
              if (m.user.id == me.id) 'You',
              if (m.role == 'owner') 'Owner',
              if (m.user.isPlaceholder == true) m.inviteEmail == null ? 'No account yet' : 'Invited · ${m.inviteEmail}',
              if (m.placeholderName != null && m.user.isPlaceholder != true) 'Was “${m.placeholderName}”',
            ].join(' · ').ifEmpty('Member'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.user.isPlaceholder == true)
                  SkButton(
                    'Link',
                    variant: SkButtonVariant.secondary,
                    size: SkButtonSize.small,
                    onPressed: () => linkGroupMember(context, group, m),
                  ),
                if (owner && m.user.id != me.id)
                  HeaderIconButton(
                    glyph: 'close',
                    label: 'Remove ${m.user.name}',
                    color: SkColors.ink3,
                    onPressed: () => removeGroupMember(context, ref, group, m),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        SkButton(
          'Add member',
          icon: 'plus',
          variant: SkButtonVariant.secondary,
          expand: true,
          onPressed: () => addGroupMember(context, group),
        ),
      ],
    );
  }
}

Future<void> addGroupMember(BuildContext context, GroupOut group) async {
  final added = await showAppBottomSheet<String>(
    context,
    title: 'Add someone',
    child: _AddMemberForm(group: group),
  );
  if (added != null && context.mounted) showMessage(context, 'Added $added to ${group.name}');
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// Links a placeholder member to an account (groups/linking.py on the server).
Future<void> linkGroupMember(BuildContext context, GroupOut group, MemberOut member) async {
  final message = await showAppBottomSheet<String>(
    context,
    title: 'Link ${member.user.name} to an account',
    child: _LinkMemberForm(groupId: group.id, member: member),
  );
  if (message != null && context.mounted) showMessage(context, message);
}

class _LinkMemberForm extends ConsumerStatefulWidget {
  const _LinkMemberForm({required this.groupId, required this.member});
  final String groupId;
  final MemberOut member;

  @override
  ConsumerState<_LinkMemberForm> createState() => _LinkMemberFormState();
}

class _LinkMemberFormState extends ConsumerState<_LinkMemberForm> {
  late final _email = TextEditingController(text: widget.member.inviteEmail);
  String? _error;
  bool _busy = false;

  String get _name => widget.member.user.name;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter their email');
      return;
    }
    setState(() => _busy = true);
    try {
      final group = await ref
          .read(apiProvider)
          .groups
          .linkMember(widget.groupId, widget.member.user.id, LinkMemberIn(email: email));
      refreshLedger(ref.invalidate);
      // Still here as a placeholder: no account had that email, so it was saved as an invite.
      final invited = group?.members.any((x) => x.user.id == widget.member.user.id) ?? false;
      if (mounted) {
        Navigator.of(
          context,
        ).pop(invited ? 'Invite saved. Signing up with $email takes $_name’s place.' : '$_name is linked to $email');
      }
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
            label: 'Their email',
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'If they have a Splitkit account, $_name’s expenses and payments move to it now. '
            'If not, they take $_name’s place when they sign up with this email. '
            'Nobody’s balance changes.',
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
          const SizedBox(height: 18),
          SkButton(
            _busy ? 'Linking…' : 'Link account',
            onPressed: _busy ? null : _submit,
            size: SkButtonSize.large,
            expand: true,
          ),
        ],
      ),
    );
  }
}

/// Pops with the first name of whoever was added.
class _AddMemberForm extends ConsumerStatefulWidget {
  const _AddMemberForm({required this.group});
  final GroupOut group;

  @override
  ConsumerState<_AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends ConsumerState<_AddMemberForm> {
  final _text = TextEditingController();
  final _name = TextEditingController();
  bool _byEmail = true;

  /// The email has no account yet: ask for a name and invite them instead.
  bool _invite = false;
  String? _error;
  String? _nameError;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _text.text.trim();
    if (value.isEmpty) {
      setState(() => _error = _byEmail ? 'Enter their email' : 'Enter their name');
      return;
    }
    final name = _name.text.trim();
    if (_byEmail && _invite && name.isEmpty) {
      setState(() => _nameError = 'Enter their name');
      return;
    }
    setState(() => _busy = true);
    try {
      final group = await ref
          .read(apiProvider)
          .groups
          .addMember(
            widget.group.id,
            !_byEmail
                ? AddMemberIn(name: value)
                : _invite
                ? AddMemberIn(email: value, name: name)
                : AddMemberIn(email: value),
          );
      refreshLedger(ref.invalidate);
      final before = {for (final m in widget.group.members) m.user.id};
      final added = group?.members.where((m) => !before.contains(m.user.id)).firstOrNull;
      final fallback = !_byEmail ? firstName(value) : (_invite ? firstName(name) : value);
      if (mounted) Navigator.of(context).pop(added == null ? fallback : firstName(added.user.name));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          if (_byEmail && !_invite && apiErrorCode(e) == 'no_account') {
            _invite = true; // ask who they are, then invite the email
          } else {
            _error = apiErrorMessage(e);
          }
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
          Wrap(
            spacing: 8,
            children: [
              SelectableChip(label: 'Has an account', selected: _byEmail, onTap: () => setState(() => _byEmail = true)),
              SelectableChip(label: 'No account', selected: !_byEmail, onTap: () => setState(() => _byEmail = false)),
            ],
          ),
          const SizedBox(height: 14),
          SkTextField(
            label: _byEmail ? 'Their email' : 'Their name',
            controller: _text,
            autofocus: true,
            keyboardType: _byEmail ? TextInputType.emailAddress : TextInputType.name,
            errorText: _error,
            onChanged: (_) {
              if (_error != null || _invite) {
                setState(() {
                  _error = null;
                  _invite = false; // a different email may have an account
                });
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_byEmail && _invite) ...[
            const SizedBox(height: 10),
            Text(
              "There's no Splitkit account with that email yet. Add their name: they can be part of "
              'splits now, and join the group when they sign up with this email.',
              style: SkText.body(13, 400, color: SkColors.ink2, height: 1.4),
            ),
            const SizedBox(height: 10),
            SkTextField(
              label: 'Their name',
              controller: _name,
              autofocus: true,
              keyboardType: TextInputType.name,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              onSubmitted: (_) => _submit(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _byEmail
                  ? 'They see the group next time they open Splitkit.'
                  : 'They can be part of splits now and link an account later.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            ),
          ],
          const SizedBox(height: 18),
          SkButton(
            _busy
                ? 'Adding…'
                : _byEmail && _invite
                ? 'Add and invite'
                : 'Add to group',
            onPressed: _busy ? null : _submit,
            size: SkButtonSize.large,
            expand: true,
          ),
        ],
      ),
    );
  }
}
