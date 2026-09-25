import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/layout/layout.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../expenses/activity_table.dart';
import '../expenses/feed_list.dart';
import '../home/home_wide.dart' show ListCard;
import '../settlements/settlement_sheet.dart';

enum _Tab { expenses, balances, analytics, members }

class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  _Tab _tab = _Tab.expenses;

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    final layout = SkLayout.of(context);
    if (layout == SkLayout.expanded) {
      return Scaffold(
        body: AsyncBody(value: group, onRetry: () => ref.invalidate(groupProvider(widget.groupId)), builder: _desktop),
      );
    }
    return Scaffold(
      floatingActionButton: group.hasValue && layout.showsFab
          ? Semantics(
              label: 'Add expense to ${group.value!.name}',
              child: AddSplitFab(onPressed: () => context.push('/expenses/new?group=${widget.groupId}')),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.brand,
          onRefresh: () async {
            refreshLedger(ref.invalidate);
            await ref.read(groupProvider(widget.groupId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              ContentWidth(
                child: AsyncBody(
                  value: group,
                  onRetry: () => ref.invalidate(groupProvider(widget.groupId)),
                  builder: (g) => _content(g),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(GroupOut g) {
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
        const SizedBox(height: 16),
        _summary(g),
        const SizedBox(height: 16),
        _tabs(),
        const SizedBox(height: 16),
        switch (_tab) {
          _Tab.expenses => _expenses(g),
          _Tab.balances || _Tab.analytics => const SizedBox.shrink(),
          _Tab.members => _MembersTab(group: g),
        },
      ],
    );
  }

  /// GroupDesktop: breadcrumb header, section tabs, the expense table and your balances.
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
          _tabs(balancesLabel: 'Settlements'),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _tab == _Tab.members
                      ? SingleChildScrollView(child: _MembersTab(group: g))
                      : SkCard(padding: EdgeInsets.zero, child: _expenseTable(g)),
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
    final feed = ref.watch(feedProvider((groupId: g.id, deleted: false)));
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
          : ActivityTable(items: items, onHome: false),
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
        final others = b.people.where((p) => p.user.id != me.id).toList();
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
                      'You owe ${money(b.youOweMinor, g.currency)} · You are owed ${money(b.youAreOwedMinor, g.currency)}',
                      style: SkText.body(13, 400, color: ink),
                    ),
                  ],
                ),
              ),
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListCard(
                title: 'Your balances',
                children: [
                  for (final (n, p) in others.indexed)
                    FriendBalanceRow(
                      person: SkPerson(id: p.user.id, name: firstName(p.user.name)),
                      state: personRowState(p.netMinor, g.currency),
                      tone: toneFor(p.netMinor),
                      showDivider: n < others.length - 1,
                      onTap: p.netMinor == 0 ? null : () => _settleWith(g, b, p),
                      trailing: p.netMinor < 0
                          ? SkButton(
                              'Settle',
                              variant: SkButtonVariant.strong,
                              size: SkButtonSize.small,
                              onPressed: () => _settleWith(g, b, p),
                            )
                          : null,
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  void _settleWith(GroupOut g, GroupBalancesOut b, PersonBalance p) {
    final me = ref.read(meProvider);
    final meBrief = UserBrief(id: me.id, name: me.name, avatarUrl: me.avatarUrl);
    showGroupPaymentSheet(
      context,
      GroupPaymentTarget(
        group: g,
        members: b.people,
        from: p.netMinor < 0 ? meBrief : p.user,
        to: p.netMinor < 0 ? p.user : meBrief,
        balanceMinor: p.netMinor.abs(),
      ),
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
          Text(value, style: SkText.display(20, weight, color: color)),
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
            builder: (b) => Row(
              children: [
                figure('You owe', money(b.youOweMinor, g.currency), SkColors.owe),
                const SizedBox(width: 8),
                figure('You are owed', money(b.youAreOwedMinor, g.currency), SkColors.owed),
                const SizedBox(width: 8),
                figure(
                  'Net',
                  formatMinor(b.netMinor, currency: g.currency, signed: true),
                  textColorFor(b.netMinor),
                  weight: 800,
                ),
              ],
            ),
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
                  onPressed: () => context.go('/groups/${g.id}/balances'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Start with the person you owe most; otherwise the person who owes you most.
  void _settleUp(GroupOut g, GroupBalancesOut b) {
    final owe = [...b.people.where((p) => p.netMinor < 0)]..sort((a, c) => a.netMinor.compareTo(c.netMinor));
    final owed = [...b.people.where((p) => p.netMinor > 0)]..sort((a, c) => c.netMinor.compareTo(a.netMinor));
    if (owe.isEmpty && owed.isEmpty) {
      showMessage(context, "You're all square in ${g.name}");
      return;
    }
    _settleWith(g, b, owe.isNotEmpty ? owe.first : owed.first);
  }

  Widget _tabs({String balancesLabel = 'Balances'}) {
    Widget tab(_Tab t, String label) {
      final on = _tab == t;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: () => switch (t) {
            _Tab.balances => context.go('/groups/${widget.groupId}/balances'),
            _Tab.analytics => context.go('/groups/${widget.groupId}/analytics'),
            _ => setState(() => _tab = t),
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: on ? SkColors.brand : Colors.transparent, width: 2.5)),
            ),
            alignment: Alignment.center,
            child: Text(label, style: SkText.body(14, on ? 700 : 600, color: on ? SkColors.brandInk : SkColors.ink2)),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SkColors.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            tab(_Tab.expenses, 'Expenses'),
            const SizedBox(width: 4),
            tab(_Tab.balances, balancesLabel),
            const SizedBox(width: 4),
            tab(_Tab.analytics, 'Analytics'),
            const SizedBox(width: 4),
            tab(_Tab.members, 'Members'),
          ],
        ),
      ),
    );
  }

  Widget _expenses(GroupOut g) {
    final feed = ref.watch(feedProvider((groupId: g.id, deleted: false)));
    return AsyncBody(
      value: feed,
      onRetry: () => ref.invalidate(feedProvider),
      builder: (items) => items.isEmpty
          ? EmptyState(
              title: 'No expenses yet',
              body: "Add the first one and we'll keep the balances.",
              actionLabel: 'Add split',
              onAction: () => context.push('/expenses/new?group=${g.id}'),
            )
          : FeedList(items: items, onHome: false, byDay: false),
    );
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
        setState(() => _tab = _Tab.members);
      case 'deleted':
        context.go('/groups/${g.id}/deleted');
      case 'archive':
        await ref.read(apiProvider).groups.updateGroup(g.id, GroupUpdate(archived: g.archivedAt == null));
        refreshLedger(ref.invalidate);
        if (mounted) {
          showMessage(context, g.archivedAt == null ? '${g.name} archived' : '${g.name} is back');
          if (g.archivedAt == null) context.go('/groups');
        }
    }
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.group});
  final GroupOut group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in group.members) ...[
          UserCard(
            person: personOf(m.user),
            subtitle: [
              if (m.user.id == me.id) 'You',
              if (m.role == 'owner') 'Owner',
              if (m.user.isPlaceholder == true) 'No account yet',
              if (m.placeholderName != null && m.user.isPlaceholder != true) 'Was “${m.placeholderName}”',
            ].join(' · ').ifEmpty('Member'),
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
  final added = await showAppBottomSheet<bool>(
    context,
    title: 'Add someone',
    child: _AddMemberForm(groupId: group.id),
  );
  if (added == true && context.mounted) showMessage(context, 'Added to ${group.name}');
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _AddMemberForm extends ConsumerStatefulWidget {
  const _AddMemberForm({required this.groupId});
  final String groupId;

  @override
  ConsumerState<_AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends ConsumerState<_AddMemberForm> {
  final _text = TextEditingController();
  bool _byEmail = true;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _text.text.trim();
    if (value.isEmpty) {
      setState(() => _error = _byEmail ? 'Enter their email' : 'Enter their name');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .groups
          .addMember(widget.groupId, _byEmail ? AddMemberIn(email: value) : AddMemberIn(name: value));
      refreshLedger(ref.invalidate);
      if (mounted) Navigator.of(context).pop(true);
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
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            _byEmail
                ? 'They see the group next time they open Splitkit.'
                : 'They can be part of splits now and link an account later.',
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
          const SizedBox(height: 18),
          SkButton(
            _busy ? 'Adding…' : 'Add to group',
            onPressed: _busy ? null : _submit,
            size: SkButtonSize.large,
            expand: true,
          ),
        ],
      ),
    );
  }
}
