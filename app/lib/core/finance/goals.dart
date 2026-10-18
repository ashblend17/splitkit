/// Goals worked out on the device (finance revamp Phase 2, design §2.1): progress by tracking
/// mode, what's left, the months left and what's needed each month, whether a goal is behind its
/// trajectory or overdue, and an optional estimate with returns. The server keeps and checks
/// goals (api/app/modules/personal/goals.py) but never computes any of this.
///
/// Pure Dart. [FinanceEngine.goals] (finance.dart) feeds [goalProgress] each goal's contributions
/// or account balance; the functions here only do the arithmetic, in minor units.
library;

import 'dart:math' as math;

import 'model.dart';

/// Where a goal stands, for its chip. One state per goal, by precedence: archived, completed,
/// paused, reached, overdue, behind, on track (has a date), no date.
enum GoalState { onTrack, behind, overdue, reached, noDate, paused, completed, archived }

/// Why a goal that follows an account shows no progress.
enum GoalIssue {
  /// The account it follows is missing or deleted.
  accountMissing,

  /// It follows a card or a loan, whose balance is what you owe: not savings.
  followsLiability,
}

/// What's needed each month if the money saved earns [monthlyReturnBp] a month (compounded):
/// always an estimate, and only for a goal that opted in (expected_return_bp) and has a date.
final class ReturnEstimate {
  const ReturnEstimate({required this.monthlyReturnBp, required this.requiredMonthlyMinor, required this.returnsAlone});

  /// The expected monthly return in basis points (80 = 0.8% a month).
  final int monthlyReturnBp;

  /// What to put in each month, rounded up to the paisa; 0 when returns alone get there.
  final int requiredMonthlyMinor;

  /// What's saved already reaches the target by the date on returns alone.
  final bool returnsAlone;
}

/// One goal's figures on one day ([FinanceEngine.goals]).
final class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.progressMinor,
    required this.remainingMinor,
    required this.percentTrue,
    required this.percentShown,
    required this.barFraction,
    required this.reached,
    required this.behind,
    required this.state,
    required this.contributionCount,
    this.monthsLeft,
    this.daysLeft,
    this.requiredMonthlyMinor,
    this.overdueDays,
    this.expectedMinor,
    this.estimate,
    this.issue,
  });

  final FinGoal goal;

  /// What's saved, by the goal's mode: its contributions, the followed account's balance, or the
  /// figure typed in. The true value: it can be over the target, and is never clamped.
  final int progressMinor;

  /// What's left to save: the target less the progress, never below 0.
  final int remainingMinor;

  /// The progress as a whole percentage of the target, rounded down (140 when over); 0 for none.
  final int percentTrue;

  /// The percentage to show: 100 once reached, else at most 99, so a goal never reads "100%"
  /// before it's there.
  final int percentShown;

  /// How full the bar is, from 0 to 1.
  final double barFraction;

  /// The progress is at least the target.
  final bool reached;

  /// Calendar months to the target date, this month and the target's included (1 when it's due
  /// this month or today). Null with no date, or once the date has passed.
  final int? monthsLeft;

  /// Days to the target date (0 when it's today). Null with no date, or once it has passed.
  final int? daysLeft;

  /// What to put in each month to get there: what's left over [monthsLeft], rounded up to the
  /// paisa. Null with no date, once the date has passed, or once reached.
  final int? requiredMonthlyMinor;

  /// Days since the target date, for a goal not reached by then; else null.
  final int? overdueDays;

  /// Where a straight line from the day the goal was made to the target puts the progress today,
  /// when that's worked out (see [behind]); else null.
  final int? expectedMinor;

  /// An active goal with a date, not reached and not overdue, made at least
  /// Features.behindGraceDays ago, whose progress is below [expectedMinor].
  final bool behind;

  /// The estimate with returns, for a goal with expected_return_bp above 0 and [monthsLeft].
  final ReturnEstimate? estimate;

  final GoalState state;

  /// Why a goal that follows an account shows no progress, or null.
  final GoalIssue? issue;

  /// How many live contributions the goal has. They count only in contribution mode; after a
  /// switch to another mode they're kept, and this says how many.
  final int contributionCount;

  @override
  String toString() => 'GoalProgress(${goal.name}: $progressMinor of ${goal.targetMinor}, ${state.name})';
}

