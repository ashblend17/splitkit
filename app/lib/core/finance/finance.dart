/// The finance maths in one place: [FinanceEngine], over your accounts, personal entries and
/// goals. Import this file for all of core/finance.
///
/// An engine never changes. Build one per change to the personal entries or accounts; it works
/// out what its answers share (entries in ledger order, transfer partners, balances) the first
/// time one asks, and remembers its answers for the arguments it was last given.
library;

import 'balances.dart';
import 'cash_flow.dart';
import 'cash_flow.dart' as flows show cashFlow;
import 'goals.dart';
import 'model.dart';
import 'net_worth.dart';
import 'net_worth.dart' as worth show netWorth;
import 'refunds.dart' as refunds show refundTarget;
import 'transfers.dart';
import 'transfers.dart' as transfers show transferSuggestions;

export 'balances.dart';
export 'cash_flow.dart';
export 'goals.dart';
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
  /// [contributions].
  FinanceEngine({
    required List<FinAccount> accounts,
    required List<FinEntry> entries,
    required this.currency,
    List<FinGoal> goals = const [],
    List<FinContribution> contributions = const [],
  }) : _allAccounts = [...accounts]..sort(_accountOrder),
       _entries = entries,
       _allGoals = [...goals]..sort(FinGoal.order),
       _contributions = contributions;

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

  /// The balance of account [accountId], or null if it's deleted or unknown.
  AccountBalance? balanceOf(String accountId) => _balanceById[accountId];

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

  /// Net worth from [balances], with the Split line ([splitNetMinor]) when [countSplit].
  NetWorth netWorth({required int splitNetMinor, required bool countSplit}) =>
      worth.netWorth(balances: balances, currency: currency, splitNetMinor: splitNetMinor, countSplit: countSplit);

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
      accountValueMinor: account == null ? null : balanceOf(account.id)?.balanceMinor,
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
  /// account [accountId], as ids. Always none for now: the device doesn't read allocation rules
  /// yet (the rules step fills this in), so only the server refuses with rule_points_here.
  List<String> rulesPointingAt({String? goalId, String? accountId}) => const [];

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

  /// The accounts a goal can follow: live, open, not owed (no card or loan), and not followed by
  /// another goal that's live and not archived ([exceptGoalId] aside, for editing it).
  List<FinAccount> followableAccounts({String? exceptGoalId}) => [
    for (final a in accounts)
      if (!a.closed && !a.type.isLiability && (_followers[a.id] ?? const []).every((g) => g.id == exceptGoalId)) a,
  ];
}

int _accountOrderOf(int aMicros, String aId, int bMicros, String bId) {
  final c = aMicros.compareTo(bMicros);
  return c != 0 ? c : aId.compareTo(bId);
}

/// The API's order for accounts: created_at, then id.
int _accountOrder(FinAccount a, FinAccount b) {
  final c = a.createdMicros.compareTo(b.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}
