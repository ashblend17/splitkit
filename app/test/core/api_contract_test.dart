import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';

/// Real responses captured from the seeded API (test/fixtures/api) must parse with the
/// generated client. Catches drift between server output and the OpenAPI spec.
dynamic fixture(String name) => jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());

void main() {
  test('login', () {
    final t = TokenOut.fromJson(fixture('login'))!;
    expect((t.user.name, t.user.role, t.tokenType), ('Ansh C', 'admin', 'bearer'));
  });

  test('groups', () {
    final groups = GroupOut.listFromJson(fixture('groups'));
    final goa = groups.firstWhere((g) => g.name == 'Goa Trip');
    expect((goa.totalSpentMinor, goa.myNetMinor, goa.members.length), (4826000, 115000, 6));
    expect(goa.members.firstWhere((m) => m.placeholderName != null).placeholderName, 'Kabir M.');
  });

  test('overall and group balances', () {
    final overall = OverallBalancesOut.fromJson(fixture('balances'))!;
    expect(overall.totals.single.youOweMinor, 125000);
    final goa = GroupBalancesOut.fromJson(fixture('group_balances'))!;
    expect(goa.people.map((p) => (p.user.name, p.netMinor)).first, ('Kabir Mehta', -75000));
    expect(goa.suggested, isNotEmpty);
  });

  test('feed and expense detail', () {
    final feed = FeedItem.listFromJson(fixture('feed'));
    expect(feed.first.title, 'Dinner at Thalassa');
    expect(feed.first.myNetMinor, -45000);
    final settlement = feed.firstWhere((i) => i.kind == FeedItemKindEnum.settlement);
    expect((settlement.title, settlement.toUser?.name), (null, 'Rahul Sharma'));

    final e = ExpenseOut.fromJson(fixture('expense'))!;
    expect(e.splits.map((s) => s.shareMinor), [45000, 45000, 45000, 45000]);
    expect(e.category?.label, 'Food');
    expect(e.deletedAt, isNull);
  });

  test('split methods and categories drive the UI', () {
    expect(SplitMethodOut.listFromJson(fixture('split_methods')).map((m) => m.key), [
      'equal',
      'exact',
      'percent',
      'shares',
    ]);
    expect(CategoryOut.listFromJson(fixture('categories')).first.label, 'Food');
  });

  test('error bodies surface the human message', () {
    final error = ApiException(422, jsonEncode(fixture('error_split_invalid')));
    expect(apiErrorMessage(error), '₹100 still needs to be allocated');
    expect(apiErrorMessage(ApiException(502, '<html>Bad gateway</html>')), 'Something went wrong. Please try again.');
  });

  test('dates go out as the calendar day, whatever the device time zone', () {
    final s = SettlementIn(
      fromUser: 'a',
      toUser: 'b',
      amountMinor: 50000,
      date: apiDate(DateTime(2026, 9, 24)),
      method: SettlementInMethodEnum.upi,
    );
    expect(s.toJson()['date'], '2026-09-24');
    expect(s.toJson()['method'], SettlementInMethodEnum.upi);
  });

  test('split inputs are sent as decimal strings', () {
    final input = SplitInputIn(userId: 'u1', value: '33.34');
    expect(input.toJson(), {'user_id': 'u1', 'value': '33.34'});
  });
}
