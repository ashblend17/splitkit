/// Cash flow over a period: what came in, what was spent (net of refunds, with your share of
/// group spending when that's counted), what was invested, and what's left.
///
/// Spending follows the server's summary (personal/service.py summary): an entry counts when it's
/// live, in your currency, and not counted in Split already ([notCounted]: entries linked to a
/// live group expense or payment, and refunds of those). Months follow the date each entry
/// carries, which is local: the profile has no timezone.
library;

import 'model.dart';
import 'transfers.dart';

/// What [e] adds to spending: its amount for a counted expense in [currency], minus its amount
/// for a counted refund, and null for anything else (other types, deleted entries, entries
/// counted in Split, other currencies). Cash flow and Insights both count spending through this.
int? consumptionMinor(FinEntry e, Set<String> notCounted, String currency) {
  final sign = switch (e.txnType) {
    TxnType.expense => 1,
    TxnType.refund => -1,
    _ => 0,
  };
  if (sign == 0 || e.deleted || e.currency != currency || notCounted.contains(e.id)) return null;
  return sign * e.amount;
}

/// Spending in one category over the period, net of refunds.
final class CategoryAmount {
  const CategoryAmount({required this.categoryId, required this.label, required this.amountMinor});

  /// Null for entries with no category.
  final String? categoryId;
  final String label;
  final int amountMinor;
}

/// The money that came in and went out over [period], in one currency.
final class CashFlow {
  const CashFlow({
    required this.period,
    this.incomeMinor = 0,
    this.expensesMinor = 0,
    this.refundsMinor = 0,
    this.groupShareMinor = 0,
    this.investedMinor = 0,
    this.withdrawnMinor = 0,
    this.groupShareCounted = false,
    this.byCategory = const [],
    this.entryCount = 0,
  });

  final DayRange period;

  /// Counted income.
  final int incomeMinor;

  /// Counted spends, before refunds.
  final int expensesMinor;

  /// Counted refunds.
  final int refundsMinor;

  /// Your share of the period's group expenses (in Split), whether counted here or not.
  final int groupShareMinor;

  /// Money put into investments: investment contributions, and transfers from your other
  /// accounts into an investment account.
  final int investedMinor;

  /// Money taken out of them, the same way round.
  final int withdrawnMinor;

  /// Whether [groupShareMinor] counts as spending here.
  final bool groupShareCounted;

  /// Spending by category, net of refunds: zeros left out, largest first, then by label.
  final List<CategoryAmount> byCategory;

  /// The entries that went into any of the totals.
  final int entryCount;

  /// Spends minus refunds: the server summary's spent_minor. Can be less than zero.
  int get spendingMinor => expensesMinor - refundsMinor;

  /// What you spent: [spendingMinor], plus your group share when it's counted.
  int get consumptionMinor => spendingMinor + (groupShareCounted ? groupShareMinor : 0);

  /// What's left of income after spending.
  int get netMinor => incomeMinor - consumptionMinor;

  /// [netMinor] as a share of income, or null with no income.
  double? get savingsRate => incomeMinor == 0 ? null : netMinor / incomeMinor;

  /// [savingsRate] as a whole percent, rounded half away from zero, or null with no income.
  int? get savingsRatePercent {
    if (incomeMinor == 0) return null;
    final n = netMinor * 100, d = incomeMinor;
    final q = (2 * n.abs() + d.abs()) ~/ (2 * d.abs());
    return (n < 0) != (d < 0) ? -q : q;
  }

  /// Nothing to show: no counted entries, and no counted group share.
  bool get isEmpty => entryCount == 0 && (!groupShareCounted || groupShareMinor == 0);
}

/// The cash flow of [entries] (every entry: deleted ones and other periods are skipped) over
/// [period], in [currency]:
/// - income, spends and refunds that are counted (see [consumptionMinor]);
/// - invested and withdrawn: investment entries, and transfer legs on another account whose
///   partner is on an investment account ([accounts], by id);
/// - other transfers (a loan received is one, from a loan account) and balance corrections
///   aren't in it;
/// - your group share ([groupShareMinor]) is spending only when [countGroupShare].
///
/// [label] names a category (null: none). [partners] is [transferPartners] of [entries], when
/// the caller keeps it.
CashFlow cashFlow({
  required Iterable<FinEntry> entries,
  required DayRange period,
  required String currency,
  required Set<String> notCounted,
  required Map<String, FinAccount> accounts,
  required int groupShareMinor,
  required bool countGroupShare,
  required String Function(String? categoryId) label,
  Map<String, FinEntry>? partners,
}) {
  final totals = _Totals(
    currency: currency,
    notCounted: notCounted,
    accounts: accounts,
    partners: partners ?? transferPartners(entries),
  );
  for (final e in entries) {
    if (period.contains(e.day)) totals.add(e);
  }
  return totals.cashFlow(period, groupShareMinor: groupShareMinor, countGroupShare: countGroupShare, label: label);
}

