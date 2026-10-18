/// The finance maths in one place: [FinanceEngine], over your accounts and personal entries.
/// Import this file for all of core/finance.
///
/// An engine never changes. Build one per change to the personal entries or accounts; it works
/// out what its answers share (entries in ledger order, transfer partners, balances) the first
/// time one asks, and remembers its answers for the arguments it was last given.
library;

import 'balances.dart';
import 'cash_flow.dart';
import 'cash_flow.dart' as flows show cashFlow;
import 'model.dart';
import 'net_worth.dart';
import 'net_worth.dart' as worth show netWorth;
import 'refunds.dart' as refunds show refundTarget;
import 'transfers.dart';
import 'transfers.dart' as transfers show transferSuggestions;

export 'balances.dart';
export 'cash_flow.dart';
export 'ids.dart';
export 'model.dart';
export 'net_worth.dart';
export 'refunds.dart';
export 'transfers.dart';

/// Balances, cash flow, net worth, transfer suggestions and refund targets over one set of
/// accounts and entries, in your [currency].
class FinanceEngine {
  /// [accounts] as synced (deleted ones too) and [entries] as synced (every personal entry,
  /// deleted ones too: they're skipped where they don't count).
  FinanceEngine({required List<FinAccount> accounts, required List<FinEntry> entries, required this.currency})
    : _allAccounts = [...accounts]..sort(_accountOrder),
      _entries = entries;

  /// Your currency: cash flow and net worth count only this one.
  final String currency;

  final List<FinAccount> _allAccounts;
  final List<FinEntry> _entries;

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
}

/// The API's order for accounts: created_at, then id.
int _accountOrder(FinAccount a, FinAccount b) {
  final c = a.createdMicros.compareTo(b.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}
