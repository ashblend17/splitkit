/// What the Goals screens read from the device's data (the finance engine's goals, goals.dart):
/// typed answers, never JSON. Each is worked out again only when a part of the data it reads
/// changes ([localOn]), or the day does ([todayProvider]). With Features.goals off there are no
/// goals: the lists are empty and a goal is not found.
///
/// Writes are FinanceWrites' goal methods (core/local/writes_goals.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../integrations.dart';
import '../local/ledger.dart';
import 'finance.dart';
import 'today.dart';

/// Goals depend on balances (a goal can follow an account), which are personal data, and on your
/// currency.
const _goalData = {LedgerDomain.personal, LedgerDomain.profile};

/// Every live goal's figures today, in the API's order (priority, then oldest first): active,
/// paused, completed and archived alike (screens group them by [GoalProgress.state]).
final goalsProvider = FutureProvider<List<GoalProgress>>((ref) async {
  final features = ref.watch(featuresProvider);
  if (!features.goals) return const [];
  final today = ref.watch(todayProvider);
  return localOn(ref, _goalData, (l) => l.finance.goals(today: today, behindGraceDays: features.behindGraceDays));
});

/// Goal [id]'s figures today. Fails like the API's 404 (LocalNotFound('Goal')) when it's missing
/// or deleted, so AsyncBody shows its not-found state.
final goalProvider = FutureProvider.family<GoalProgress, String>((ref, id) {
  final features = ref.watch(featuresProvider);
  final today = ref.watch(todayProvider);
  return localOn(ref, _goalData, (l) {
    final found = features.goals ? l.finance.goal(id, today: today, behindGraceDays: features.behindGraceDays) : null;
    return found ?? (throw const LocalNotFound('Goal'));
  });
});

/// Goal [goalId]'s live contributions, newest first, each with its entry's description and
/// account. None for a goal that's missing or deleted (as the API lists them).
final goalContributionsProvider = FutureProvider.family<List<ContributionView>, String>((ref, goalId) {
  if (!ref.watch(featuresProvider).goals) return const [];
  return localOn(ref, const {LedgerDomain.personal}, (l) => l.finance.contributionViews(goalId));
});

/// The first 3 active goals, for Overview's card.
final topGoalsProvider = FutureProvider<List<GoalProgress>>((ref) async {
  final goals = await ref.watch(goalsProvider.future);
  return List.unmodifiable(goals.where((g) => g.goal.status == GoalStatus.active).take(3));
});

/// What stands in the way of changing goal [goalId] (archiving, deleting, switching its mode,
/// following an account). Fails like a 404 when there's no such goal.
final goalGuardsProvider = FutureProvider.family<GoalGuards, String>((ref, goalId) {
  return localOn(ref, const {LedgerDomain.personal}, (l) {
    if (l.finance.goalById(goalId) == null) throw const LocalNotFound('Goal');
    return l.finance.guards(goalId);
  });
});

/// The accounts a goal can follow: live, open, not owed, and not followed by another goal. Pass
/// the goal being edited (or null for a new one), so its own account stays on offer.
final followableAccountsProvider = FutureProvider.family<List<FinAccount>, String?>(
  (ref, exceptGoalId) =>
      localOn(ref, const {LedgerDomain.personal}, (l) => l.finance.followableAccounts(exceptGoalId: exceptGoalId)),
);
