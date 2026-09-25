import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../expenses/activity_table.dart';
import '../expenses/feed_list.dart';
import '../settlements/settlement_sheet.dart';
import 'activity_filters.dart';

// Pieces shared by the phone, tablet and desktop Home layouts.

/// "Wednesday, 23 September" over "Hi, Ansh".
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(longDateLabel(DateTime.now()), style: SkText.body(13, 400, color: SkColors.ink2)),
      const SizedBox(height: 2),
      Semantics(header: true, child: Text('Hi, ${firstName(name)}', style: SkText.title)),
    ],
  );
}

/// Settle up with a friend, or say you're square.
void openFriend(BuildContext context, FriendBalance f) => f.netMinor == 0
    ? showMessage(context, 'You and ${firstName(f.user.name)} are all square')
    : showFriendSettleUpSheet(context, f.user);

/// Totals and friends in your main currency (the one on your profile, else the first).
({CurrencyTotals? totals, String currency, List<FriendBalance> friends}) homeBalances(
  UserOut me,
  OverallBalancesOut b,
) {
  final totals = b.totals.where((t) => t.currency == me.currency).firstOrNull ?? b.totals.firstOrNull;
  final currency = totals?.currency ?? me.currency;
  return (totals: totals, currency: currency, friends: b.friends.where((f) => f.currency == currency).toList());
}

/// Group picker sheet for the phone and tablet "All groups" button.
Future<void> pickActivityGroup(BuildContext context, WidgetRef ref, List<GroupOut> groups) async {
  final current = ref.read(activityFiltersProvider).groupId;
  Widget option(String label, String glyph, String? id) => Builder(
    builder: (sheet) => InkWell(
      onTap: () => Navigator.of(sheet).pop(id ?? ''),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            SkIcon(glyph, size: 20, color: SkColors.brandInk),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: SkText.body(15, 600))),
            if (current == id) const SkIcon('check', size: 20, color: SkColors.brand),
          ],
        ),
      ),
    ),
  );
  final picked = await showAppBottomSheet<String>(
    context,
    title: 'Show activity from',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        option('All groups', 'groups', null),
        for (final g in groups) option(g.name, glyphOr(g.icon, 'groups'), g.id),
      ],
    ),
  );
  if (picked != null) {
    ref.read(activityFiltersProvider.notifier).change((f) => f.withGroup(picked == '' ? null : picked));
  }
}

String groupFilterLabel(String? groupId, List<GroupOut>? groups) =>
    groupId == null ? 'All groups' : groups?.where((g) => g.id == groupId).firstOrNull?.name ?? 'Group';

/// Shown when there's no activity at all: make a group first, or add the first expense.
Widget homeEmpty(BuildContext context, List<GroupOut> groups) => groups.isEmpty
    ? EmptyState(
        glyph: 'groups',
        title: 'No groups yet',
        body: 'Make a group for your flat, a trip or a dinner, then add what people paid.',
        actionLabel: 'Create a group',
        onAction: () => context.go('/groups?new=1'),
      )
    : EmptyState(
        title: 'No expenses yet',
        body: "Add the first one and we'll keep the balances.",
        actionLabel: 'Add split',
        onAction: () => context.push('/expenses/new'),
      );

/// A titled white card whose rows are separated by hairlines (Friends, Your balances).
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.title, required this.children, this.titleSize = 17});
  final String title;
  final List<Widget> children;
  final double titleSize;

  @override
  Widget build(BuildContext context) => SkCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: SkColors.line)),
          ),
          child: Semantics(header: true, child: Text(title, style: SkText.display(titleSize, 700))),
        ),
        ...children,
      ],
    ),
  );
}

