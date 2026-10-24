/// What the Rules screens, the entry sheet, goal detail and Overview read about allocation
/// (core/finance/allocation.dart over Ledger.finance): typed answers, never JSON. Each is worked
/// out again only when your personal data or profile change ([localOn]); plans don't depend on the
/// day. With Features.allocationRules off there are no rules or plans: the lists are empty, the
/// load is [AllocationLoad.none] and a rule is not found.
///
/// Writes are the rule methods in core/local/writes_plans.dart (createRule, updateRule,
/// setRuleActive, deleteRule, restoreRule); plans are made and changed by the income writes
/// themselves. For the editor's live warning, ask the engine directly as you type:
/// `ref.watch(financeEngineProvider).value?.allocationLoad(draft: rule)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../integrations.dart';
import '../local/ledger.dart';
import 'finance.dart';

/// Rules and plans are personal data; the engine also reads your currency.
const _reads = {LedgerDomain.personal, LedgerDomain.profile};

/// Your rules that aren't deleted, active or not, in the API's order (priority, then oldest
/// first), each with the plans it has made ("N plans made"), whether its source account filter
/// names a deleted account (it then takes no income) and whether its destination takes money now.
final allocationRulesProvider = FutureProvider<List<RuleView>>((ref) {
  if (!ref.watch(featuresProvider).allocationRules) return const [];
  return localOn(ref, _reads, (l) => l.finance.ruleViews);
});

/// Live rule [id], for the editor. Fails like the API's 404 (LocalNotFound('Rule')) when it's
/// missing or deleted, so AsyncBody shows its not-found state.
final allocationRuleProvider = FutureProvider.family<FinRule, String>((ref, id) {
  final on = ref.watch(featuresProvider).allocationRules;
  return localOn(ref, _reads, (l) {
    final rule = on ? l.finance.ruleById(id) : null;
    return rule == null || rule.deleted ? throw const LocalNotFound('Rule') : rule;
  });
});

/// How much your active rules set aside from one income at worst: the Rules list's over-100%
/// banner ([AllocationLoad.over100]).
final allocationLoadProvider = FutureProvider<AllocationLoad>((ref) {
  if (!ref.watch(featuresProvider).allocationRules) return AllocationLoad.none;
  return localOn(ref, _reads, (l) => l.finance.allocationLoad());
});

/// The plans made from incomes in the month [month] is in (any day of it gives the month, as
/// cashFlowProvider), against what has been set aside for them: Overview's planned vs actual card.
final plannedVsActualProvider = FutureProvider.family<PlannedVsActual, DateTime>((ref, month) {
  final period = monthRange(month.year, month.month);
  if (!ref.watch(featuresProvider).allocationRules) {
    return PlannedVsActual(period: period, plannedMinor: 0, actualMinor: 0, rows: const [], hasRules: false);
  }
  return localOn(ref, _reads, (l) => l.finance.plannedVsActual(period));
});

/// The plans of income [incomeId], cancelled ones too, oldest first: the entry sheet's "Plans
/// from this income", each with its status.
final incomePlansProvider = FutureProvider.family<List<PlanView>, String>((ref, incomeId) {
  if (!ref.watch(featuresProvider).allocationRules) return const [];
  return localOn(ref, _reads, (l) => l.finance.plansOfIncome(incomeId));
});

/// Goal [goalId]'s plans still to act on (planned or partial), oldest first: goal detail's
/// "Planned, not yet saved". Each [PlanView.remainingMinor] is what "Record" prefills. These
/// amounts never count in the goal's progress.
final goalPlansProvider = FutureProvider.family<List<PlanView>, String>((ref, goalId) {
  if (!ref.watch(featuresProvider).allocationRules) return const [];
  return localOn(ref, _reads, (l) => l.finance.plansTo(goalId: goalId, outstanding: true));
});

/// Account [accountId]'s plans still to act on (planned or partial), oldest first: filled by
/// transfers into it from your other accounts.
final accountPlansProvider = FutureProvider.family<List<PlanView>, String>((ref, accountId) {
  if (!ref.watch(featuresProvider).allocationRules) return const [];
  return localOn(ref, _reads, (l) => l.finance.plansTo(accountId: accountId, outstanding: true));
});
