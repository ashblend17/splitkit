/// Allocation worked out on the device (finance revamp Phase 3, design §3.1): which rules apply to
/// an income and what each plans, how an edited income's plans change ([reconcilePlans]), how far
/// each plan has been acted on (filled oldest first: [PlanView]), the over-100% warning
/// ([AllocationLoad]) and planned against actual for a period ([PlannedVsActual]). The server keeps
/// and checks rules and plans (api/app/modules/personal/allocation_rules.py, allocation_plans.py)
/// but never works any of this out.
///
/// Pure Dart. [FinanceEngine] (finance.dart) feeds these the rules, plans, goals, accounts and
/// entries it holds; screens read them through core/finance/allocation_providers.dart.
///
/// A plan is an intention, never money: nothing here moves a goal's progress or a balance.
library;

import 'ids.dart';
import 'model.dart';

/// What a percentage of [incomeMinor] or a fixed amount comes to ([s]): a percentage rounds half
/// away from zero (amounts are positive), a fixed amount is as it is, even over the income. 0
/// makes no plan (the server takes only amounts above zero).
int plannedMinor(PlanSnapshot s, int incomeMinor) => switch (s.kind) {
  AllocationKind.percentage => (incomeMinor * (s.percentBp ?? 0) + 5000) ~/ 10000,
  AllocationKind.fixed => s.amountMinor ?? 0,
};

/// Whether entry [e] can have plans: a live income in your [currency], not linked to Split.
bool incomeEligible(FinEntry e, String currency) =>
    !e.deleted && e.txnType == TxnType.income && !e.linkedToSplit && e.currency == currency;

/// Whether rule [r]'s filters take income [income]: its category (exact id) and account, when
/// set. A filter naming an account that isn't live ([sourceAccountLive] false) takes nothing
/// (ISS-080).
bool ruleMatches(FinRule r, FinEntry income, {bool sourceAccountLive = true}) =>
    (r.sourceCategoryId == null || r.sourceCategoryId == income.categoryId) &&
    (r.sourceAccountId == null || (sourceAccountLive && r.sourceAccountId == income.accountId));

/// Whether rule [r] makes a plan for [income] now: live and active, its filters take the income
/// ([ruleMatches]), its destination still takes money ([destinationValid]: a live goal counting
/// contributions that's active, or a live open account), and it existed when the income was
/// recorded (`sms_at ?? created_at`), so a first read of old bank SMS, or an edit of an old
/// income, never picks up a newer rule.
bool ruleApplies(FinRule r, FinEntry income, {required bool destinationValid, bool sourceAccountLive = true}) =>
    !r.deleted &&
    r.active &&
    r.trigger == 'income_recorded' &&
    destinationValid &&
    ruleMatches(r, income, sourceAccountLive: sourceAccountLive) &&
    income.atMicros >= r.createdMicros;

/// A plan to make: the rule's id-based [id] (planId of the income and the rule), the rule as it is
/// now ([snapshot]) and what it comes to.
final class PlanDraft {
  const PlanDraft({
    required this.id,
    required this.incomeId,
    required this.rule,
    required this.snapshot,
    required this.plannedMinor,
  });

  final String id;
  final String incomeId;
  final FinRule rule;
  final PlanSnapshot snapshot;
  final int plannedMinor;

  String? get goalId => rule.goalId;
  String? get accountId => rule.accountId;

  @override
  String toString() => 'PlanDraft($plannedMinor → ${goalId ?? accountId})';
}

/// The plans [income] gets now, one per rule that applies ([ruleApplies]), in [rules]' order
/// (the API's: priority, then oldest first). [rules] are the live ones; [destinationValid] and
/// [accountLive] answer for the rule's destination and source account. None for an income that
/// can't have plans ([incomeEligible]) or a planned amount of 0.
List<PlanDraft> plansForIncome(
  FinEntry income, {
  required String currency,
  required Iterable<FinRule> rules,
  required bool Function(FinRule rule) destinationValid,
  required bool Function(String accountId) accountLive,
}) {
  if (!incomeEligible(income, currency)) return const [];
  return [
    for (final r in rules)
      if (_applies(r, income, destinationValid, accountLive))
        if (plannedMinor(r.snapshot, income.amount) case final planned when planned > 0)
          PlanDraft(
            id: planId(income.id, r.id),
            incomeId: income.id,
            rule: r,
            snapshot: r.snapshot,
            plannedMinor: planned,
          ),
  ];
}

bool _applies(FinRule r, FinEntry income, bool Function(FinRule) destinationValid, bool Function(String) accountLive) =>
    ruleApplies(
      r,
      income,
      destinationValid: destinationValid(r),
      sourceAccountLive: r.sourceAccountId == null || accountLive(r.sourceAccountId!),
    );

