/// The finance maths in one place: [FinanceEngine], over your accounts, personal entries, goals,
/// holdings and allocation rules and plans. Import this file for all of core/finance.
///
/// An engine never changes. Build one per change to the personal entries or accounts; it works
/// out what its answers share (entries in ledger order, transfer partners, balances) the first
/// time one asks, and remembers its answers for the arguments it was last given.
library;

import 'account_links.dart' show labelParts;
import 'allocation.dart';
import 'allocation.dart' as allocation show plansForIncome, reconcilePlans;
import 'balances.dart';
import 'cash_flow.dart';
import 'cash_flow.dart' as flows show cashFlow;
import 'goals.dart';
import 'holdings.dart';
import 'holdings.dart' as values show accountValue;
import 'model.dart';
import 'net_worth.dart';
import 'net_worth.dart' as worth show netWorth;
import 'refunds.dart' as refunds show refundTarget;
import 'transfers.dart';
import 'transfers.dart' as transfers show transferSuggestions;

export 'account_links.dart';
export 'allocation.dart';
export 'balances.dart';
export 'cash_flow.dart';
export 'goals.dart';
export 'holdings.dart';
export 'ids.dart';
export 'model.dart';
export 'net_worth.dart';
export 'refunds.dart';
export 'transfers.dart';

/// Balances, cash flow, net worth, transfer suggestions, refund targets and goals over one set
/// of accounts, entries, goals and contributions, in your [currency].
class FinanceEngine {
  /// [accounts] as synced (deleted ones too) and [entries] as synced (every personal entry,
  /// deleted ones too: they're skipped where they don't count); likewise [goals] and their
  /// [contributions], [holdings], and allocation [rules] and their [plans].
  FinanceEngine({
    required List<FinAccount> accounts,
    required List<FinEntry> entries,
    required this.currency,
    List<FinGoal> goals = const [],
    List<FinContribution> contributions = const [],
    List<FinHolding> holdings = const [],
    List<FinRule> rules = const [],
    List<FinPlan> plans = const [],
  }) : _allAccounts = [...accounts]..sort(_accountOrder),
       _entries = entries,
       _allGoals = [...goals]..sort(FinGoal.order),
       _contributions = contributions,
       _allHoldings = holdings,
       _allRules = [...rules]..sort(FinRule.order),
       _allPlans = plans;

  /// Your currency: cash flow and net worth count only this one.
  final String currency;

  final List<FinAccount> _allAccounts;
  final List<FinEntry> _entries;
  final List<FinGoal> _allGoals;
  final List<FinContribution> _contributions;

  /// Your accounts that aren't deleted (closed ones too), oldest first: the API's order.
  late final List<FinAccount> accounts = List.unmodifiable([
    for (final a in _allAccounts)
      if (!a.deleted) a,
  ]);

  late final Map<String, FinAccount> _byId = {for (final a in _allAccounts) a.id: a};
  late final Map<String, FinAccount> _liveById = {for (final a in accounts) a.id: a};

  /// Account [id], deleted or not (so an old entry can still be named), or null.
  FinAccount? account(String id) => _byId[id];

  /// The account with bank SMS label [label], whatever its state (closed and deleted ones keep
  /// their label), or null. One label, one account, ever.
  FinAccount? accountForLabel(String label) => _byLabel[label];

  late final Map<String, FinAccount> _byLabel = {
    // A live account wins over a deleted one, should there be both.
    for (final a in [..._allAccounts.where((a) => a.deleted), ...accounts])
      if (a.smsLabel case final label?) label: a,
  };

  /// The oldest open cash account, if any: where an ATM withdrawal's cash goes.
  FinAccount? firstActiveCash() {
    for (final a in accounts) {
      if (a.type == AccountType.cash && !a.closed) return a;
    }
    return null;
  }

  /// Live entries of a type this build knows, in ledger order (by day first).
  late final List<FinEntry> _live = [
    for (final e in _entries)
      if (!e.deleted && e.txnType != null) e,
  ]..sort(compareLedgerOrder);

  late final Map<String, FinEntry> _partners = transferPartners(_live);

  /// The balance of every account that isn't deleted, in [accounts]' order.
  late final List<AccountBalance> balances = List.unmodifiable(accountBalances(_allAccounts, _live));

  late final Map<String, AccountBalance> _balanceById = {for (final b in balances) b.account.id: b};

  /// The balance of account [accountId], or null if it's deleted, unknown or part of another
  /// ([wholeOf]: its entries are in that one's balance).
  AccountBalance? balanceOf(String accountId) => _balanceById[accountId];

