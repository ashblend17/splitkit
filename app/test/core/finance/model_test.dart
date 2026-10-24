import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';
import 'package:app/core/local/personal_index.dart';

import 'finance_helpers.dart';

void main() {
  test('wire names round-trip, and unknown ones read as null', () {
    for (final t in AccountType.values) {
      expect(accountTypeFromWire(t.wire), t);
    }
    for (final t in TxnType.values) {
      expect(txnTypeFromWire(t.wire), t);
    }
    expect(
      [for (final t in AccountType.values) t.wire],
      ['cash', 'bank', 'credit_card', 'loan', 'investment', 'other_asset'],
    );
    expect(
      [for (final t in TxnType.values) t.wire],
      ['income', 'expense', 'transfer', 'refund', 'investment_contribution', 'investment_withdrawal', 'adjustment'],
    );
    expect(accountTypeFromWire('crypto'), isNull);
    expect(txnTypeFromWire('gift'), isNull);
    expect(txnTypeFromWire(null), isNull);
    expect(flowFromWire('in'), MoneyFlow.inflow);
    expect(flowFromWire('sideways'), isNull);
    expect(
      [
        for (final t in AccountType.values)
          if (t.isLiability) t,
      ],
      [AccountType.creditCard, AccountType.loan],
    );
  });

  test('the direction each type implies (ledger_rules.IMPLIED_DIRECTION)', () {
    expect(
      {for (final t in TxnType.values) t.wire: impliedFlow(t)?.wire},
      {
        'income': 'in',
        'expense': 'out',
        'transfer': null,
        'refund': 'in',
        'investment_contribution': 'out',
        'investment_withdrawal': 'in',
        'adjustment': null,
      },
    );
  });

  test('FinAccount.read reads a synced account, and skips one of an unknown type', () {
    final a = FinAccount.read({
      'id': 'a1',
      'name': 'HDFC ··4821',
      'type': 'bank',
      'currency': 'INR',
      'opening_balance_minor': 2748000,
      'sms_label': 'HDFC ··4821',
      'status': 'closed',
      'created_at': '2026-09-01T03:30:00+00:00',
      'deleted_at': null,
    })!;
    expect(
      (a.id, a.type, a.openingMinor, a.smsLabel, a.closed, a.deleted),
      ('a1', AccountType.bank, 2748000, 'HDFC ··4821', true, false),
    );
    expect(a.createdMicros, DateTime.parse('2026-09-01T03:30:00+00:00').microsecondsSinceEpoch);
    expect(FinAccount.read({'id': 'x', 'name': 'x', 'type': 'crypto', 'currency': 'INR'}), isNull);
  });

  group('PersonalRow (FinEntry) reads the ledger columns', () {
    Map<String, dynamic> synced(Map<String, dynamic> extra) => {
      'id': 't1',
      'type': 'expense',
      'amount_minor': 500,
      'currency': 'INR',
      'date': '2026-09-15',
      'created_at': '2026-09-15T10:00:00+00:00',
      'sms_at': null,
      'deleted_at': null,
      ...extra,
    };

    test('account, direction, transfer group, refund and holding', () {
      final t = PersonalRow(
        synced({
          'type': 'transfer',
          'direction': 'in',
          'account_id': 'acc',
          'transfer_group_id': 'grp',
          'refund_of_id': null,
          'holding_id': 'h1',
          'source': 'sms',
        }),
      );
      expect(
        (t.txnType, t.flow, t.accountId, t.transferGroupId, t.holdingId),
        (TxnType.transfer, MoneyFlow.inflow, 'acc', 'grp', 'h1'),
      );
      expect(t.fromSms, isTrue);
      final r = PersonalRow(synced({'id': 'r1', 'type': 'refund', 'direction': 'in', 'refund_of_id': 't0'}));
      expect((r.txnType, r.refundOfId, r.fromSms), (TxnType.refund, 't0', false));
    });

    test('a row synced before migration 0013: no direction or account, the flow its type implies', () {
      final spend = PersonalRow(synced({}));
      expect(
        (spend.txnType, spend.flow, spend.accountId, spend.transferGroupId),
        (TxnType.expense, MoneyFlow.outflow, null, null),
      );
      expect(PersonalRow(synced({'id': 'i', 'type': 'income'})).flow, MoneyFlow.inflow);
    });

    test('a type from a later build reads as null, and the row keeps its raw type', () {
      final t = PersonalRow(synced({'type': 'gift', 'direction': 'in'}));
      expect(t.txnType, isNull);
      expect(t.type, 'gift');
      expect(t.flow, MoneyFlow.inflow);
      expect(entry(type: 'gift', noDirection: true).flow, MoneyFlow.outflow);
    });
  });
}
