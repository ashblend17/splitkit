import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';

/// shared/ledger_vectors.json: the personal ledger's fixed rules, which the server (ledger_rules.py,
/// migration 0013's backfill; api/tests/api/test_personal_backfill.py) passes too.
void main() {
  final vectors = jsonDecode(File('../shared/ledger_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  List<Map<String, dynamic>> cases(String key) => (vectors[key] as List).cast<Map<String, dynamic>>();

  test('the namespaces are the server\'s', () {
    expect(accountNamespace, vectors['namespace']);
    expect(planNamespace, vectors['plan_namespace']);
    expect(reminderNamespace, vectors['reminder_namespace']);
  });

  group('opening_balance:', () {
    for (final c in cases('opening_balance')) {
      test(c['name'], () {
        final type = accountTypeFromWire(c['account_type'] as String)!;
        final entries = [
          for (final e in (c['entries'] as List).cast<Map<String, dynamic>>())
            FinEntry({
              'id': e['id'],
              'type': e['type'],
              'direction': e['direction'],
              'amount_minor': e['amount_minor'],
              'currency': 'INR',
              'date': e['day'],
              'sms_at': e['at'],
              'created_at': e['created_at'],
              'balance_minor': e['balance_minor'],
              'deleted_at': null,
            }),
        ];
        for (final (i, e) in entries.indexed) {
          expect(e.flow, impliedFlow(e.txnType!), reason: 'entry $i: direction is the one its type implies');
        }
        expect(openingFromFirstReport(entries, type), c['opening_minor']);
        // An account opened that way has no gap at its first report.
        final reported = [...entries.where((e) => e.balance != null)]..sort(compareLedgerOrder);
        if (reported.isEmpty || type.isLiability) return;
        final first = reported.first;
        final upToFirst = [
          for (final e in entries)
            if (compareLedgerOrder(e, first) <= 0) FinEntry({...e.raw, 'account_id': 'a'}),
        ];
        final account = FinAccount(
          id: 'a',
          name: 'a',
          type: type,
          currency: 'INR',
          openingMinor: c['opening_minor'] as int,
        );
        expect(accountBalances([account], upToFirst).single.lastReported!.gapMinor, 0);
      });
    }
  });

  group('account_ids:', () {
    for (final c in cases('account_ids')) {
      test(c['label'], () => expect(smsAccountId(c['user_id'] as String, c['label'] as String), c['id']));
    }
  });

  group('account_types:', () {
    for (final c in cases('account_types')) {
      test(c['label'], () => expect(accountTypeForLabel(c['label'] as String).wire, c['type']));
    }
  });

  group('plan_ids:', () {
    for (final c in cases('plan_ids')) {
      test('${c['transaction_id']} ${c['rule_id']}', () {
        expect(planId(c['transaction_id'] as String, c['rule_id'] as String), c['id']);
      });
    }
  });

  group('reminder_state_ids:', () {
    for (final c in cases('reminder_state_ids')) {
      test(c['dedup_key'], () {
        expect(reminderStateId(c['user_id'] as String, c['dedup_key'] as String), c['id']);
      });
    }
  });
}