/// A plan with what it comes to.
typedef PlanAmount = ({FinPlan plan, int plannedMinor});

/// What an income's create or edit does to its plans ([reconcilePlans]), in the order a
/// `POST /personal/batch` sends it: [deleteBefore] deletes, then the entry, then [update]s,
/// [create]s and [deleteAfter] deletes. [restore]s can't go in a batch (a create with a deleted
/// plan's id gives the deleted row back): each is `POST /personal/allocation-plans/{id}/restore`,
/// then a PUT when its amount changes, queued after the batch.
final class PlanDiff {
  const PlanDiff({
    this.deleteBefore = const [],
    this.update = const [],
    this.create = const [],
    this.restore = const [],
    this.deleteAfter = const [],
  });

  static const none = PlanDiff();

  /// Live plans of an income that's no longer one (deleted, another type, linked to Split): sent
  /// before the entry, since the server refuses changing an income's type while it has live
  /// plans (income_has_plans).
  final List<FinPlan> deleteBefore;

  /// Live plans whose amount changes with the income's, worked out with each plan's own snapshot.
  final List<PlanAmount> update;

  final List<PlanDraft> create;

  /// Deleted plans whose rule applies again.
  final List<PlanAmount> restore;

  /// Live plans whose rule (live) no longer takes the income, or that come to 0 now.
  final List<FinPlan> deleteAfter;

  bool get isEmpty =>
      deleteBefore.isEmpty && update.isEmpty && create.isEmpty && restore.isEmpty && deleteAfter.isEmpty;

  @override
  String toString() =>
      'PlanDiff(deleteBefore: $deleteBefore, update: $update, create: $create, restore: $restore, '
      'deleteAfter: $deleteAfter)';
}

/// What changes for an income's [plans] (every plan of it, deleted ones too) when it goes from
/// [before] (null: it's being made) to [after] (null: it's gone). Worked out only on a create, or
/// when its amount, category, account, type or Split link changes, or it's deleted or restored;
/// otherwise [PlanDiff.none].
///
/// - [after] can't have plans ([incomeEligible]): every live plan is deleted first.
/// - Each live plan whose rule is live and whose filters no longer take the income is deleted;
///   otherwise, when the amount changed, it's worked out again with **its own snapshot**, so a
///   rule change never rewrites old plans (a deleted rule's plans keep theirs too).
/// - Each rule that applies now ([ruleApplies]) with no plan for the income yet gets one, and one
///   whose plan was deleted gets it back ([PlanDiff.restore]), but only when this is a create, or
///   the category, account or type changed, or it couldn't have plans before. An edit of the
///   amount alone never adds plans.
///
/// [rules] are the live rules in the API's order; [ruleById] finds any rule, deleted ones too.
PlanDiff reconcilePlans({
  required FinEntry? before,
  required FinEntry? after,
  required String currency,
  required List<FinPlan> plans,
  required Iterable<FinRule> rules,
  required FinRule? Function(String id) ruleById,
  required bool Function(FinRule rule) destinationValid,
  required bool Function(String accountId) accountLive,
}) {
  if (before != null && after != null && !_plansMayChange(before, after)) return PlanDiff.none;
  final live = [
    for (final p in plans)
      if (!p.deleted) p,
  ]..sort(_planOrder);
  if (after == null || !incomeEligible(after, currency)) return PlanDiff(deleteBefore: live);
  final amountChanged = before == null || before.amount != after.amount;
  final mayAdd =
      before == null ||
      !incomeEligible(before, currency) ||
      before.categoryId != after.categoryId ||
      before.accountId != after.accountId;
  final update = <PlanAmount>[];
  final deleteAfter = <FinPlan>[];
  for (final p in live) {
    final rule = ruleById(p.ruleId);
    if (rule != null &&
        !rule.deleted &&
        !ruleMatches(
          rule,
          after,
          sourceAccountLive: rule.sourceAccountId == null || accountLive(rule.sourceAccountId!),
        )) {
      deleteAfter.add(p);
      continue;
    }
    if (!amountChanged) continue;
    final planned = plannedMinor(p.snapshot, after.amount);
    if (planned <= 0) {
      deleteAfter.add(p);
    } else if (planned != p.plannedMinor) {
      update.add((plan: p, plannedMinor: planned));
    }
  }
  final create = <PlanDraft>[];
  final restore = <PlanAmount>[];
  if (mayAdd) {
    final byRule = {for (final p in plans) p.ruleId: p};
    for (final r in rules) {
      if (!_applies(r, after, destinationValid, accountLive)) continue;
      switch (byRule[r.id]) {
        case null:
          final planned = plannedMinor(r.snapshot, after.amount);
          if (planned > 0) {
            create.add(
              PlanDraft(
                id: planId(after.id, r.id),
                incomeId: after.id,
                rule: r,
                snapshot: r.snapshot,
                plannedMinor: planned,
              ),
            );
          }
        case final p when p.deleted:
          final planned = plannedMinor(p.snapshot, after.amount);
          if (planned > 0) restore.add((plan: p, plannedMinor: planned));
        case _:
      }
    }
  }
  return PlanDiff(update: update, create: create, restore: restore, deleteAfter: deleteAfter);
}

