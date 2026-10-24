import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/local/balance_engine.dart';

/// The same language-neutral vectors the Python engine and planner pass.
void main() {
  final vectors = jsonDecode(File('../shared/balance_vectors.json').readAsStringSync()) as Map;

  Map<String, int> sorted(Map<String, int> m) => {for (final k in m.keys.toList()..sort()) k: m[k]!};

  group('balances', () {
    for (final c in (vectors['cases'] as List).cast<Map>()) {
      test(c['name'], () {
        final flows = [
          for (final e in (c['expenses'] as List).cast<Map>())
            ...expenseFlows(e['payer'], [for (final s in e['shares'] as List) (s[0] as String, s[1] as int)]),
          for (final s in (c['settlements'] as List).cast<Map>()) settlementFlow(s['from'], s['to'], s['amount']),
        ];
        final pos = positions(flows);
        expect(sorted(pairwise(c['me'], flows)), Map<String, int>.from(c['pairwise']));
        expect(sorted(planned(c['me'], flows)), Map<String, int>.from(c['planned']));
        expect(sorted(pos), Map<String, int>.from(c['positions']));
        expect(
          [for (final f in simplify({for (final e in pos.entries) if (e.value != 0) e.key: e.value})) [f.debtor, f.creditor, f.amount]],
          c['simplified'],
        );
      });
    }
  });

  group('settle up', () {
    for (final c in (vectors['settle_up'] as List).cast<Map>()) {
      test(c['name'], () {
        final balances = [for (final b in c['balances'] as List) GroupBalance(b[0], b[1])];
        if (c.containsKey('error')) {
          expect(
            () => planSettleUp(balances, c['amount_minor']),
            throwsA(isA<SettleUpException>().having((e) => e.message, 'message', c['error'])),
          );
        } else {
          expect(
            [for (final p in planSettleUp(balances, c['amount_minor'])) [p.groupId, p.friendPays, p.amountMinor]],
            c['plan'],
          );
        }
      });
    }
  });
}
