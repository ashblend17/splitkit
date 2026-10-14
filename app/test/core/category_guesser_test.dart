import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/categorise/category_guesser.dart';
import 'package:splitkit/core/categorise/category_rules.dart';
import 'package:splitkit/core/local/ledger.dart';

/// John's synced data (the seed), plus [extra] personal entries and learned [rules]
/// ((pattern, category key, income, updated_at)).
Ledger _ledger([List<Map<String, dynamic>> extra = const [], List<(String, String, bool, String)> rules = const []]) {
  final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
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
    for (final (pattern, key, income, at) in rules)
      LocalEntity('user:$me', 'category_rule', ruleId(me, income: income, pattern: pattern), null, {
        'id': ruleId(me, income: income, pattern: pattern),
        'user_id': me,
        'pattern': pattern,
        'income': income,
        'category_id': _seedCategory(entities, key),
        'updated_at': at,
      }),
  ], today: DateTime(2026, 9, 25));
}

String _seedCategory(List<LocalEntity> entities, String key) =>
    entities.firstWhere((e) => e.entity == 'category' && e.data['key'] == key && e.data['owner_id'] == null).entityId;

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

    test("a category the app guessed for an SMS teaches nothing, looked at or not", () {
      final l = _ledger([
        {'description': 'Zeta', 'category_id': _id(_ledger(), 'shopping'), 'source': 'sms', 'reviewed': false},
        {'description': 'Theta', 'category_id': _id(_ledger(), 'shopping'), 'source': 'sms', 'reviewed': true},
      ]);
      expect(categoryFor(l, 'Zeta', scope: 'personal'), isNull);
      expect(categoryFor(l, 'Theta', scope: 'personal'), isNull);
    });

    test('a learned rule covers every spelling of its merchant', () {
      final l = _ledger(const [], [('zomato limited', 'shopping', false, '2026-09-20T10:00:00Z')]);
      final shopping = _id(l, 'shopping');
      expect(categoryFor(l, 'Zomato', scope: 'personal', merchant: 'ZOMATO CYBS', fuzzy: false), shopping);
      expect(categoryFor(l, 'Lunch', scope: 'personal', merchant: 'zomato.payu@axisbank'), shopping);
      expect(categoryFor(l, 'Zomato', scope: 'personal'), shopping); // typed by hand
      expect(categoryFor(l, 'Zomato order', scope: 'group'), shopping); // Shopping is in both
      expect(categoryFor(l, 'Zomato', scope: 'personal', learn: false), _id(l, 'food'));
    });

    test('the newest choice wins, and income and spending are learned apart', () {
      final l = _ledger(const [], [
        ('zomato', 'shopping', false, '2026-09-20T10:00:00Z'),
        ('zomato limited', 'entertainment', false, '2026-09-22T10:00:00Z'),
        ('vagish bhardwaj', 'income', true, '2026-09-21T10:00:00Z'),
      ]);
      expect(categoryFor(l, 'Zomato', scope: 'personal', merchant: 'ZOMATO'), _id(l, 'entertainment'));
      expect(categoryFor(l, 'Vagish', scope: 'personal', merchant: 'VAGISH BHARDWAJ', income: true), _id(l, 'income'));
      expect(categoryFor(l, 'Vagish', scope: 'personal', merchant: 'VAGISH BHARDWAJ'), isNull);
    });

    test('a learned category not offered where it goes is passed over', () {
      final l = _ledger(const [], [('apollo pharmacy', 'health', false, '2026-09-20T10:00:00Z')]);
      expect(categoryFor(l, 'Apollo Pharmacy', scope: 'personal'), _id(l, 'health'));
      expect(categoryFor(l, 'Apollo Pharmacy', scope: 'group'), isNull); // Health is personal only
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