/// What plans read of an income changed between [a] and [b].
bool _plansMayChange(FinEntry a, FinEntry b) =>
    a.amount != b.amount ||
    a.categoryId != b.categoryId ||
    a.accountId != b.accountId ||
    a.type != b.type ||
    a.linkedToSplit != b.linkedToSplit ||
    a.deleted != b.deleted ||
    a.currency != b.currency;

/// The API's order for plans: created_at, then id.
int _planOrder(FinPlan a, FinPlan b) {
  final c = a.createdMicros.compareTo(b.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// How far a plan has been acted on.
enum PlanStatus {
  /// Nothing has reached its destination since its income.
  planned,

  /// Some of it has.
  partial,

  /// All of it has.
  fulfilled,

  /// Its income was deleted, or it no longer applies ([CancelReason]).
  cancelled,
}

/// Why a plan is [PlanStatus.cancelled].
enum CancelReason {
  /// Its income was deleted (or isn't on this device).
  incomeDeleted,

  /// The plan was deleted: its income changed (category, account, type, a Split link) so its
  /// rule no longer applies.
  noLongerApplies,
}

/// A plan with how far it has been acted on. What fills a plan, oldest plan first:
/// - for a goal, its live contributions;
/// - for an account, transfers into it from another of your accounts (in-legs), in your
///   currency. Incomes, refunds and corrections into it don't count: they're new money or fixes,
///   not acting on a plan.
///
/// Money reaching a destination fills the plans whose income came on or before it, oldest
/// income first; what's left over isn't assigned.
final class PlanView {
  const PlanView({
    required this.plan,
    required this.status,
    required this.filledMinor,
    required this.incomeDay,
    this.income,
    this.cancelReason,
  });

  final FinPlan plan;
  final PlanStatus status;

  /// What has reached the destination for it so far (at most [FinPlan.plannedMinor]); 0 when
  /// cancelled.
  final int filledMinor;

  /// Its income's day as a day key (20260901), or 0 when the income isn't on this device.
  final int incomeDay;

  /// Its income as synced (deleted ones too), or null when it isn't on this device.
  final FinEntry? income;

  /// Set when [status] is [PlanStatus.cancelled].
  final CancelReason? cancelReason;

  /// What's still to set aside: 0 once fulfilled or cancelled.
  int get remainingMinor =>
      status == PlanStatus.cancelled || filledMinor >= plan.plannedMinor ? 0 : plan.plannedMinor - filledMinor;

  /// Planned or partial: still to act on.
  bool get outstanding => status == PlanStatus.planned || status == PlanStatus.partial;

  @override
  String toString() => 'PlanView(${plan.plannedMinor}, ${status.name}, filled $filledMinor)';
}

/// One plan as [fillOldestFirst] reads it: its income's day, then what it plans.
typedef FillPlan = ({int incomeDay, int plannedMinor});

/// Money reaching a destination: its day, then what.
typedef FillMoney = ({int day, int amountMinor});

/// What each of [plans] is filled with by [money], oldest plan first: each amount goes to the
/// plans whose income day is on or before its day, in [plans]' order, until it runs out; what's
/// left isn't assigned. [plans] are sorted oldest income first and [money] oldest first. O(P + F).
List<int> fillOldestFirst(List<FillPlan> plans, Iterable<FillMoney> money) {
  final filled = List<int>.filled(plans.length, 0);
  var head = 0, queued = 0;
  for (final m in money) {
    while (queued < plans.length && plans[queued].incomeDay <= m.day) {
      queued++;
    }
    var left = m.amountMinor;
    while (left > 0 && head < queued) {
      final room = plans[head].plannedMinor - filled[head];
      if (room <= 0) {
        head++;
        continue;
      }
      final take = room < left ? room : left;
      filled[head] += take;
      left -= take;
      if (take == room) head++;
    }
  }
  return filled;
}

/// The status a plan of [plannedMinor] filled with [filledMinor] has.
PlanStatus statusOf(int plannedMinor, int filledMinor) => filledMinor <= 0
    ? PlanStatus.planned
    : filledMinor < plannedMinor
    ? PlanStatus.partial
    : PlanStatus.fulfilled;

/// How much your active rules set aside from one income, at worst: for each combination of a
/// source category (none, or one a rule names) and a source account (likewise), the percentages of
/// the active percentage rules whose filters take it, added up. Fixed amounts are added up the
/// same way, apart ([fixedMinor]: the largest such sum). A warning only: rules over 100% are
/// allowed and never changed.
final class AllocationLoad {
  const AllocationLoad({required this.worstBp, required this.fixedMinor, this.categoryId, this.accountId});

  static const none = AllocationLoad(worstBp: 0, fixedMinor: 0);

  /// The largest sum of percentages, in basis points (11000 is 110%).
  final int worstBp;

  /// The income category and account of [worstBp], when it needs one (null: any).
  final String? categoryId, accountId;

  /// The largest sum of fixed amounts from one income.
  final int fixedMinor;

  /// More than all of an income is set aside: the banner shows.
  bool get over100 => worstBp > 10000;

  @override
  bool operator ==(Object other) =>
      other is AllocationLoad &&
      other.worstBp == worstBp &&
      other.fixedMinor == fixedMinor &&
      other.categoryId == categoryId &&
      other.accountId == accountId;

  @override
  int get hashCode => Object.hash(worstBp, fixedMinor, categoryId, accountId);

  @override
  String toString() => 'AllocationLoad($worstBp bp, fixed $fixedMinor, $categoryId, $accountId)';
}

/// [AllocationLoad] of [rules]: those that are live and active count, except one whose source
/// account isn't live ([accountLive]), which takes nothing.
AllocationLoad allocationLoadOf(Iterable<FinRule> rules, {required bool Function(String accountId) accountLive}) {
  final counted = [
    for (final r in rules)
      if (!r.deleted && r.active && (r.sourceAccountId == null || accountLive(r.sourceAccountId!))) r,
  ];
  if (counted.isEmpty) return AllocationLoad.none;
  final categories = <String?>{null, for (final r in counted) r.sourceCategoryId};
  final accounts = <String?>{null, for (final r in counted) r.sourceAccountId};
  var worst = AllocationLoad.none;
  var fixed = 0;
  for (final c in categories) {
    for (final a in accounts) {
      var bp = 0, minor = 0;
      for (final r in counted) {
        if ((r.sourceCategoryId != null && r.sourceCategoryId != c) ||
            (r.sourceAccountId != null && r.sourceAccountId != a)) {
          continue;
        }
        if (r.kind == AllocationKind.percentage) {
          bp += r.percentBp ?? 0;
        } else {
          minor += r.amountMinor ?? 0;
        }
      }
      if (bp > worst.worstBp) worst = AllocationLoad(worstBp: bp, fixedMinor: 0, categoryId: c, accountId: a);
      if (minor > fixed) fixed = minor;
    }
  }
  return AllocationLoad(
    worstBp: worst.worstBp,
    fixedMinor: fixed,
    categoryId: worst.categoryId,
    accountId: worst.accountId,
  );
}

/// One destination's plans in a period ([PlannedVsActual.rows]): what was planned for it and what
/// of that has reached it.
final class DestinationPlan {
  const DestinationPlan({
    this.goalId,
    this.accountId,
    required this.plannedMinor,
    required this.actualMinor,
    required this.planCount,
  });

  /// Exactly one of [goalId] and [accountId].
  final String? goalId, accountId;
  final int plannedMinor;

  /// What of [plannedMinor] has been filled (never more than it).
  final int actualMinor;
  final int planCount;

  @override
  String toString() => 'DestinationPlan(${goalId ?? accountId}: $actualMinor of $plannedMinor)';
}

/// The plans made from incomes in [period] (by the income's day; cancelled ones left out): what
/// was planned against what has been set aside for them, in all and per destination (largest
/// planned first).
final class PlannedVsActual {
  const PlannedVsActual({
    required this.period,
    required this.plannedMinor,
    required this.actualMinor,
    required this.rows,
    required this.hasRules,
  });

  final DayRange period;
  final int plannedMinor;
  final int actualMinor;
  final List<DestinationPlan> rows;

  /// You have a live rule (active or not): with none, Overview offers to set one up.
  final bool hasRules;

  /// No plans in the period.
  bool get isEmpty => rows.isEmpty;

  @override
  String toString() => 'PlannedVsActual($actualMinor of $plannedMinor, ${rows.length} destinations)';
}

/// A rule with what the Rules list shows next to it.
final class RuleView {
  const RuleView({
    required this.rule,
    required this.planCount,
    required this.sourceAccountGone,
    required this.destinationValid,
  });

  final FinRule rule;

  /// The live plans it has made ("N plans made").
  final int planCount;

  /// Its source account filter names an account that's deleted (or isn't on this device): it
  /// takes no income until you change it (ISS-080).
  final bool sourceAccountGone;

  /// Its destination takes money now (a live, active goal counting contributions; a live open
  /// account): a paused or completed goal gets no plans while it is.
  final bool destinationValid;

  @override
  String toString() => 'RuleView($rule, $planCount plans)';
}
