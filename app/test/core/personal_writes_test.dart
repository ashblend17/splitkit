import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';
import 'package:splitkit/design_system/design_system.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// A personal entry from the seed's sync snapshot (what the server stores).
Map<String, dynamic> _serverEntry(String description) {
  final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map;
  final entities = [
    for (final s in (fixture['snapshots'] as Map).values)
      for (final e in (s as Map)['entities'] as List)
        if ((e as Map)['entity'] == 'personal_transaction') (e['data'] as Map).cast<String, dynamic>(),
  ];
  return entities.firstWhere((d) => d['description'] == description);
}

PersonalTxnOut _out(String description) =>
    PersonalTxnOut.fromJson((fixture('personal_list') as Map)['items'].firstWhere((t) => t['description'] == description))!;

void main() {
  setUpAll(loadFonts);

  testWidgets('a queued entry has the same keys as the server stores, so it can be matched', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    final container = appContainer(tester);
    await runWrite(
      tester,
      container.read(writesProvider).createPersonal(
        PersonalTxnIn(
          type: PersonalTxnInTypeEnum.expense,
          amountMinor: 45000,
          description: 'Swiggy',
          date: DateTime.utc(2026, 9, 24),
          channel: PersonalTxnInChannelEnum.upi,
          merchant: ' SWIGGY ',
          account: 'HDFC ··4821',
          reviewed: false,
          source_: PersonalTxnInSource_Enum.sms,
          reference: '426700000001',
          balanceMinor: 4000000,
          smsAt: DateTime.utc(2026, 9, 24, 8),
        ),
        id: '00000000-0000-5000-8000-000000000001',
      ),
    );
    final queued = container.read(outboxProvider).single.entities.single;
    expect(queued.entityId, '00000000-0000-5000-8000-000000000001');
    expect(queued.data.keys.toSet(), _serverEntry('Swiggy order').keys.toSet());
    expect((queued.data['merchant'], queued.data['source'], queued.data['reviewed']), ('SWIGGY', 'sms', false));
  });

  testWidgets('an edit keeps where the entry came from, and its link', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    final container = appContainer(tester);
    final uber = _out('Uber to airport');
    expect((uber.source_.value, uber.counted), ('sms', false));
    expect(uber.expenseId, isNotNull);
    final body = personalBody(uber)
      ..description = 'Airport cab'
      ..source_ = PersonalTxnInSource_Enum.manual // ignored on an edit, as by the server
      ..reference = 'x';
    await runWrite(tester, container.read(writesProvider).updatePersonal(uber.id, body));
    final op = container.read(outboxProvider).single;
    final data = op.entities.single.data;
    expect((data['description'], data['source'], data['reference']), ('Airport cab', 'sms', uber.reference));
    expect((data['expense_id'], data['merchant'], data['account']), (uber.expenseId, 'UBER', 'HDFC ··4821'));
    expect((op.body as Map)['expense_id'], uber.expenseId);
  });

  testWidgets('editing an SMS entry in the sheet sends it back whole, as looked at', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    // Unchecked, so it's in "Just in" at the top.
    await tester.tap(find.text('Swiggy order').first);
    await tester.pumpAndSettle();
    expect(find.text('From an SMS · HDFC ··4821 · balance after ₹42,276'), findsOneWidget);
    expect(tester.widget<SelectableChip>(find.widgetWithText(SelectableChip, 'UPI')).selected, isTrue);
    await tester.enterText(find.byType(TextField).at(1), 'Swiggy dinner');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final body = appContainer(tester).read(outboxProvider).single.body as Map;
    expect((body['description'], body['merchant'], body['account'], body['channel'], body['reviewed']), (
      'Swiggy dinner',
      'SWIGGY',
      'HDFC ··4821',
      'upi',
      true,
    ));
  });

  testWidgets('a new entry says how it was paid', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/personal/transactions'] = (201, (fixture('personal_list') as Map)['items'][0]);
    await pumpApp(tester, backend: be, location: '/personal');
    await tester.tap(find.byType(AddSplitFab));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Books');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(SelectableChip, 'Card'));
    await tester.tap(find.widgetWithText(SelectableChip, 'Card'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    final (_, _, body) = be.writes.single;
    expect((body['channel'], body['source'], body['reviewed']), ('card', 'manual', true));
  });
}
