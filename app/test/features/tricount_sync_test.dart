import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/design_system/design_system.dart';

import '../fake_backend.dart';
import '../flutter_test_config.dart';
import '../helpers.dart';

Map<String, dynamic> _member(Map<String, dynamic> group, String name) =>
    ((group['members'] as List).firstWhere((m) => m['user']['name'] == name) as Map)['user'] as Map<String, dynamic>;

Map<String, dynamic> _linked(Map<String, dynamic> group, {String state = 'ok', List<Object> conflicts = const [], List<String> warnings = const []}) => {
  'linked': true,
  'link': {
    'group_id': group['id'],
    'share_link': 'https://tricount.com/tGOA2026',
    'state': state,
    'last_error': state == 'error' ? "Can't reach Tricount right now. Trying again later." : null,
    'warnings': warnings,
    'last_synced_at': fixtureDay.subtract(const Duration(minutes: 4)).toUtc().toIso8601String(),
    'linked_at': '2026-09-24T10:00:00Z',
    'linked_by': _member(group, 'John Doe'),
    'conflicts': conflicts,
  },
};

Map<String, dynamic> _conflict(Map<String, dynamic> group) => {
  'id': '11111111-2222-4333-8444-555555555555',
  'group_id': group['id'],
  'group_name': group['name'],
  'entity': 'expense',
  'local': {'title': 'Dinner (here)', 'summary': '₹1,800 · paid by Rahul · split 4 ways · 23 Sep', 'deleted': false},
  'tricount': {'title': 'Dinner (Tricount)', 'summary': '₹2,000 · paid by Rahul · split 4 ways · 23 Sep', 'deleted': false},
  'created_at': '2026-09-25T06:00:00Z',
};