/// Tablet Home (HomeTablet): balance and friends in a 280px column, activity beside it.
class HomeTabletBody extends ConsumerWidget {
  const HomeTabletBody({super.key, required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final balances = ref.watch(overallBalancesProvider);
    final groups = ref.watch(groupsProvider);
    final groupId = ref.watch(activityFiltersProvider.select((f) => f.groupId));
    final feed = ref.watch(feedProvider((groupId: groupId, deleted: false)));

    return SafeArea(
      left: false,
      bottom: false,
      child: RefreshIndicator(
        color: SkColors.brand,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          children: [
            HomeGreeting(name: me.name),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 280,
                  child: AsyncBody(
                    value: balances,
                    onRetry: () => ref.invalidate(overallBalancesProvider),
                    skeletonRows: 2,
                    builder: (b) {
                      final h = homeBalances(me, b);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BalanceCard(
                            netMinor: h.totals?.netMinor ?? 0,
                            youOweMinor: h.totals?.youOweMinor ?? 0,
                            youAreOwedMinor: h.totals?.youAreOwedMinor ?? 0,
                            currency: h.currency,
                            layout: BalanceCardLayout.stacked,
                          ),
                          if (h.friends.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ListCard(
                              title: 'Friends',
                              titleSize: 16,
                              children: [
                                for (final (n, f) in h.friends.indexed)
                                  FriendBalanceRow(
                                    person: SkPerson(id: f.user.id, name: firstName(f.user.name)),
                                    state: friendChipState(f.netMinor, h.currency),
                                    tone: toneFor(f.netMinor),
                                    dense: true,
                                    showDivider: n < h.friends.length - 1,
                                    onTap: () => openFriend(context, f),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text('Recent activity', style: SkText.display(20, 700)),
                            ),
                          ),
                          SkPillButton(
                            groupFilterLabel(groupId, groups.value),
                            leading: 'filter',
                            onPressed: () => pickActivityGroup(context, ref, groups.value ?? const []),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AsyncBody(
                        value: feed,
                        onRetry: () => ref.invalidate(feedProvider),
                        builder: (items) => items.isEmpty
                            ? homeEmpty(context, groups.value ?? const [])
                            : FeedList(items: items, onHome: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop Home (HomeDesktop): search, three balance tiles, the activity table with its
/// filter toolbar, and friends and groups on the right.
class HomeDesktopBody extends ConsumerWidget {
  const HomeDesktopBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final balances = ref.watch(overallBalancesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: HomeGreeting(name: me.name)),
              const SizedBox(width: 16),
              const SizedBox(width: 320, child: _SearchField()),
            ],
          ),
          const SizedBox(height: 18),
          AsyncBody(
            value: balances,
            onRetry: () => ref.invalidate(overallBalancesProvider),
            skeletonRows: 1,
            builder: (b) => _SummaryTiles(h: homeBalances(me, b)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _ActivityCard()),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: AsyncBody(
                      value: balances,
                      onRetry: () => ref.invalidate(overallBalancesProvider),
                      builder: (b) => _Aside(b: b, h: homeBalances(me, b)),
                    ),
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

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final _text = TextEditingController(text: ref.read(activityFiltersProvider).search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(activityFiltersProvider.notifier).change((f) => f.withSearch(value));
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SkColors.line),
      ),
      child: Row(
        children: [
          const SkIcon('search', size: 18, color: SkColors.ink2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _text,
              onChanged: _changed,
              style: SkText.body(14, 400),
              textInputAction: TextInputAction.search,
              // Explicit "none" borders: the theme's outlined field borders would win otherwise.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search expenses',
                hintStyle: SkText.body(14, 400, color: SkColors.ink3),
              ),
            ),
          ),
          if (_text.text.isNotEmpty)
            HeaderIconButton(
              glyph: 'close',
              label: 'Clear search',
              color: SkColors.ink2,
              onPressed: () {
                _text.clear();
                _changed('');
              },
            ),
        ],
      ),
    );
  }
}

/// "Rahul", "Rahul and Kabir", "Rahul, Kabir and 2 others".
String _names(List<FriendBalance> friends) {
  final names = [for (final f in friends) firstName(f.user.name)];
  return switch (names.length) {
    0 => '',
    1 => names.first,
    2 => '${names[0]} and ${names[1]}',
    3 => '${names[0]}, ${names[1]} and ${names[2]}',
    _ => '${names[0]}, ${names[1]} and ${names.length - 2} others',
  };
}

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.h});
  final ({CurrencyTotals? totals, String currency, List<FriendBalance> friends}) h;

  @override
  Widget build(BuildContext context) {
    final t = h.totals;
    final net = t?.netMinor ?? 0;
    final owe = t?.youOweMinor ?? 0;
    final owed = t?.youAreOwedMinor ?? 0;
    final c = h.currency;
    final oweTo = _names(h.friends.where((f) => f.netMinor < 0).toList());
    final owedBy = _names(h.friends.where((f) => f.netMinor > 0).toList());

    Widget tile(String label, int amount, Color amountColor, {Color? bg, Color? ink, String? note}) => Expanded(
      child: Semantics(
        container: true,
        label: '$label ${money(amount, c)}${note == null ? '' : ', $note'}',
        child: ExcludeSemantics(
          child: SkCard(
            color: bg ?? SkColors.surface,
            borderColor: bg ?? SkColors.line,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SkText.body(13, 600, color: ink ?? SkColors.ink2)),
                const SizedBox(height: 4),
                Text(money(amount, c), style: SkText.display(34, 800, color: amountColor)),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: SkText.body(12, 400, color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: 'Balance summary',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile(BalanceCard.headline(net), net.abs(), textColorFor(net)),
            const SizedBox(width: 12),
            tile(
              'You owe',
              owe,
              SkColors.owe,
              bg: SkColors.oweSoft,
              ink: SkColors.oweInk,
              note: oweTo.isEmpty ? "You don't owe anyone" : 'to $oweTo',
            ),
            const SizedBox(width: 12),
            tile(
              'You are owed',
              owed,
              SkColors.owed,
              bg: SkColors.owedSoft,
              ink: SkColors.owedInk,
              note: owedBy.isEmpty ? 'Nobody owes you' : 'by $owedBy',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(activityFiltersProvider);
    final notifier = ref.read(activityFiltersProvider.notifier);
    final groups = ref.watch(groupsProvider);
    final categories = ref.watch(groupCategoriesProvider);
    final activity = ref.watch(activityProvider(filters.query(DateTime.now())));
    final categoryLabel = filters.category == null
        ? 'Any category'
        : categories.value?.where((c) => c.key == filters.category).firstOrNull?.label ?? 'Category';

    return SkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SkColors.line)),
            ),
            child: Semantics(
              container: true,
              label: 'Filters',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(header: true, child: Text('Recent activity', style: SkText.display(18, 700))),
                  ),
                  _MenuChip<String?>(
                    label: groupFilterLabel(filters.groupId, groups.value),
                    selected: filters.groupId != null,
                    value: filters.groupId,
                    options: [(null, 'All groups'), for (final g in groups.value ?? const <GroupOut>[]) (g.id, g.name)],
                    onPicked: (id) => notifier.change((f) => f.withGroup(id)),
                  ),
                  _MenuChip<String?>(
                    label: categoryLabel,
                    selected: filters.category != null,
                    value: filters.category,
                    options: [
                      (null, 'Any category'),
                      for (final c in categories.value ?? const <CategoryOut>[]) (c.key, c.label),
                    ],
                    onPicked: (key) => notifier.change((f) => f.withCategory(key)),
                  ),
                  _MenuChip<ActivityPeriod>(
                    label: filters.period.label,
                    selected: filters.period != ActivityPeriod.any,
                    value: filters.period,
                    options: [for (final p in ActivityPeriod.values) (p, p.label)],
                    onPicked: (p) => notifier.change((f) => f.withPeriod(p)),
                  ),
                  SkFilterChip(
                    label: 'Unsettled only',
                    selected: filters.unsettled,
                    onTap: () => notifier.change((f) => f.withUnsettled(!f.unsettled)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: activity,
              onRetry: () => ref.invalidate(activityProvider),
              builder: (items) {
                if (items.isNotEmpty) return ActivityTable(items: items, onHome: true);
                final Widget empty = filters.narrowed || filters.search.trim().isNotEmpty
                    ? EmptyState(
                        glyph: 'search',
                        title: 'Nothing matches',
                        body: 'Try another filter or search.',
                        actionLabel: 'Clear filters',
                        onAction: notifier.clear,
                      )
                    : homeEmpty(context, groups.value ?? const []);
                return SingleChildScrollView(padding: const EdgeInsets.all(24), child: empty);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip that opens a menu under itself ("All groups ▾").
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.selected,
    required this.value,
    required this.options,
    required this.onPicked,
  });

  final String label;
  final bool selected;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onPicked;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (chip) => SkFilterChip(
        label: label,
        selected: selected,
        dropdown: true,
        onTap: () async {
          final box = chip.findRenderObject()! as RenderBox;
          final overlay = Overlay.of(chip).context.findRenderObject()! as RenderBox;
          final topLeft = box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay);
          final picked = await showMenu<(T,)>(
            context: chip,
            color: SkColors.surface,
            position: RelativeRect.fromRect(topLeft & const Size(1, 1), Offset.zero & overlay.size),
            items: [
              for (final (v, text) in options)
                PopupMenuItem(
                  value: (v,),
                  height: 40,
                  child: Row(
                    children: [
                      Expanded(child: Text(text, style: SkText.body(14, v == value ? 700 : 500))),
                      if (v == value) const SkIcon('check', size: 18, color: SkColors.brand),
                    ],
                  ),
                ),
            ],
          );
          if (picked != null) onPicked(picked.$1);
        },
      ),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside({required this.b, required this.h});
  final OverallBalancesOut b;
  final ({CurrencyTotals? totals, String currency, List<FriendBalance> friends}) h;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (h.friends.isNotEmpty) ...[
          ListCard(
            title: 'Friends',
            children: [
              for (final (n, f) in h.friends.indexed)
                FriendBalanceRow(
                  person: SkPerson(id: f.user.id, name: firstName(f.user.name)),
                  state: personRowState(f.netMinor, h.currency),
                  tone: toneFor(f.netMinor),
                  showDivider: n < h.friends.length - 1,
                  onTap: () => openFriend(context, f),
                  trailing: f.netMinor < 0
                      ? TextButton(
                          onPressed: () => openFriend(context, f),
                          style: TextButton.styleFrom(
                            foregroundColor: SkColors.brandInk,
                            minimumSize: const Size(44, 44),
                          ),
                          child: Text('Settle', style: SkText.body(13, 700, color: SkColors.brandInk)),
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (b.groups.isNotEmpty)
          SkCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text('Groups', style: SkText.display(17, 700))),
                const SizedBox(height: 4),
                for (final g in b.groups)
                  Semantics(
                    button: true,
                    label: '${g.name}, ${groupNetLabel(g.netMinor)} ${money(g.netMinor.abs(), g.currency)}',
                    child: InkWell(
                      onTap: () => context.go('/groups/${g.groupId}'),
                      child: ExcludeSemantics(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(g.name, style: SkText.body(14, 600), overflow: TextOverflow.ellipsis),
                              ),
                              Text(
                                formatMinor(g.netMinor, currency: g.currency, signed: true),
                                style: SkText.display(14, 700, color: textColorFor(g.netMinor), tracking: 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
