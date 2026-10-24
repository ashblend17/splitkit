/// Words for the finance revamp's goals and allocation rules (design §2.4, §3.4): state labels,
/// the timeline, what's needed each month, the estimate with returns, what a rule sets aside and
/// how far a plan has got. core/finance only counts; formatting stays here, at the UI boundary.
library;

import 'package:intl/intl.dart';

import '../finance/allocation.dart';
import '../finance/goals.dart';
import '../finance/model.dart';
import '../money/money.dart';

/// A goal's state on its chip.
String goalStateLabel(GoalState s) => switch (s) {
  GoalState.onTrack => 'On track',
  GoalState.behind => 'Behind',
  GoalState.overdue => 'Overdue',
  GoalState.reached => 'Reached',
  GoalState.noDate => 'No date',
  GoalState.paused => 'Paused',
  GoalState.completed => 'Done',
  GoalState.archived => 'Archived',
};

/// How a goal's progress is tracked, as the editor's choices name it.
String goalModeLabel(GoalMode m) => switch (m) {
  GoalMode.contribution => 'Contributions',
  GoalMode.linkedBalance => 'Account balance',
  GoalMode.manual => 'By hand',
};

/// "May 2027" for a day key.
String goalMonthLabel(int day) => DateFormat('MMM y').format(DateTime(day ~/ 10000, day ~/ 100 % 100, day % 100));

/// "₹17,000 of ₹60,000 · 28%": what's saved, the target, and the % shown (never 100 before
/// it's reached).
String goalAmountLine(GoalProgress p) {
  final c = p.goal.currency;
  return '${formatMinor(p.progressMinor, currency: c)} of ${formatMinor(p.goal.targetMinor, currency: c)} · '
      '${p.percentShown}%';
}

/// "112% · ₹7,000 over" for a goal past its target; else null.
String? goalOverLine(GoalProgress p) {
  final over = p.progressMinor - p.goal.targetMinor;
  if (over <= 0) return null;
  return '${p.percentTrue}% · ${formatMinor(over, currency: p.goal.currency)} over';
}

/// "₹4,777.78/month to May 2027", "Overdue by 12 days", "No target date: progress only" or
/// "Target reached": the card's timeline line. Null for a goal that's done or archived.
String? goalTimeline(GoalProgress p) {
  if (p.goal.status == GoalStatus.completed || p.goal.status == GoalStatus.archived) return null;
  if (p.reached) return 'Target reached';
  if (p.overdueDays case final days?) return overdueLabel(days);
  final target = p.goal.targetDay;
  if (target == null) return noDateLabel;
  if (p.requiredMonthlyMinor case final monthly?) {
    return '${formatMinor(monthly, currency: p.goal.currency)}/month to ${goalMonthLabel(target)}';
  }
  return null;
}

const noDateLabel = 'No target date: progress only';

/// "Overdue by 12 days".
String overdueLabel(int days) => 'Overdue by $days ${days == 1 ? 'day' : 'days'}';

/// "9 months left", or "Due this month".
String monthsLeftLabel(int months) => months <= 1 ? 'Due this month' : '$months months left';

/// "Expected ₹7,606 by now", for a goal that's behind.
String? goalExpectedLine(GoalProgress p) => p.behind && p.expectedMinor != null
    ? 'Expected ${formatMinor(p.expectedMinor!, currency: p.goal.currency)} by now'
    : null;

/// A monthly return in basis points as a percentage: 80 is "0.8%", 125 "1.25%".
String returnPercentLabel(int bp) {
  final whole = bp ~/ 100, rest = bp % 100;
  if (rest == 0) return '$whole%';
  return '$whole.${rest.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}%';
}

/// The estimate with returns, in a sentence: "If what's saved earns 0.8% a month, about ₹4,512 a
/// month gets there by May 2027." Or, when returns alone do it, says so.
String? goalEstimateSentence(GoalProgress p) {
  final e = p.estimate;
  final target = p.goal.targetDay;
  if (e == null || target == null) return null;
  final rate = returnPercentLabel(e.monthlyReturnBp);
  final by = goalMonthLabel(target);
  if (e.returnsAlone) return "If what's saved earns $rate a month, returns alone get it there by $by.";
  return "If what's saved earns $rate a month, about "
      '${formatMinor(e.requiredMonthlyMinor, currency: p.goal.currency)} a month gets there by $by.';
}

/// Why a goal that follows an account shows no progress.
String goalIssueLabel(GoalIssue issue) => switch (issue) {
  GoalIssue.accountMissing => "The account it followed is gone. Pick another, or track it another way.",
  GoalIssue.followsLiability => 'It follows a card or a loan, whose balance is what you owe. Pick a savings account.',
};

/// What a rule sets aside, without its name: "10% of each income", "₹5,000 from each income".
String ruleAmountLabel(FinRule r) => r.kind == AllocationKind.percentage
    ? '${returnPercentLabel(r.percentBp ?? 0)} of each income'
    : '${formatMinor(r.amountMinor ?? 0, currency: r.currency)} from each income';

/// "1 plan made", "3 plans made", or "No plans yet".
String planCountLabel(int n) => n == 0 ? 'No plans yet' : '$n ${n == 1 ? 'plan' : 'plans'} made';

/// A plan's state on its chip.
String planStatusLabel(PlanStatus s) => switch (s) {
  PlanStatus.planned => 'Planned',
  PlanStatus.partial => 'Partly saved',
  PlanStatus.fulfilled => 'Saved',
  PlanStatus.cancelled => 'Cancelled',
};

/// Why a plan was cancelled.
String cancelReasonLabel(CancelReason r) => switch (r) {
  CancelReason.incomeDeleted => 'Its income was deleted',
  CancelReason.noLongerApplies => 'The rule no longer applies to this income',
};

/// The over-100% warning ([AllocationLoad.over100]): "Your rules set aside 110% of a salary into
/// HDFC. That's allowed: the app won't change them." [category] and [account] name the filters of
/// the worst case, when it has them; [would] is the editor's version, with the rule being edited.
/// Fixed amounts, in [currency], are said apart.
String overLoadSentence(
  AllocationLoad load, {
  String? category,
  String? account,
  bool would = false,
  String currency = 'INR',
}) {
  final kind = category?.toLowerCase();
  final income = kind == null || kind == 'income' ? 'an income' : '${_article(kind)} $kind';
  final into = account == null ? '' : ' into $account';
  final fixed = load.fixedMinor <= 0
      ? ''
      : ' Fixed amounts add up to ${formatMinor(load.fixedMinor, currency: currency)} more.';
  return 'Your rules ${would ? 'would set' : 'set'} aside ${returnPercentLabel(load.worstBp)} of $income$into.$fixed '
      "That's allowed: the app won't change them.";
}

String _article(String word) => 'aeiou'.contains(word.isEmpty ? 'x' : word[0]) ? 'an' : 'a';