void main() {
  setUpAll(loadFonts);

  testWidgets('linking a tricount: paste the link, check who is who, start', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    final path = '/api/v1/groups/${goa['id']}/tricount';
    be.get[path] = {'linked': false, 'link': null};
    be.postResponses['$path/preview'] = (200, {
      'title': 'Goa 2026',
      'currency': 'INR',
      'expenses': 3,
      'payments': 1,
      'unsupported': 1,
      'people': [
        {'member_uuid': 'm-john', 'name': 'John', 'suggested': _member(goa, 'John Doe'), 'state': 'you'},
        {'member_uuid': 'm-rahul', 'name': 'Rahul S', 'suggested': _member(goa, 'Rahul Sharma'), 'state': 'suggested'},
        {'member_uuid': 'm-neha', 'name': 'Neha', 'suggested': null, 'state': 'unmatched'},
      ],
      'problem': null,
    });
    be.postResponses[path] = (201, _linked(goa, state: 'syncing'));
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}/tricount');

    expect(find.text('Sync with Tricount'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Paste the link from Tricount (Share → Copy link)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'https://tricount.com/tGOA2026');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Goa 2026'), findsOneWidget);
    expect(find.text('3 expenses · 1 payment · INR'), findsOneWidget);
    expect(find.textContaining("1 entry (income) can't be shown"), findsOneWidget);
    expect(find.text('“Goa Trip” will be renamed “Goa 2026” to match the tricount.'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.text('Add as a new person'), findsOneWidget, reason: 'Neha has no match');

    be.get[path] = _linked(goa); // what the page reads once linked
    await tester.ensureVisible(find.text('Start syncing'));
    await tester.tap(find.text('Start syncing'));
    await tester.pumpAndSettle();
    final (method, sent, body) = be.writes.last;
    expect((method, sent), ('POST', path));
    expect(body['link'], 'https://tricount.com/tGOA2026');
    expect(body['people'], [
      {'member_uuid': 'm-john', 'user_id': _member(goa, 'John Doe')['id']},
      {'member_uuid': 'm-rahul', 'user_id': _member(goa, 'Rahul Sharma')['id']},
      {'member_uuid': 'm-neha', 'user_id': null},
    ]);
    expect(find.text('In sync'), findsOneWidget);
    expect(find.textContaining('Last synced 4 min ago'), findsOneWidget);
  });

  testWidgets('the same group member for two Tricount people is caught before sending', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    final path = '/api/v1/groups/${goa['id']}/tricount';
    be.get[path] = {'linked': false, 'link': null};
    be.postResponses['$path/preview'] = (200, {
      'title': 'Goa 2026', 'currency': 'INR', 'expenses': 0, 'payments': 0, 'unsupported': 0, 'problem': null,
      'people': [
        {'member_uuid': 'a', 'name': 'Rahul', 'suggested': _member(goa, 'Rahul Sharma'), 'state': 'matched'},
        {'member_uuid': 'b', 'name': 'R. Sharma', 'suggested': _member(goa, 'Rahul Sharma'), 'state': 'suggested'},
      ],
    });
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}/tricount');
    await tester.enterText(find.byType(TextField).first, 'tGOA2026');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start syncing'));
    await tester.tap(find.text('Start syncing'));
    await tester.pumpAndSettle();
    expect(find.textContaining('matched to the same person'), findsOneWidget);
    expect(be.writes.where((w) => w.$2 == path), isEmpty);
  });

  testWidgets('a different currency stops linking with the reason', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    final path = '/api/v1/groups/${goa['id']}/tricount';
    be.get[path] = {'linked': false, 'link': null};
    be.postResponses['$path/preview'] = (200, {
      'title': 'Paris', 'currency': 'EUR', 'expenses': 2, 'payments': 0, 'unsupported': 0, 'people': [],
      'problem': "The tricount is in EUR and this group in INR. App can't convert between currencies.",
    });
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}/tricount');
    await tester.enterText(find.byType(TextField).first, 'tPARIS');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The tricount is in EUR'), findsOneWidget);
    final start = tester.widget<SkButton>(find.widgetWithText(SkButton, 'Start syncing'));
    expect(start.onPressed, isNull);
  });

  testWidgets('a linked group shows how it is going and its conflicts', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    final path = '/api/v1/groups/${goa['id']}/tricount';
    be.get[path] = _linked(goa, conflicts: [_conflict(goa)], warnings: ['1 entry in Tricount with income (₹100) can’t be shown in App, so balances can differ.']);
    be.postResponses['/api/v1/tricount/conflicts/${_conflict(goa)['id']}/resolve'] = (200, _linked(goa));
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}/tricount');

    expect(find.text('In sync'), findsOneWidget);
    expect(find.text('https://tricount.com/tGOA2026'), findsOneWidget);
    expect(find.text('Dinner (here)'), findsOneWidget);
    expect(find.text('Dinner (Tricount)'), findsOneWidget);
    expect(find.textContaining('with income (₹100)'), findsOneWidget);

    be.get[path] = _linked(goa);
    await tester.ensureVisible(find.text("Keep Tricount's"));
    await tester.tap(find.text("Keep Tricount's"));
    await tester.pumpAndSettle();
    final (method, sent, body) = be.writes.last;
    expect((method, sent), ('POST', '/api/v1/tricount/conflicts/${_conflict(goa)['id']}/resolve'));
    expect(body, {'keep': 'tricount'});
    expect(find.text('Dinner (Tricount)'), findsNothing);
  });

  testWidgets('a failed sync says why, and Sync now asks again', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    final path = '/api/v1/groups/${goa['id']}/tricount';
    be.get[path] = _linked(goa, state: 'error');
    be.postResponses['$path/sync'] = (200, _linked(goa));
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}/tricount');
    expect(find.text('Not syncing'), findsOneWidget);
    expect(find.textContaining("Can't reach Tricount right now"), findsOneWidget);
    be.get[path] = _linked(goa);
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(be.writes.last.$2, '$path/sync');
    expect(find.text('In sync'), findsOneWidget);
  });

  testWidgets('the group shows it is synced, and the banner asks about conflicts', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    be.get['/api/v1/groups/${goa['id']}/tricount'] = _linked(goa);
    be.get['/api/v1/tricount/conflicts'] = [_conflict(goa)];
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}');
    expect(find.text('Synced with Tricount · 4 min ago'), findsOneWidget);
    expect(find.text('1 change from Tricount needs a decision'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Changed in both apps'), findsOneWidget);
    expect(find.text('An expense in Goa Trip'), findsOneWidget);
  });

  testWidgets('the group menu leads to the sync page', (tester) async {
    final be = FakeBackend();
    final goa = be.goa;
    be.get['/api/v1/groups/${goa['id']}/tricount'] = {'linked': false, 'link': null};
    await pumpApp(tester, backend: be, location: '/groups/${goa['id']}');
    expect(find.textContaining('Synced with Tricount'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Group settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync with Tricount'));
    await tester.pumpAndSettle();
    expect(find.text('Make a new tricount from this group'), findsOneWidget);
  });
}