  /// The account whose balance account [accountId]'s entries count in: the live account it's
  /// linked to ([partOf]), else itself; null if it's deleted or unknown.
  FinAccount? wholeOf(String accountId) => switch (_liveById[accountId]) {
    final a? => partOf(a, _liveById) ?? a,
    null => null,
  };

  /// The live accounts linked to account [accountId], whose entries count in its balance.
  List<FinAccount> linkedTo(String accountId) => _balanceById[accountId]?.linked ?? const [];

  /// A credit card label ("HDFC Credit card ··5678") that a live entry counted in account
  /// [accountId]'s balance carries, if any: the bank's messages say it's a credit card.
  String? creditCardLabelIn(String accountId) => _creditCardLabels[accountId];

  late final Map<String, String> _creditCardLabels = {
    for (final e in _live)
      if (e.accountId case final id? when labelParts(e.account)?.card == 'credit')
        if (wholeOf(id) case final whole?) whole.id: e.account!,
  };

  /// Cash flow over [period] (cashFlow in cash_flow.dart). Remembered by its arguments: [notCounted] by
  /// identity and [label] by equality (a method tear-off of the same object is equal), so pass
  /// the same set and function each time.
  CashFlow cashFlow(
    DayRange period, {
    required Set<String> notCounted,
    required int groupShareMinor,
    required bool countGroupShare,
    required String Function(String? categoryId) label,
  }) {
    final key = (period.start, period.end, notCounted, groupShareMinor, countGroupShare, label);
    if (_cashFlows.remove(key) case final hit?) return _cashFlows[key] = hit;
    final flow = flows.cashFlow(
      entries: _live.getRange(_firstOnOrAfter(period.start), _firstOnOrAfter(period.end + 1)),
      period: period,
      currency: currency,
      notCounted: notCounted,
      accounts: _byId,
      groupShareMinor: groupShareMinor,
      countGroupShare: countGroupShare,
      label: label,
      partners: _partners,
    );
    _cashFlows[key] = flow;
    if (_cashFlows.length > _remembered) _cashFlows.remove(_cashFlows.keys.first);
    return flow;
  }

  /// The last cash flows asked for, the least recent first.
  final _cashFlows = <Object, CashFlow>{};
  static const _remembered = 24;

  /// The index of the first of [_live] on or after [day].
  int _firstOnOrAfter(int day) {
    var lo = 0, hi = _live.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_live[mid].day < day) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Net worth on [today] (a day key), with the Split line ([splitNetMinor]) when [countSplit]:
  /// each account at its value ([accountValues]), or with [holdings] false, at its balance.
  NetWorth netWorth({
    required int splitNetMinor,
    required bool countSplit,
    required int today,
    bool holdings = true,
    int staleDays = defaultStaleDays,
  }) => worth.netWorth(
    balances: balances,
    currency: currency,
    splitNetMinor: splitNetMinor,
    countSplit: countSplit,
    values: holdings ? _valuesOn(today, staleDays).byId : const {},
  );

  // ---- holdings (holdings.dart) ----

  final List<FinHolding> _allHoldings;

  /// Your holdings that aren't deleted, of a type this build knows, oldest first: the API's order.
  late final List<FinHolding> holdings = List.unmodifiable([
    for (final h in [..._allHoldings]..sort(_holdingOrder))
      if (!h.deleted) h,
  ]);

  late final Map<String, FinHolding> _holdingById = {for (final h in _allHoldings) h.id: h};

  /// Holding [id], deleted or not (so an entry can still name it), or null.
  FinHolding? holding(String id) => _holdingById[id];

  /// The live entries naming holding [id], in ledger order ("holding_in_use").
  List<FinEntry> namingHolding(String id) => _naming[id] ?? const [];

  late final Map<String, List<FinEntry>> _naming = () {
    final out = <String, List<FinEntry>>{};
    for (final e in _live) {
      if (e.holdingId case final h?) (out[h] ??= []).add(e);
    }
    return out;
  }();

  /// For each account with live holdings: its own live entries and those naming its holdings,
  /// each once, in ledger order (what [accountValue] reads).
  late final Map<String, List<FinEntry>> _valuedBy = () {
    final owner = <String, String>{for (final h in holdings) h.id: h.accountId};
    final out = <String, List<FinEntry>>{for (final a in owner.values) a: []};
    for (final e in _live) {
      if (out[e.accountId] case final mine?) {
        mine.add(e);
      } else if (out[owner[e.holdingId]] case final theirs?) {
        theirs.add(e);
      }
    }
    return out;
  }();

