import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/categorise/category_guesser.dart';
import 'package:splitkit/core/local/ledger.dart';

/// Ansh's synced data (the seed), plus [extra] personal entries.
Ledger _ledger([List<Map<String, dynamic>> extra = const []]) {
  final fixture = jsonDecode(File('test/fixtures/sync/ansh.json').readAsStringSync()) as Map<String, dynamic>;
  final entities = [
    for (final s in (fixture['snapshots'] as Map).entries)
      for (final e in ((s.value as Map)['entities'] as List).cast<Map<String, dynamic>>())
        LocalEntity(s.key, e['entity'], e['entity_id'], e['version'], (e['data'] as Map).cast()),
  ];
  final me = entities.firstWhere((e) => e.entity == 'profile').entityId;
  return Ledger([
    ...entities,
    for (final (i, t) in extra.indexed)
      LocalEntity('user:$me', 'personal_transaction', 'extra-$i', 1, {
        'id': 'extra-$i',
        'user_id': me,
        'type': 'expense',
        'amount_minor': 100,
        'currency': 'INR',
        'date': '2026-09-24',
        'created_at': '2026-09-24T10:00:00Z',
        'deleted_at': null,
        ...t,
      }),
  ], today: DateTime(2026, 9, 25));
}

String _id(Ledger l, String key) => l.categories().firstWhere((c) => c['key'] == key && c['owner_id'] == null)['id'];

void main() {
  group('keywords', () {
    test("ISS-001's typos", () {
      expect(keywordCategory('grocries from mart'), 'food');
      expect(keywordCategory('ubar ride'), 'transport');
      expect(keywordCategory('zomatoo dinner'), 'food');
      // Each typo alone, without a keyword next to it.
      expect([for (final w in ['grocries', 'zomatoo', 'netflx', 'swigy', 'petrl']) keywordCategory(w)], [
        'food',
        'food',
        'entertainment',
        'food',
        'transport',
      ]);
    });

    test('short words only match exactly', () {
      expect(keywordCategory('bar'), 'food');
      expect(keywordCategory('car'), isNull); // not "bar"
      expect(keywordCategory('ola cab'), 'transport');
      expect(keywordCategory('oil'), isNull); // not "ola"
      expect(keywordCategory('pubg'), isNull);
    });

    test('a real 4-letter word is not taken for a typo of a keyword', () {
      for (final word in ['rice', 'cart', 'rest', 'full', 'care']) {
        expect(keywordCategory(word), isNull, reason: word);
      }
      expect(keywordCategory('price'), isNull);
      expect(keywordCategory('later'), isNull);
    });

    test('the first keyword wins, two-word keywords too', () {
      expect(keywordCategory('Tata Power bill'), 'bills');
      expect(keywordCategory('Namma Yatri to office'), 'transport');
      expect(keywordCategory('UPI-SWIGGY*INSTAMART-BLR'), 'food');
      expect(keywordCategory('Books'), isNull);
    });

    test('bank SMS merchants are matched exactly', () {
      expect(keywordCategory('zomatoo', fuzzy: false), isNull);
      expect(keywordCategory('AMAZON PAY INDIA', fuzzy: false), 'shopping');
    });
  });

  group('categoryFor', () {
    test('what you chose before for the same words or merchant comes first', () {
      final l = _ledger([
        {'description': 'Swiggy', 'category_id': _id(_ledger(), 'shopping'), 'reviewed': true},
      ]);
      expect(categoryFor(l, 'Swiggy', scope: 'personal'), _id(l, 'shopping'));
      expect(categoryFor(l, 'Swiggy', scope: 'personal', learn: false), _id(l, 'food'));
      // The seed's Blue Tokai coffee (food) came from an SMS with this merchant.
      expect(categoryFor(l, 'Coffee beans', scope: 'personal', merchant: 'blue tokai coffee'), _id(l, 'food'));
    });

    test("an SMS entry you haven't looked at teaches nothing", () {
      final l = _ledger([
        {'description': 'Zeta', 'category_id': _id(_ledger(), 'shopping'), 'source': 'sms', 'reviewed': false},
      ]);
      expect(categoryFor(l, 'Zeta', scope: 'personal'), isNull);
    });

    test('only categories offered where it goes', () {
      final l = _ledger();
      expect(categoryFor(l, 'Flight to Goa', scope: 'group'), _id(l, 'travel'));
      expect(categoryFor(l, 'Flight to Goa', scope: 'personal'), _id(l, 'transport')); // no Travel there
      expect(categoryFor(l, 'Pharmacy', scope: 'personal'), _id(l, 'health'));
      expect(categoryFor(l, 'Pharmacy', scope: 'group'), isNull); // Health is personal only
    });

    test('income gets an income category, spending never does', () {
      final l = _ledger();
      expect(categoryFor(l, 'ACME CORP', scope: 'personal', income: true), _id(l, 'income'));
      expect(categoryFor(l, 'Interest on loan', scope: 'personal'), isNull);
    });
  });
}
