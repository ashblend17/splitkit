import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/layout/layout.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../expenses/feed_list.dart';
import 'activity_filters.dart';
import 'home_wide.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      refreshLedger(ref.invalidate);
      await ref.read(overallBalancesProvider.future);
    }

    return switch (SkLayout.of(context)) {
      SkLayout.compact => _PhoneHome(onRefresh: refresh),
      SkLayout.medium => Scaffold(body: HomeTabletBody(onRefresh: refresh)),
      SkLayout.expanded => const Scaffold(body: HomeDesktopBody()),
    };
  }
}

class _PhoneHome extends ConsumerWidget {
  const _PhoneHome({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final balances = ref.watch(overallBalancesProvider);
    final groups = ref.watch(groupsProvider);
    final groupId = ref.watch(activityFiltersProvider.select((f) => f.groupId));
    final feed = ref.watch(feedProvider((groupId: groupId, deleted: false)));

    return Scaffold(
      floatingActionButton: AddSplitFab(
        onPressed: () => context.push(groupId == null ? '/expenses/new' : '/expenses/new?group=$groupId'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.brand,
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, me),
                    const SizedBox(height: 20),
                    AsyncBody(
                      value: balances,
                      onRetry: () => ref.invalidate(overallBalancesProvider),
                      skeletonRows: 1,
                      builder: (b) => _balance(context, me, b),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('Recent activity', style: SkText.section)),
                        ),
                        SkPillButton(
                          groupFilterLabel(groupId, groups.value),
                          leading: 'filter',
                          onPressed: () => pickActivityGroup(context, ref, groups.value ?? const []),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
        ),
      ),
    );
  }

  Widget _header(BuildContext context, UserOut me) => Row(
    children: [
      Expanded(child: HomeGreeting(name: me.name)),
      Semantics(
        button: true,
        label: 'Your profile',
        child: InkWell(
          onTap: () => context.go('/profile'),
          customBorder: const CircleBorder(),
          child: Avatar(SkPerson(id: me.id, name: me.name), size: 44, fontSize: 15),
        ),
      ),
    ],
  );

  Widget _balance(BuildContext context, UserOut me, OverallBalancesOut b) {
    final h = homeBalances(me, b);
    return BalanceCard(
      netMinor: h.totals?.netMinor ?? 0,
      youOweMinor: h.totals?.youOweMinor ?? 0,
      youAreOwedMinor: h.totals?.youAreOwedMinor ?? 0,
      currency: h.currency,
      footer: h.friends.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in h.friends) ...[
                    FriendBalanceChip(
                      person: SkPerson(id: f.user.id, name: firstName(f.user.name), initials: initialsFor(f.user.name)),
                      state: friendChipState(f.netMinor, h.currency),
                      tone: toneFor(f.netMinor),
                      onTap: () => openFriend(context, f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
    );
  }
}