  /// What each account that isn't deleted is worth on [today] (a day key), in [balances]' order:
  /// an investment account with live holdings by them, every other account its balance
  /// (accountValue in holdings.dart). Remembered for the last two days asked.
  List<AccountValue> accountValues({required int today, int staleDays = defaultStaleDays}) =>
      _valuesOn(today, staleDays).list;

  /// What account [accountId] is worth on [today] ([accountValues]), or null if it's deleted or
  /// unknown.
  AccountValue? accountValue(String accountId, {required int today, int staleDays = defaultStaleDays}) =>
      _valuesOn(today, staleDays).byId[accountId];

  /// The live holdings in account [accountId] on [today], oldest first; none for an account that
  /// isn't an investment account, or is deleted or unknown.
  List<HoldingView> holdingsOf(String accountId, {required int today, int staleDays = defaultStaleDays}) =>
      accountValue(accountId, today: today, staleDays: staleDays)?.holdings ?? const [];

  /// Your investment accounts in your currency on [today], valued and added up.
  Investments investments({required int today, int staleDays = defaultStaleDays}) {
    final on = _valuesOn(today, staleDays);
    return on.investments ??= investmentsOf(on.list, currency: currency);
  }

  _Values _valuesOn(int today, int staleDays) {
    final key = (today, staleDays);
    if (_values[key] case final hit?) return hit;
    final list = List<AccountValue>.unmodifiable([
      for (final b in balances)
        values.accountValue(b, holdings, _valuedBy[b.account.id] ?? const [], today: today, staleDays: staleDays),
    ]);
    final made = _Values(list, {for (final v in list) v.account.id: v});
    // At most two days: today, and yesterday's until every screen has moved on.
    if (_values.length >= 2) _values.remove(_values.keys.first);
    return _values[key] = made;
  }

  final _values = <(int, int), _Values>{};

  /// Spends and incomes that look like one transfer (transferSuggestions in transfers.dart).
  /// Remembered for the last [notCounted] and [dismissed] (by identity) and [window].
  List<TransferSuggestion> transferSuggestions({
    required Set<String> notCounted,
    required Set<String> dismissed,
    Duration window = const Duration(minutes: 30),
  }) {
    if (_suggested case (
      final n,
      final d,
      final w,
      final found,
    ) when identical(n, notCounted) && identical(d, dismissed) && w == window) {
      return found;
    }
    final found = List<TransferSuggestion>.unmodifiable(
      transfers.transferSuggestions(
        _live,
        accounts: _liveById,
        notCounted: notCounted,
        dismissed: dismissed,
        window: window,
      ),
    );
    _suggested = (notCounted, dismissed, window, found);
    return found;
  }

  (Set<String>, Set<String>, Duration, List<TransferSuggestion>)? _suggested;

  /// The spend a refund is for (refundTarget in refunds.dart).
  FinEntry? refundTarget({
    required int amountMinor,
    required int day,
    String? reference,
    String? merchantKey,
    String? accountId,
    int windowDays = 60,
  }) => refunds.refundTarget(
    _live,
    amountMinor: amountMinor,
    day: day,
    reference: reference,
    merchantKey: merchantKey,
    accountId: accountId,
    windowDays: windowDays,
  );

  /// What's left to refund of spend [original] (refundableMinor in refunds.dart).
  int refundableMinor(FinEntry original) {
    final left = original.amount - (_refunded[original.id] ?? 0);
    return left < 0 ? 0 : left;
  }

  /// Live refunds, added up by the spend they're for.
  late final Map<String, int> _refunded = () {
    final out = <String, int>{};
    for (final e in _live) {
      if (e.txnType == TxnType.refund && e.refundOfId != null) {
        out[e.refundOfId!] = (out[e.refundOfId!] ?? 0) + e.amount;
      }
    }
    return out;
  }();

  /// The other leg of transfer leg [entryId], or null. A live leg's partner is the other live leg
  /// of its group; a deleted leg's is the one deleted with it (the same deleted_at).
  FinEntry? partnerLeg(String entryId) {
    final leg = _entryById[entryId];
    final group = leg?.transferGroupId;
    if (leg == null || group == null) return null;
    if (!leg.deleted) return _partners[entryId];
    final deletedAt = leg.raw['deleted_at'];
    for (final e in _groupRows[group] ?? const <FinEntry>[]) {
      if (e.id != entryId && e.deleted && e.raw['deleted_at'] == deletedAt) return e;
    }
    return null;
  }

