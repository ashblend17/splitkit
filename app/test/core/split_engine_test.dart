import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/splits/split_engine.dart';

void main() {
  final vectors = (jsonDecode(File('../shared/split_vectors.json').readAsStringSync()) as Map)['cases'] as List;

  group('shared vectors', () {
    for (final c in vectors.cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final method = splitRegistry.get(c['method'] as String);
        final total = c['total_minor'] as int;
        final inputs = [
          for (final pair in (c['inputs'] as List).cast<List>())
            SplitInput(pair[0] as String, pair[1] == null ? null : Decimal.parse(pair[1] as String)),
        ];
        final expect_ = c['expect'] as Map<String, dynamic>;

        final v = method.validate(total, inputs);
        expect((v.ok, v.remainingMinor, v.message), (expect_['ok'], expect_['remaining_minor'], expect_['message']));
        if (expect_.containsKey('remaining_percent')) {
          expect(v.remainingPercent, Decimal.parse(expect_['remaining_percent'] as String));
        }
        if (expect_['ok'] == true) {
          final shares = method.allocate(total, inputs);
          expect({for (final s in shares) s.userId: s.shareMinor}, expect_['shares']);
          expect(shares.map((s) => s.userId).toList(), inputs.map((i) => i.userId).toList());
          expect(shares.fold(0, (a, s) => a + s.shareMinor), total);
        } else {
          expect(() => method.allocate(total, inputs), throwsA(isA<SplitValidationException>()));
        }
      });
    }
  });

  test('registry order drives the selector', () {
    expect(splitRegistry.keys, ['equal', 'exact', 'percent', 'shares']);
    expect(splitRegistry.all.map((m) => m.symbol), ['=', '₹', '%', '×']);
    expect(() => splitRegistry.get('itemised'), throwsArgumentError);
  });

  test('programming errors throw', () {
    expect(
      () => splitRegistry.get('equal').validate(100, const [SplitInput('a'), SplitInput('a')]),
      throwsArgumentError,
    );
    expect(() => splitRegistry.get('exact').validate(100, const [SplitInput('a')]), throwsArgumentError);
    expect(
      () => splitRegistry.get('exact').validate(100, [
        SplitInput('a', Decimal.parse('99.5')),
        SplitInput('b', Decimal.parse('0.5')),
      ]),
      throwsArgumentError,
    );
  });

  test('weighted allocations always sum to the total', () {
    for (var seed = 0; seed < 200; seed++) {
      final total = 1 + (seed * 7919) % 9999999;
      final weights = [for (var i = 0; i < 1 + seed % 11; i++) Decimal.fromInt((seed * 31 + i * 17) % 500)];
      if (weights.every((w) => w == Decimal.zero)) weights[0] = Decimal.one;
      final parts = distribute(total, weights);
      expect(parts.fold(0, (a, b) => a + b), total);
    }
  });
}