/// [goal]'s figures on day key [today].
///
/// [contributedMinor] is what its live contributions add up to (counted in contribution mode);
/// [accountValueMinor] the followed account's balance, null when that account is missing or
/// deleted (counted in linked-balance mode, unless [accountIsLiability]). [behindGraceDays]:
/// how long after it's made a goal can first be behind (Features.behindGraceDays).
GoalProgress goalProgress(
  FinGoal goal, {
  required int today,
  required int contributedMinor,
  required int contributionCount,
  required int? accountValueMinor,
  required bool accountIsLiability,
  int behindGraceDays = 7,
}) {
  final issue = goal.mode != GoalMode.linkedBalance
      ? null
      : accountValueMinor == null
      ? GoalIssue.accountMissing
      : accountIsLiability
      ? GoalIssue.followsLiability
      : null;
  final progress = switch (goal.mode) {
    GoalMode.contribution => contributedMinor,
    GoalMode.manual => goal.manualProgressMinor ?? 0,
    GoalMode.linkedBalance => issue == null ? accountValueMinor! : 0,
  };
  final target = goal.targetMinor;
  final reached = progress >= target;
  final remaining = math.max(0, target - progress);
  final percentTrue = progress <= 0 ? 0 : (target <= 0 ? 100 : progress * 100 ~/ target);
  final bar = target <= 0 ? 1.0 : (progress / target).clamp(0.0, 1.0);

  final targetDay = goal.targetDay;
  final overdue = targetDay != null && targetDay < today && !reached;
  final upcoming = targetDay != null && targetDay >= today;
  final monthsLeft = upcoming ? monthsLeftInclusive(today, targetDay) : null;

  // The trajectory: from the day it was made to the target date, in days.
  int? expected;
  var behind = false;
  if (upcoming && !reached && goal.status == GoalStatus.active) {
    final elapsed = daysBetween(goal.startDay, today);
    final total = daysBetween(goal.startDay, targetDay);
    if (total > 0 && elapsed >= behindGraceDays) {
      expected = target * elapsed ~/ total;
      behind = progress < expected;
    }
  }

  ReturnEstimate? estimate;
  final bp = goal.expectedReturnBp ?? 0;
  if (bp > 0 && monthsLeft != null) {
    final monthly = returnAdjustedMonthly(
      targetMinor: target,
      progressMinor: progress,
      months: monthsLeft,
      monthlyReturnBp: bp,
    )!;
    estimate = ReturnEstimate(monthlyReturnBp: bp, requiredMonthlyMinor: monthly, returnsAlone: monthly == 0);
  }

  final state = switch (goal.status) {
    GoalStatus.archived => GoalState.archived,
    GoalStatus.completed => GoalState.completed,
    GoalStatus.paused => GoalState.paused,
    GoalStatus.active when reached => GoalState.reached,
    GoalStatus.active when overdue => GoalState.overdue,
    GoalStatus.active when behind => GoalState.behind,
    GoalStatus.active when targetDay != null => GoalState.onTrack,
    GoalStatus.active => GoalState.noDate,
  };

  return GoalProgress(
    goal: goal,
    progressMinor: progress,
    remainingMinor: remaining,
    percentTrue: percentTrue,
    percentShown: reached ? 100 : math.min(99, percentTrue),
    barFraction: bar,
    reached: reached,
    monthsLeft: monthsLeft,
    daysLeft: upcoming ? daysBetween(today, targetDay) : null,
    requiredMonthlyMinor: monthsLeft != null && !reached ? _ceilDiv(remaining, monthsLeft) : null,
    overdueDays: overdue ? daysBetween(targetDay, today) : null,
    expectedMinor: expected,
    behind: behind,
    estimate: estimate,
    state: state,
    issue: issue,
    contributionCount: contributionCount,
  );
}