  /// Every entry in transfer group [groupId], live and deleted, as synced (none for an unknown
  /// group). Shared: callers only read it.
  List<FinEntry> transferLegs(String groupId) => _groupRows[groupId] ?? const [];

  /// Entry [id] as synced, deleted or not, or null.
  FinEntry? entry(String id) => _entryById[id];

  /// Every entry by id (the first synced, should there be two).
  late final Map<String, FinEntry> _entryById = {for (final e in _entries.reversed) e.id: e};

  /// Every entry with a transfer group, live and deleted, by group.
  late final Map<String, List<FinEntry>> _groupRows = () {
    final out = <String, List<FinEntry>>{};
    for (final e in _entries) {
      if (e.transferGroupId case final g?) (out[g] ??= []).add(e);
    }
    return out;
  }();

  // ---- goals (goals.dart) ----

  /// Your goals that aren't deleted, in the API's order (priority, then oldest first).
  late final List<FinGoal> liveGoals = List.unmodifiable([
    for (final g in _allGoals)
      if (!g.deleted) g,
  ]);

  late final Map<String, FinGoal> _goalById = {for (final g in _allGoals) g.id: g};

  /// Goal [id], deleted or not, or null.
  FinGoal? goalById(String id) => _goalById[id];

  /// Each goal's live contributions, newest first (the API's order). One whose entry the device
  /// has as deleted is left out: the server deleted it with its entry. One whose entry hasn't
  /// synced yet still counts.
  late final Map<String, List<FinContribution>> _liveContributions = () {
    final out = <String, List<FinContribution>>{};
    for (final c in _contributions) {
      if (c.deleted || (c.transactionId != null && (_entryById[c.transactionId]?.deleted ?? false))) continue;
      (out[c.goalId] ??= []).add(c);
    }
    for (final list in out.values) {
      list.sort(FinContribution.newestFirst);
    }
    return out;
  }();

  /// Goal [goalId]'s live contributions, newest first (the API's order). Shared: callers only
  /// read it.
  List<FinContribution> contributionsOf(String goalId) => _liveContributions[goalId] ?? const [];

  /// The live contribution entry [entryId] counts toward (an entry counts toward one goal at
  /// most), or null.
  FinContribution? contributionFor(String entryId) => _contributionByEntry[entryId];

  late final Map<String, FinContribution> _contributionByEntry = {
    for (final list in _liveContributions.values)
      for (final c in list)
        if (c.transactionId case final t?) t: c,
  };

  /// Goal [goalId]'s live contributions, newest first, each with its entry and that entry's
  /// account.
  List<ContributionView> contributionViews(String goalId) => [
    for (final c in contributionsOf(goalId))
      if (c.transactionId case final id?)
        ContributionView(
          contribution: c,
          entry: _entryById[id],
          accountName: switch (_entryById[id]) {
            final e? => _byId[e.accountId]?.name ?? e.account,
            null => null,
          },
        )
      else
        ContributionView(contribution: c),
  ];

  /// Every live goal's figures on day key [today], in [liveGoals]' order. [behindGraceDays]:
  /// Features.behindGraceDays. Remembered for the last two days asked.
  List<GoalProgress> goals({required int today, int behindGraceDays = 7}) => _goalsOn(today, behindGraceDays).$1;

  /// Live goal [id]'s figures on day key [today], or null when it's missing or deleted.
  GoalProgress? goal(String id, {required int today, int behindGraceDays = 7}) =>
      _goalsOn(today, behindGraceDays).$2[id];

  (List<GoalProgress>, Map<String, GoalProgress>) _goalsOn(int today, int grace) {
    final key = (today, grace);
    if (_goalDays[key] case final hit?) return hit;
    final list = List<GoalProgress>.unmodifiable([for (final g in liveGoals) _progress(g, today, grace)]);
    final found = (list, {for (final p in list) p.goal.id: p});
    if (_goalDays.length >= 2) _goalDays.remove(_goalDays.keys.first);
    return _goalDays[key] = found;
  }

  final _goalDays = <(int, int), (List<GoalProgress>, Map<String, GoalProgress>)>{};

  GoalProgress _progress(FinGoal g, int today, int grace) {
    final contributions = contributionsOf(g.id);
    var contributed = 0;
    for (final c in contributions) {
      contributed += c.amountMinor;
    }
    final account = g.linkedAccountId == null ? null : _liveById[g.linkedAccountId];
    return goalProgress(
      g,
      today: today,
      contributedMinor: contributed,
      contributionCount: contributions.length,
      // An investment account with holdings is worth what they are (holdings.dart accountValue).
      accountValueMinor: account == null ? null : accountValue(account.id, today: today)?.valueMinor,
      accountIsLiability: account?.type.isLiability ?? false,
      behindGraceDays: grace,
    );
  }