/// [cashFlow] for each month in [yyyymm] (202609 for September 2026), keyed the same way, in one
/// pass over [entries]. [groupShareFor] gives each month's group share.
Map<int, CashFlow> monthlyCashFlow({
  required Iterable<FinEntry> entries,
  required Iterable<int> yyyymm,
  required String currency,
  required Set<String> notCounted,
  required Map<String, FinAccount> accounts,
  required int Function(DayRange period) groupShareFor,
  required bool countGroupShare,
  required String Function(String? categoryId) label,
  Map<String, FinEntry>? partners,
}) {
  final legs = partners ?? transferPartners(entries);
  final months = {
    for (final m in yyyymm) m: _Totals(currency: currency, notCounted: notCounted, accounts: accounts, partners: legs),
  };
  for (final e in entries) {
    months[e.day ~/ 100]?.add(e);
  }
  return {
    for (final MapEntry(key: m, value: totals) in months.entries)
      m: () {
        final period = monthRange(m ~/ 100, m % 100);
        return totals.cashFlow(
          period,
          groupShareMinor: groupShareFor(period),
          countGroupShare: countGroupShare,
          label: label,
        );
      }(),
  };
}

/// Cash flow totals, added up one entry at a time.
class _Totals {
  _Totals({required this.currency, required this.notCounted, required this.accounts, required this.partners});

  final String currency;
  final Set<String> notCounted;
  final Map<String, FinAccount> accounts;

  /// Each live transfer leg's partner, by leg id ([transferPartners]).
  final Map<String, FinEntry> partners;

  int _income = 0, _expenses = 0, _refunds = 0, _invested = 0, _withdrawn = 0, _count = 0;
  final _byCategory = <String?, int>{};

  /// Adds [e] wherever it counts (see [cashFlow]); the caller picks the period.
  void add(FinEntry e) {
    if (e.deleted || e.currency != currency) return;
    switch (e.txnType) {
      case TxnType.income:
        if (notCounted.contains(e.id)) return;
        _income += e.amount;
      case TxnType.expense || TxnType.refund:
        final spent = consumptionMinor(e, notCounted, currency);
        if (spent == null) return;
        if (e.txnType == TxnType.expense) {
          _expenses += e.amount;
        } else {
          _refunds += e.amount;
        }
        _byCategory[e.categoryId] = (_byCategory[e.categoryId] ?? 0) + spent;
      case TxnType.investmentContribution:
        _invested += e.amount;
      case TxnType.investmentWithdrawal:
        _withdrawn += e.amount;
      case TxnType.transfer:
        // Counted once, on the leg outside the investment account.
        final partner = partners[e.id];
        if (partner == null) return;
        if (accounts[partner.accountId]?.type != AccountType.investment) return;
        if (accounts[e.accountId]?.type == AccountType.investment) return;
        if (e.flow == MoneyFlow.outflow) {
          _invested += e.amount;
        } else {
          _withdrawn += e.amount;
        }
      case TxnType.adjustment || null:
        return;
    }
    _count++;
  }

  /// The totals as the cash flow of [period].
  CashFlow cashFlow(
    DayRange period, {
    required int groupShareMinor,
    required bool countGroupShare,
    required String Function(String? categoryId) label,
  }) {
    final byCategory = [
      for (final MapEntry(key: id, value: amount) in _byCategory.entries)
        if (amount != 0) CategoryAmount(categoryId: id, label: label(id), amountMinor: amount),
    ]..sort(_largestFirst);
    return CashFlow(
      period: period,
      incomeMinor: _income,
      expensesMinor: _expenses,
      refundsMinor: _refunds,
      groupShareMinor: groupShareMinor,
      investedMinor: _invested,
      withdrawnMinor: _withdrawn,
      groupShareCounted: countGroupShare,
      byCategory: List.unmodifiable(byCategory),
      entryCount: _count,
    );
  }
}

/// Largest first, then by label (the server's order), then by id so two categories with the
/// same label and amount keep one order.
int _largestFirst(CategoryAmount a, CategoryAmount b) {
  var c = b.amountMinor.compareTo(a.amountMinor);
  if (c != 0) return c;
  c = a.label.compareTo(b.label);
  if (c != 0) return c;
  return (a.categoryId ?? '').compareTo(b.categoryId ?? '');
}