/// Calendar months from [today]'s month to [targetDay]'s, both included: 1 in the target's own
/// month. Less than 1 when the target's month has passed.
int monthsLeftInclusive(int today, int targetDay) {
  final (ty, tm) = (targetDay ~/ 10000, targetDay ~/ 100 % 100);
  final (cy, cm) = (today ~/ 10000, today ~/ 100 % 100);
  return (ty * 12 + tm) - (cy * 12 + cm) + 1;
}

/// What to put in each month for [months] months to reach [targetMinor] from [progressMinor] if
/// money saved earns [monthlyReturnBp] a month, compounded (an annuity due at month end): rounded
/// up to the paisa, 0 when returns alone get there, the plain split with no return. Null for
/// fewer than 1 month.
int? returnAdjustedMonthly({
  required int targetMinor,
  required int progressMinor,
  required int months,
  required int monthlyReturnBp,
}) {
  if (months < 1) return null;
  if (monthlyReturnBp <= 0) return _ceilDiv(math.max(0, targetMinor - progressMinor), months);
  final r = monthlyReturnBp / 10000;
  final growth = math.pow(1 + r, months).toDouble();
  final needed = (targetMinor - progressMinor * growth) * r / (growth - 1);
  if (needed <= 0) return 0;
  // A hair under, so a figure that is whole but for floating-point noise isn't rounded up a paisa.
  return (needed - 1e-6).ceil();
}

int _ceilDiv(int a, int b) => a <= 0 ? 0 : (a + b - 1) ~/ b;

/// Why the server would refuse a goal write, in its words: its error `code` and `message`.
typedef GoalRefusal = ({String code, String message});

/// What stands in the way of changing goal [goal] ([FinanceEngine.guards]).
final class GoalGuards {
  const GoalGuards({
    required this.goal,
    required this.rulesPointingHere,
    required Map<String, FinGoal> followers,
    required Map<String, FinGoal> countedThrough,
  }) : _followers = followers,
       _countedThrough = countedThrough;

  final FinGoal goal;

  /// The ids of the live allocation rules, active or not (ISS-079), that send money to this goal.
  /// While there's one, the goal can't be deleted or archived, or switched away from
  /// contributions (rule_points_here).
  final List<String> rulesPointingHere;

  final Map<String, FinGoal> _followers;
  final Map<String, FinGoal> _countedThrough;

  /// No rule stands in the way of deleting or archiving the goal, or switching its mode.
  bool get canArchiveOrSwitch => rulesPointingHere.isEmpty;

  /// The other goal (live, not archived) that already follows account [accountId]'s balance, or
  /// null: this goal can't follow it too (account_followed).
  FinGoal? followedBy(String accountId) => _followers[accountId];

  /// Following account [accountId] would count money twice: an entry in it (or the other leg of
  /// its transfer) is a contribution to another goal (counted_by_contribution).
  bool countedTwiceIfLinkedTo(String accountId) => _countedThrough.containsKey(accountId);

  /// The goal an entry in account [accountId] already counts toward, if any
  /// ([countedTwiceIfLinkedTo]).
  FinGoal? countedBy(String accountId) => _countedThrough[accountId];
}

/// A contribution with what the history shows next to it: its entry, if it has one, and the
/// account that entry moved.
final class ContributionView {
  const ContributionView({required this.contribution, this.entry, this.accountName});

  final FinContribution contribution;

  /// The entry that moved the money, as synced (null when there's none, or it hasn't synced).
  final FinEntry? entry;

  /// The name of the account [entry] went through, else its bank label, else null.
  final String? accountName;

  /// The entry's description, if it has one.
  String? get entryDescription => entry?.description;
}