  /// The live goals that aren't archived and follow an account, by the account, oldest first.
  late final Map<String, List<FinGoal>> _followers = () {
    final out = <String, List<FinGoal>>{};
    for (final g in [...liveGoals]..sort((a, b) => _accountOrderOf(a.createdMicros, a.id, b.createdMicros, b.id))) {
      if (g.counts && g.linkedAccountId != null) (out[g.linkedAccountId!] ??= []).add(g);
    }
    return out;
  }();

  /// For each account, the goals (live, taking contributions) that a contribution counts toward
  /// through an entry moving it: the entry itself or the other leg of its transfer.
  late final Map<String, List<FinGoal>> _contributedThrough = () {
    final out = <String, List<FinGoal>>{};
    for (final c in _contributionByEntry.values) {
      final goal = _goalById[c.goalId];
      final entry = _entryById[c.transactionId];
      if (goal == null || !goal.takesContributions || entry == null) continue;
      for (final leg in _liveLegsOf(entry)) {
        if (leg.accountId case final a?) (out[a] ??= []).add(goal);
      }
    }
    return out;
  }();

  /// [entry] and, for a transfer leg, its partner: those of them that are live.
  List<FinEntry> _liveLegsOf(FinEntry entry) => [
    if (!entry.deleted) entry,
    if (entry.transferGroupId case final group?)
      for (final e in _groupRows[group] ?? const <FinEntry>[])
        if (e.id != entry.id && !e.deleted) e,
  ];

  /// The live allocation rules, active or not (ISS-079), that send money to goal [goalId] or
  /// account [accountId], as ids, oldest first (allocation_rules.refuse_if_pointed_at names the
  /// first). While there's one, the goal can't be deleted, archived or switched away from
  /// contributions, and the account can't be closed or deleted (rule_points_here).
  List<String> rulesPointingAt({String? goalId, String? accountId}) {
    final key = goalId != null ? 'g:$goalId' : 'a:$accountId';
    return _pointing[key] ?? const [];
  }

  late final Map<String, List<String>> _pointing = () {
    final out = <String, List<String>>{};
    for (final r in _rulesByAge) {
      (out[_destinationKey(r.goalId, r.accountId)] ??= []).add(r.id);
    }
    return out;
  }();

  /// The live allocation rules that take only incomes into account [accountId], as ids, oldest
  /// first (allocation_rules.refuse_if_filtered_on names the first): the account can't be deleted
  /// while there's one, since the filter would match nothing (ISS-080).
  List<String> rulesFilteringOn(String accountId) => [
    for (final r in _rulesByAge)
      if (r.sourceAccountId == accountId) r.id,
  ];

  late final List<FinRule> _rulesByAge = [...liveRules]
    ..sort((a, b) => _accountOrderOf(a.createdMicros, a.id, b.createdMicros, b.id));

  // ---- allocation rules and plans (allocation.dart) ----

  final List<FinRule> _allRules;
  final List<FinPlan> _allPlans;

  /// Your allocation rules that aren't deleted, active or not, in the API's order (priority, then
  /// oldest first).
  late final List<FinRule> liveRules = List.unmodifiable([
    for (final r in _allRules)
      if (!r.deleted) r,
  ]);

  late final Map<String, FinRule> _ruleById = {for (final r in _allRules) r.id: r};
  late final Map<String, FinPlan> _planById = {for (final p in _allPlans) p.id: p};

  /// Rule [id], deleted or not, or null.
  FinRule? ruleById(String id) => _ruleById[id];

  /// Plan [id], deleted or not, or null.
  FinPlan? planById(String id) => _planById[id];

  /// Every plan of income [incomeId] as synced, deleted ones too, in no set order.
  List<FinPlan> rawPlansOf(String incomeId) => _plansByIncome[incomeId] ?? const [];

  late final Map<String, List<FinPlan>> _plansByIncome = () {
    final out = <String, List<FinPlan>>{};
    for (final p in _allPlans) {
      (out[p.sourceTransactionId] ??= []).add(p);
    }
    return out;
  }();

  /// Whether account [id] is live (closed or not).
  bool _accountLive(String id) => _liveById.containsKey(id);

  /// Whether rule [r]'s destination takes new plans: a live goal counting contributions that's
  /// active (a paused or completed one gets none while it is), or a live open account.
  bool ruleDestinationValid(FinRule r) {
    if (r.goalId case final g?) {
      final goal = _goalById[g];
      return goal != null && !goal.deleted && goal.mode == GoalMode.contribution && goal.status == GoalStatus.active;
    }
    final a = r.accountId == null ? null : _liveById[r.accountId];
    return a != null && !a.closed;
  }

  /// The plans [income] would get now ([allocation.plansForIncome]): what an income's create
  /// sends with it.
  List<PlanDraft> plansForIncome(FinEntry income) => allocation.plansForIncome(
    income,
    currency: currency,
    rules: liveRules,
    destinationValid: ruleDestinationValid,
    accountLive: _accountLive,
  );

  /// What a create or an edit of an income from [before] to [after] does to its plans
  /// ([allocation.reconcilePlans]), from the plans and rules this engine has. Give [plans] when
  /// the write has changed the income's plans already (deleted ones too).
  PlanDiff reconcilePlans({required FinEntry? before, required FinEntry? after, List<FinPlan>? plans}) {
    final id = (after ?? before)?.id;
    return allocation.reconcilePlans(
      before: before,
      after: after,
      currency: currency,
      plans: plans ?? (id == null ? const [] : rawPlansOf(id)),
      rules: liveRules,
      ruleById: ruleById,
      destinationValid: ruleDestinationValid,
      accountLive: _accountLive,
    );
  }

  /// Every plan, deleted ones too, with its status, by id ([PlanView]): filled oldest first per
  /// destination.
  Map<String, PlanView> get planViews => _planState.views;

  /// The plans of income [incomeId], cancelled ones too, in the API's order (oldest first).
  List<PlanView> plansOfIncome(String incomeId) => [
    for (final p in [...rawPlansOf(incomeId)]..sort(_planOrder))
      if (planViews[p.id] case final v?) v,
  ];

  /// The plans for goal [goalId] or account [accountId] that aren't cancelled, oldest income
  /// first (the order they fill in); with [outstanding], only those still planned or partial.
  List<PlanView> plansTo({String? goalId, String? accountId, bool outstanding = false}) {
    final all = _viewsTo[_destinationKey(goalId, accountId)] ?? const <PlanView>[];
    return outstanding ? [for (final v in all) if (v.outstanding) v] : all;
  }

  /// What's still to set aside for goal [goalId] or account [accountId]: the remaining amounts of
  /// its outstanding plans, added up.
  int outstandingTo({String? goalId, String? accountId}) {
    var sum = 0;
    for (final v in plansTo(goalId: goalId, accountId: accountId)) {
      sum += v.remainingMinor;
    }
    return sum;
  }

  /// The plans that aren't cancelled, by destination, oldest income first.
  Map<String, List<PlanView>> get _viewsTo => _planState.byDestination;

  /// Every plan's view by id, and those that aren't cancelled by destination: worked out together,
  /// the first time one is asked for.
  late final ({Map<String, PlanView> views, Map<String, List<PlanView>> byDestination}) _planState =
      _buildPlanViews();

  ({Map<String, PlanView> views, Map<String, List<PlanView>> byDestination}) _buildPlanViews() {
    final views = <String, PlanView>{};
    final taking = <String, List<(FinPlan, FinEntry)>>{};
    for (final p in _allPlans) {
      final income = _entryById[p.sourceTransactionId];
      final reason = income == null || income.deleted
          ? CancelReason.incomeDeleted
          : p.deleted || income.txnType != TxnType.income
          ? CancelReason.noLongerApplies
          : null;
      if (reason != null) {
        views[p.id] = PlanView(
          plan: p,
          status: PlanStatus.cancelled,
          filledMinor: 0,
          incomeDay: income?.day ?? 0,
          income: income,
          cancelReason: reason,
        );
      } else {
        (taking[_destinationKey(p.goalId, p.accountId)] ??= []).add((p, income!));
      }
    }
    final byDestination = <String, List<PlanView>>{};
    for (final MapEntry(key: destination, value: plans) in taking.entries) {
      plans.sort((a, b) {
        final d = a.$2.day.compareTo(b.$2.day);
        if (d != 0) return d;
        final at = a.$2.atMicros.compareTo(b.$2.atMicros);
        return at != 0 ? at : _planOrder(a.$1, b.$1);
      });
      final money = destination.startsWith('g:')
          ? _goalFills(destination.substring(2))
          : _transferIns[destination.substring(2)] ?? const <FillMoney>[];
      final filled = fillOldestFirst([
        for (final (p, income) in plans) (incomeDay: income.day, plannedMinor: p.plannedMinor),
      ], money);
      byDestination[destination] = List.unmodifiable([
        for (final (i, (p, income)) in plans.indexed)
          views[p.id] = PlanView(
            plan: p,
            status: statusOf(p.plannedMinor, filled[i]),
            filledMinor: filled[i],
            incomeDay: income.day,
            income: income,
          ),
      ]);
    }
    return (views: Map.unmodifiable(views), byDestination: byDestination);
  }

  /// Goal [goalId]'s live contributions as money reaching it, oldest first.
  List<FillMoney> _goalFills(String goalId) => [
    for (final c in contributionsOf(goalId).reversed) (day: c.day, amountMinor: c.amountMinor),
  ];

  /// For each account, the live transfers into it from another of your accounts, in your
  /// currency, oldest first: what fills an account's plans.
  late final Map<String, List<FillMoney>> _transferIns = () {
    final out = <String, List<FillMoney>>{};
    for (final e in _live) {
      if (e.txnType != TxnType.transfer || e.flow != MoneyFlow.inflow || e.currency != currency) continue;
      final account = e.accountId, partner = _partners[e.id];
      if (account == null || partner == null || partner.accountId == account) continue;
      (out[account] ??= []).add((day: e.day, amountMinor: e.amount));
    }
    return out;
  }();

  /// The plans made from incomes in [period] against what has been set aside for them
  /// ([PlannedVsActual]). Remembered for the last periods asked.
  PlannedVsActual plannedVsActual(DayRange period) {
    final key = (period.start, period.end);
    if (_plannedVsActual.remove(key) case final hit?) return _plannedVsActual[key] = hit;
    final rows = <String, (int, int, int)>{};
    var planned = 0, actual = 0;
    for (final MapEntry(key: destination, value: views) in _viewsTo.entries) {
      for (final v in views) {
        if (!period.contains(v.incomeDay)) continue;
        final (p, a, n) = rows[destination] ?? (0, 0, 0);
        rows[destination] = (p + v.plan.plannedMinor, a + v.filledMinor, n + 1);
        planned += v.plan.plannedMinor;
        actual += v.filledMinor;
      }
    }
    final list = [
      for (final MapEntry(key: destination, value: (p, a, n)) in rows.entries)
        DestinationPlan(
          goalId: destination.startsWith('g:') ? destination.substring(2) : null,
          accountId: destination.startsWith('a:') ? destination.substring(2) : null,
          plannedMinor: p,
          actualMinor: a,
          planCount: n,
        ),
    ]..sort((a, b) {
        final p = b.plannedMinor.compareTo(a.plannedMinor);
        return p != 0 ? p : (a.goalId ?? '~${a.accountId}').compareTo(b.goalId ?? '~${b.accountId}');
      });
    final made = PlannedVsActual(
      period: period,
      plannedMinor: planned,
      actualMinor: actual,
      rows: List.unmodifiable(list),
      hasRules: liveRules.isNotEmpty,
    );
    _plannedVsActual[key] = made;
    if (_plannedVsActual.length > _remembered) _plannedVsActual.remove(_plannedVsActual.keys.first);
    return made;
  }

  final _plannedVsActual = <(int, int), PlannedVsActual>{};

  /// How much your active rules set aside from one income at worst ([AllocationLoad]); with
  /// [draft] (a rule being added or edited: it replaces the rule with its id), as it would be, so
  /// the editor warns as you type.
  AllocationLoad allocationLoad({FinRule? draft}) {
    if (draft == null) return _load;
    return allocationLoadOf([
      for (final r in liveRules)
        if (r.id != draft.id) r,
      draft,
    ], accountLive: _accountLive);
  }

  late final AllocationLoad _load = allocationLoadOf(liveRules, accountLive: _accountLive);

  /// Each live rule with its plan count and warnings, in the API's order: the Rules list.
  late final List<RuleView> ruleViews = List.unmodifiable([
    for (final r in liveRules)
      RuleView(
        rule: r,
        planCount: _livePlanCounts[r.id] ?? 0,
        sourceAccountGone: r.sourceAccountId != null && !_accountLive(r.sourceAccountId!),
        destinationValid: ruleDestinationValid(r),
      ),
  ]);

  late final Map<String, int> _livePlanCounts = () {
    final out = <String, int>{};
    for (final p in _allPlans) {
      if (!p.deleted) out[p.ruleId] = (out[p.ruleId] ?? 0) + 1;
    }
    return out;
  }();

  /// What stands in the way of changing goal [goalId]: the rules that point at it, the accounts
  /// other goals follow, and the accounts other goals' contributions move.
  GoalGuards guards(String goalId) {
    final goal = _goalById[goalId] ?? (throw ArgumentError.value(goalId, 'goalId', 'no such goal'));
    FinGoal? other(List<FinGoal> goals) {
      for (final g in goals) {
        if (g.id != goalId) return g;
      }
      return null;
    }

    return GoalGuards(
      goal: goal,
      rulesPointingHere: rulesPointingAt(goalId: goalId),
      followers: {
        for (final MapEntry(:key, :value) in _followers.entries)
          if (other(value) case final g?) key: g,
      },
      countedThrough: {
        for (final MapEntry(:key, :value) in _contributedThrough.entries)
          if (other(value) case final g?) key: g,
      },
    );
  }

  /// Why the server would refuse a contribution of [amountMinor] to goal [goalId], made with
  /// entry [entryId] (if any), or null when it would take it. [exceptContributionId]: the
  /// contribution being edited, which doesn't stand in its own way. Mirrors contributions.py:
  /// unknown_goal, goal_archived, goal_tracks_balance, goal_is_manual, unknown_transaction,
  /// contribution_too_large, already_contributed and counted_by_balance.
  GoalRefusal? contributionBlocker({
    required String goalId,
    String? entryId,
    int? amountMinor,
    String? exceptContributionId,
  }) {
    final g = _goalById[goalId];
    if (g == null || g.deleted) return (code: 'unknown_goal', message: "That goal isn't available");
    if (g.status == GoalStatus.archived) return (code: 'goal_archived', message: '${g.name} is archived');
    if (g.mode == GoalMode.linkedBalance) {
      return (
        code: 'goal_tracks_balance',
        message: "${g.name} follows an account's balance, so it takes no contributions",
      );
    }
    if (g.mode == GoalMode.manual) {
      return (code: 'goal_is_manual', message: '${g.name} is tracked by hand, so it takes no contributions');
    }
    if (entryId == null) return null;
    final t = _entryById[entryId];
    if (t == null || t.deleted) return (code: 'unknown_transaction', message: "That entry isn't available");
    if (amountMinor != null && amountMinor > t.amount) {
      return (code: 'contribution_too_large', message: "A contribution can't be more than its entry");
    }
    final other = _contributionByEntry[entryId];
    if (other != null && other.id != exceptContributionId) {
      final name = _goalById[other.goalId]?.name ?? 'another goal';
      return (code: 'already_contributed', message: 'That entry already counts toward $name');
    }
    for (final leg in _liveLegsOf(t)) {
      final followed = _followers[leg.accountId]?.first;
      if (followed != null) {
        final account = _byId[leg.accountId]?.name ?? 'an account';
        return (
          code: 'counted_by_balance',
          message: '${followed.name} already counts that entry, through the balance of $account',
        );
      }
    }
    return null;
  }

  /// The accounts a goal can follow: live, open, not owed (no card or loan), not part of another
  /// (its balance is that one's), and not followed by another goal that's live and not archived
  /// ([exceptGoalId] aside, for editing it).
  List<FinAccount> followableAccounts({String? exceptGoalId}) => [
    for (final a in accounts)
      if (!a.closed &&
          !a.type.isLiability &&
          partOf(a, _liveById) == null &&
          (_followers[a.id] ?? const []).every((g) => g.id == exceptGoalId))
        a,
  ];
}

int _accountOrderOf(int aMicros, String aId, int bMicros, String bId) {
  final c = aMicros.compareTo(bMicros);
  return c != 0 ? c : aId.compareTo(bId);
}

/// A plan's or rule's destination as one key: `g:$goalId` or `a:$accountId`.
String _destinationKey(String? goalId, String? accountId) => goalId != null ? 'g:$goalId' : 'a:$accountId';

/// The API's order for plans: created_at, then id (allocation_plans.py list_plans).
int _planOrder(FinPlan a, FinPlan b) => _accountOrderOf(a.createdMicros, a.id, b.createdMicros, b.id);

/// The API's order for accounts: created_at, then id.
int _accountOrder(FinAccount a, FinAccount b) {
  final c = a.createdMicros.compareTo(b.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// The API's order for holdings: created_at, then id (holdings.py list_holdings).
int _holdingOrder(FinHolding a, FinHolding b) {
  final c = a.createdMicros.compareTo(b.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// [FinanceEngine.accountValues] on one day, and what's added up from them.
class _Values {
  _Values(this.list, this.byId);

  final List<AccountValue> list;
  final Map<String, AccountValue> byId;
  Investments? investments;
}
