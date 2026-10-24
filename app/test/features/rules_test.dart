import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/integrations.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/writes.dart';
import 'package:app/core/router/router.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/goals/goal_detail_page.dart';
import 'package:app/features/goals/goals_page.dart';
import 'package:app/features/goals/rules_page.dart';
import 'package:app/features/personal/personal_txn_sheet.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// The allocation-rule screens over the seed (test/fixtures/sync/john.json) on 25 Sep 2026: two
/// rules, 10% of each income to the Ladakh trip and "Emergency top-up" (₹5,000 to Emergency
/// savings), and their plans from the ₹85,000 salary on 1 Sep: ₹8,500 to the trip (₹2,000 of it
/// set aside) and ₹5,000 to Emergency savings (nothing yet).
const trip = '5a2df56a-ab91-51c5-904b-246d07b01e36';
const topUp = '9b9e5ffd-587d-58fd-9fb0-e78be078afe6';
const ladakh = '79002d77-7486-552b-a16c-d73921823dca';
const fund = '44810de1-2cb6-5600-bbda-885df88b8d98'; // follows Emergency savings
const hdfc = '21aa8dac-2761-5677-ad69-c1b5e7fe9543';
const savings = '137b07e8-c67b-5bb2-a5a7-4f58aa342755';
const salary = '2676dd92-8311-501e-8c3c-c03c47f029bd';

const tall = Size(390, 1400);
const tablet = Size(834, 1112);
const desktop = Size(1440, 900);

/// The seed with [entity] [id]'s synced row changed by [changes].
FakeBackend _with(String entity, String id, Map<String, dynamic> changes, [FakeBackend? backend]) {
  final be = backend ?? FakeBackend();
  for (final s in be.snapshots.values) {
    for (final e in (s as Map)['entities'] as List) {
      if ((e as Map)['entity'] == entity && (e['data'] as Map)['id'] == id) (e['data'] as Map).addAll(changes);
    }
  }
  return be;
}

/// The seed without any [entities].
FakeBackend _without(Set<String> entities) {
  final be = FakeBackend();
  for (final s in be.snapshots.values) {
    ((s as Map)['entities'] as List).removeWhere((e) => entities.contains((e as Map)['entity']));
  }
  return be;
}

const _rules = 'personal_allocation_rule', _plans = 'personal_allocation_plan';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<(String, String, Map?)> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

Finder _inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

Finder _card(String id) => find.byKey(ValueKey('rule:$id'));

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.descendant(of: find.byKey(key), matching: find.byType(TextField)), text);
  await tester.pump();
}

String _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.descendant(of: find.byKey(key), matching: find.byType(TextField))).controller!.text;

/// The chip [label] in the entry sheet's account picker [picker] ('from' or 'to').
Finder _account(String picker, String label) => find.descendant(
  of: find.byKey(ValueKey('account-picker:$picker')),
  matching: find.widgetWithText(SelectableChip, label),
);

bool _picked(WidgetTester tester, Finder chip) => tester.widget<SelectableChip>(chip).selected;

/// The entry sheet's amount, as typed.
String _sheetAmount(WidgetTester tester) =>
    tester.widget<TextField>(_inSheet(find.byType(TextField)).first).controller!.text;

const _overLoad =
    "Your rules set aside 110% of an income into HDFC ··4821. Fixed amounts add up to ₹5,000 more. That's allowed: "
    "the app won't change them.";

void main() {
  setUpAll(loadFonts);

  group('the Rules page', () {
    testWidgets('on a phone: rules in order, what each does, its plans, "Add rule" floating', (tester) async {
      await pumpApp(tester, location: '/personal/goals', size: tall);
      expect(find.text('2 rules plan part of each income'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('rules-card')));
      expect(find.byType(RulesPage), findsOneWidget);

      expect(find.descendant(of: _card(trip), matching: find.text('10% of each income → Ladakh trip')), findsOneWidget);
      expect(find.descendant(of: _card(topUp), matching: find.text('Emergency top-up')), findsOneWidget);
      expect(
        find.descendant(of: _card(topUp), matching: find.text('₹5,000 from each income → Emergency savings')),
        findsOneWidget,
      );
      expect(find.text('From any income · 1 plan made'), findsNWidgets(2));
      expect(tester.getTopLeft(_card(trip)).dy, lessThan(tester.getTopLeft(_card(topUp)).dy));
      expect(find.byKey(const Key('rule-load-warning')), findsNothing); // 10% in all
      expect(tester.widget<AddSplitFab>(find.byType(AddSplitFab)).label, 'Add rule');
      expect(find.widgetWithText(SkButton, 'Add rule'), findsNothing);

      await _tap(tester, find.bySemanticsLabel('Back to goals'));
      expect(find.byType(GoalsPage), findsOneWidget);
    });

    for (final (name, size) in [('a tablet', tablet), ('a desktop', desktop)]) {
      testWidgets('on $name: "Add rule" by the title', (tester) async {
        await pumpApp(tester, location: '/personal/goals/rules', size: size);
        expect(find.byType(AddSplitFab), findsNothing);
        expect(find.text('Emergency top-up'), findsOneWidget);
        await _tap(tester, find.widgetWithText(SkButton, 'Add rule'));
        expect(_inSheet(find.text('New rule')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a filter naming a deleted account, and a paused goal, say why they make no plans', (tester) async {
      final be = _with(_rules, trip, {'source_account_id': 'a0000000-0000-4000-8000-000000000001'});
      _with('personal_goal', ladakh, {'status': 'paused'}, be);
      await pumpApp(tester, backend: be, location: '/personal/goals/rules', size: tall);
      expect(
        find.descendant(of: _card(trip), matching: find.textContaining('takes income from was deleted')),
        findsOneWidget,
      );
      expect(find.text('Ladakh trip is paused, so it makes no plans for now.'), findsOneWidget);
      expect(find.text('From income into an account · 1 plan made'), findsOneWidget);
      expect(find.descendant(of: _card(topUp), matching: find.textContaining('makes no plans')), findsNothing);
    });

    testWidgets('over 100% of an income: a banner, and nothing changed', (tester) async {
      final be = _with(_rules, trip, {'percent_bp': 11000, 'source_account_id': hdfc});
      await pumpApp(tester, backend: be, location: '/personal/goals/rules', size: tall);
      expect(find.text(_overLoad), findsOneWidget);
      expect(find.text('110% of each income → Ladakh trip'), findsOneWidget);
      expect(find.text('From income into HDFC ··4821 · 1 plan made'), findsOneWidget);
      expect(_queued(tester), isEmpty);
    });

    testWidgets('with no rules, an offer to add one', (tester) async {
      await pumpApp(tester, backend: _without({_rules, _plans}), location: '/personal/goals', size: tall);
      expect(find.text('Set aside part of each income for a goal or an account'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('rules-card')));
      expect(find.text('Set aside part of each income'), findsOneWidget);
      expect(find.text('A rule plans money for a goal or an account each time income comes in.'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'Add a rule'));
      expect(_inSheet(find.text('New rule')), findsOneWidget);
    });

    testWidgets('turned off and on with its switch', (tester) async {
      await pumpApp(tester, location: '/personal/goals/rules', size: tall);
      await _tap(tester, find.descendant(of: _card(trip), matching: find.byType(Switch)));
      final (method, path, body) = _queued(tester).single;
      expect(
        (method, path, body!['active'], body['percent_bp'], body['goal_id'], body['version']),
        ('PUT', '/api/v1/personal/allocation-rules/$trip', false, 1000, ladakh, 1),
      );
      expect(find.text('Turned off 10% of each income → Ladakh trip'), findsOneWidget);
      expect(find.text('From any income · Off · 1 plan made'), findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: _card(trip), matching: find.byType(Switch))).value, isFalse);

      await _tap(tester, find.descendant(of: _card(trip), matching: find.byType(Switch)));
      expect(_queued(tester).last.$3!['active'], isTrue);
      expect(find.text('From any income · 1 plan made'), findsNWidgets(2));
    });

    testWidgets('deleted from its editor, with Undo', (tester) async {
      await pumpApp(tester, location: '/personal/goals/rules', size: tall);
      await _tap(tester, _card(topUp));
      expect(_inSheet(find.text('Edit rule')), findsOneWidget);
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Delete rule')));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Deleted Emergency top-up'), findsOneWidget);
      expect(_card(topUp), findsNothing);
      expect(_queued(tester).single.$1, 'DELETE');
      expect(_queued(tester).single.$2, '/api/v1/personal/allocation-rules/$topUp');

      await _tap(tester, find.text('Undo'));
      expect(_queued(tester).last.$2, '/api/v1/personal/allocation-rules/$topUp/restore');
      expect(_card(topUp), findsOneWidget);
    });

    testWidgets('Features.allocationRules off: no page, no card, no plans', (tester) async {
      await pumpApp(
        tester,
        location: '/personal/goals/rules',
        size: tall,
        overrides: [featuresProvider.overrideWithValue(const Features(allocationRules: false))],
      );
      expect(find.byType(RulesPage), findsNothing);
      expect(find.byType(GoalsPage), findsOneWidget);
      expect(find.byKey(const Key('rules-card')), findsNothing);
      expect(find.bySemanticsLabel('Planned ₹6,500, not yet saved'), findsNothing);
      appContainer(tester).read(routerProvider).go('/personal/goals/$ladakh');
      await tester.pumpAndSettle();
      expect(find.text('Planned, not yet saved'), findsNothing);
      appContainer(tester).read(routerProvider).go('/personal');
      await tester.pumpAndSettle();
      expect(find.text('Planned from income'), findsNothing);
    });
  });

  group('the rule editor', () {
    testWidgets('a new rule: a percentage of any income to a goal, warned live over 100%', (tester) async {
      await pumpApp(tester, location: '/personal/goals/rules', size: tall);
      await _tap(tester, find.text('Add rule'));
      expect(_inSheet(find.text('New rule')), findsOneWidget);
      expect(
        _inSheet(find.text('Applies to income recorded from now on. Plans already made keep their amounts.')),
        findsOneWidget,
      );
      // Only active goals that count contributions take money.
      expect(_inSheet(find.widgetWithText(SelectableChip, 'Ladakh trip')), findsOneWidget);
      expect(_inSheet(find.widgetWithText(SelectableChip, 'Gold coins')), findsNothing);
      expect(_inSheet(find.widgetWithText(SelectableChip, 'Emergency fund')), findsNothing);

      await _type(tester, const Key('rule-percent'), '95');
      expect(
        _inSheet(
          find.text(
            "Your rules would set aside 105% of an income. Fixed amounts add up to ₹5,000 more. That's allowed: the "
            "app won't change them.",
          ),
        ),
        findsOneWidget,
      );
      await _type(tester, const Key('rule-percent'), '1001');
      expect(_inSheet(find.text('A percentage from 0.01 to 1000, like 10 or 12.5')), findsOneWidget);
      await _type(tester, const Key('rule-percent'), '12.5');
      expect(find.byKey(const Key('rule-load-warning')), findsNothing);

      await _type(tester, const Key('rule-name'), 'Trip boost');
      await _tap(tester, _inSheet(find.widgetWithText(SelectableChip, 'Ladakh trip')));
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add rule')));
      expect(find.byType(BottomSheet), findsNothing);
      final (method, path, body) = _queued(tester).single;
      expect(
        (method, path, body!['kind'], body['percent_bp'], body['amount_minor'], body['goal_id'], body['account_id']),
        ('POST', '/api/v1/personal/allocation-rules', 'percentage', 1250, null, ladakh, null),
      );
      expect(
        (body['name'], body['source_category_id'], body['source_account_id'], body['active']),
        ('Trip boost', null, null, true),
      );
      expect(find.text('Trip boost'), findsOneWidget);
      expect(find.text('12.5% of each income → Ladakh trip'), findsOneWidget);
      expect(find.text('From any income · No plans yet'), findsOneWidget);
    });

    testWidgets('a fixed amount from one account\'s income, to an account', (tester) async {
      await pumpApp(tester, location: '/personal/goals/rules', size: tall);
      await _tap(tester, find.text('Add rule'));
      await _tap(tester, _inSheet(find.widgetWithText(SelectableChip, 'Fixed')));
      await _type(tester, const Key('rule-amount'), '2000');
      await _tap(tester, _inSheet(find.widgetWithText(SelectableChip, 'An account').first));
      await _tap(tester, _inSheet(find.widgetWithText(SelectableChip, 'HDFC ··4821')));
      await _tap(tester, _inSheet(find.widgetWithText(SelectableChip, 'An account').last));
      await _tap(tester, _inSheet(find.widgetWithText(SelectableChip, 'Emergency savings')).last);
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add rule')));
      final body = _queued(tester).single.$3!;
      expect(
        (body['kind'], body['amount_minor'], body['percent_bp'], body['source_account_id'], body['account_id']),
        ('fixed', 200000, null, hdfc, savings),
      );
      expect(find.text('₹2,000 from each income → Emergency savings'), findsOneWidget);
      expect(find.text('From income into HDFC ··4821 · No plans yet'), findsOneWidget);
    });

    testWidgets('editing a rule saves its full state; plans keep their amounts', (tester) async {
      await pumpApp(tester, location: '/personal/goals/rules', size: tall);
      await _tap(tester, _card(topUp));
      expect(_field(tester, const Key('rule-name')), 'Emergency top-up');
      expect(_field(tester, const Key('rule-amount')), '5,000');
      expect(tester.widget<SelectableChip>(_inSheet(find.widgetWithText(SelectableChip, 'Fixed'))).selected, isTrue);
      await _type(tester, const Key('rule-amount'), '6000');
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Save changes')));
      final (method, path, body) = _queued(tester).single;
      expect(
        (method, path, body!['amount_minor'], body['account_id'], body['name'], body['version']),
        ('PUT', '/api/v1/personal/allocation-rules/$topUp', 600000, savings, 'Emergency top-up', 1),
      );
      expect(find.text('₹6,000 from each income → Emergency savings'), findsOneWidget);
      expect(find.text('From any income · 1 plan made'), findsNWidgets(2));
    });

    testWidgets('a refusal says why, keeps the editor open and queues nothing', (tester) async {
      await pumpApp(tester, location: '/personal/goals/rules', size: tall);
      await _tap(tester, _card(trip));
      // Deleted meanwhile (another device, say).
      await runWrite(tester, appContainer(tester).read(writesProvider).deleteRule(trip));
      await tester.pumpAndSettle();
      await _type(tester, const Key('rule-name'), 'Trip');
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Save changes')));
      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text('Restore this rule before editing it')),
        findsOneWidget,
      );
      expect(_inSheet(find.text('Edit rule')), findsOneWidget);
      expect([for (final op in _queued(tester)) op.$1], ['DELETE']);
    });
  });

  group('plans on goals', () {
    testWidgets('goal cards outline what is planned and not yet saved', (tester) async {
      await pumpApp(tester, location: '/personal/goals', size: tall);
      expect(find.bySemanticsLabel('Planned ₹6,500, not yet saved'), findsOneWidget); // Ladakh trip
      expect(find.bySemanticsLabel('Planned ₹5,000, not yet saved'), findsOneWidget); // Emergency fund
      expect(find.text('₹17,000 of ₹60,000 · 28%'), findsOneWidget); // never in the progress
    });

    testWidgets('goal detail: "Planned, not yet saved", and Record adds what\'s left', (tester) async {
      await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      expect(find.text('28%'), findsOneWidget);
      expect(find.text('₹17,000 of ₹60,000'), findsOneWidget);
      expect(find.bySemanticsLabel('Planned, not yet saved: ₹6,500'), findsOneWidget);
      expect(find.bySemanticsLabel('Planned ₹6,500, not yet saved'), findsOneWidget);
      expect(find.text('Planned, not yet saved'), findsNWidgets(2)); // the line above, and the list
      expect(find.text('₹6,500 to set aside'), findsOneWidget);
      expect(find.textContaining('₹2,000 of ₹8,500 saved · from Salary · '), findsOneWidget);

      await _tap(tester, find.widgetWithText(SkButton, 'Record'));
      expect(_inSheet(find.text('To Ladakh trip')), findsOneWidget);
      expect(_field(tester, const Key('contribution-amount')), '6,500');
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add money')));
      expect(find.text('Added ₹6,500 to Ladakh trip'), findsOneWidget);
      expect(find.text('₹23,500 of ₹60,000'), findsOneWidget);
      expect(find.text('Planned, not yet saved'), findsNothing); // fulfilled
    });

    testWidgets('following an account: its plans, and Record moves what\'s left there', (tester) async {
      await pumpApp(tester, location: '/personal/goals/$fund', size: tall);
      expect(find.text('₹5,000 to set aside'), findsOneWidget);
      expect(find.textContaining('₹5,000 planned · from Salary · '), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'Record'));
      expect(_inSheet(find.text('Add transfer')), findsOneWidget);
      expect(_sheetAmount(tester), '5,000');
      expect(_picked(tester, _account('to', 'Emergency savings')), isTrue);
      expect(_picked(tester, _account('from', 'HDFC ··4821')), isFalse);

      await _tap(tester, _account('from', 'HDFC ··4821'));
      await tester.enterText(_inSheet(find.byType(TextField)).at(1), 'Emergency top-up');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save transfer'));
      final items = (_queued(tester).single.$3!['items'] as List).cast<Map>();
      expect(
        [for (final i in items) (i['transaction']['direction'], i['transaction']['account_id'])],
        [('out', hdfc), ('in', savings)],
      );
      expect(find.text('₹5,000 to set aside'), findsNothing); // fulfilled
    });

    testWidgets('"Move money to Emergency savings" opens the transfer into it (ISS-111)', (tester) async {
      await pumpApp(tester, location: '/personal/goals/$fund', size: tall);
      await _tap(tester, find.text('Move money to Emergency savings'));
      expect(_inSheet(find.text('Add transfer')), findsOneWidget);
      expect(_picked(tester, _account('to', 'Emergency savings')), isTrue);
      expect(_picked(tester, _account('from', 'Emergency savings')), isFalse);
      expect(_sheetAmount(tester), '');
    });

    testWidgets('a transfer can start from both sides and an amount; a closed account is left to pick', (tester) async {
      await pumpApp(tester, backend: _with('personal_account', hdfc, {'status': 'closed'}), size: tall);
      showPersonalTxnSheet(
        tester.element(find.byType(Scaffold).first),
        type: 'transfer',
        fromAccountId: hdfc,
        toAccountId: savings,
        amountMinor: 123450,
      );
      await tester.pumpAndSettle();
      expect(_sheetAmount(tester), '1,234.50');
      expect(_picked(tester, _account('to', 'Emergency savings')), isTrue);
      expect(_account('from', 'HDFC ··4821'), findsNothing); // closed: not picked, so not offered
      expect(tester.widget<SkButton>(find.widgetWithText(SkButton, 'Save transfer')).onPressed, isNull);
    });
  });

  group('the entry sheet', () {
    testWidgets('an income shows the plans made from it', (tester) async {
      await pumpApp(tester, location: '/personal', size: tall);
      final ledger = appContainer(tester).read(localStoreProvider).value!.ledger;
      showPersonalTxnSheet(
        tester.element(find.byType(Scaffold).first),
        existing: PersonalTxnOut.fromJson(ledger.personalTransaction(salary))!,
      );
      await tester.pumpAndSettle();
      expect(_inSheet(find.text('Plans from this income')), findsOneWidget);
      expect(_inSheet(find.text('₹8,500 → Ladakh trip')), findsOneWidget);
      expect(_inSheet(find.text('Partly saved')), findsOneWidget);
      expect(_inSheet(find.text('₹2,000 saved so far')), findsOneWidget);
      expect(_inSheet(find.text('₹5,000 → Emergency savings')), findsOneWidget);
      expect(_inSheet(find.text('Planned')), findsOneWidget);
    });

    testWidgets('saving a new income says what was planned from it', (tester) async {
      await pumpApp(tester, location: '/personal', size: tall);
      showPersonalTxnSheet(tester.element(find.byType(Scaffold).first), type: 'income');
      await tester.pumpAndSettle();
      await tester.enterText(_inSheet(find.byType(TextField)).at(0), '40000');
      await tester.enterText(_inSheet(find.byType(TextField)).at(1), 'Bonus');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save income'));
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Planned: ₹4,000 → Ladakh trip, ₹5,000 → Emergency savings'),
        ),
        findsOneWidget,
      );
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('POST', '/api/v1/personal/batch'));
      expect(
        [for (final i in body!['items'] as List) ((i as Map)['kind'], i['op'])],
        [('transaction', 'create'), ('allocation_plan', 'create'), ('allocation_plan', 'create')],
      );
    });

    testWidgets('a spend says nothing of plans', (tester) async {
      await pumpApp(tester, location: '/personal', size: tall);
      showPersonalTxnSheet(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
      await tester.enterText(_inSheet(find.byType(TextField)).at(0), '400');
      await tester.enterText(_inSheet(find.byType(TextField)).at(1), 'Lunch');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save expense'));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group("Overview's planned against actual", () {
    for (final (name, size) in [('a phone', tall), ('a desktop', desktop)]) {
      testWidgets('on $name: what was planned from the month\'s income, and what is set aside', (tester) async {
        await pumpApp(tester, location: '/personal', size: size);
        final card = find.byKey(const Key('planned-actual'));
        expect(find.text('Planned from income'), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('₹2,000 of ₹13,500 set aside')), findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text("So far, for what your rules planned from September's income."),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Planned ₹11,500, not yet saved'), findsOneWidget);
        expect(find.bySemanticsLabel('Ladakh trip: ₹2,000 of ₹8,500'), findsOneWidget);
        expect(find.bySemanticsLabel('Emergency savings: ₹0 of ₹5,000'), findsOneWidget);
        // Ladakh trip, the larger, first.
        expect(
          tester.getTopLeft(find.descendant(of: card, matching: find.text('Ladakh trip'))).dy,
          lessThan(tester.getTopLeft(find.descendant(of: card, matching: find.text('Emergency savings'))).dy),
        );
        await _tap(tester, find.text('Rules'));
        expect(find.byType(RulesPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('with no rules: an offer to set one up', (tester) async {
      await pumpApp(tester, backend: _without({_rules, _plans}), location: '/personal', size: tall);
      expect(find.text('Set a savings % of each income'), findsOneWidget);
      expect(find.byKey(const Key('planned-actual')), findsNothing);
      await _tap(tester, find.widgetWithText(SkButton, 'Set up'));
      expect(_inSheet(find.text('New rule')), findsOneWidget);
    });

    testWidgets('with rules but no plans that month: when plans appear', (tester) async {
      await pumpApp(tester, backend: _without({_plans}), location: '/personal', size: tall);
      expect(find.text('Plans appear when income comes in.'), findsOneWidget);
      expect(find.text('Set a savings % of each income'), findsNothing);
    });
  });

  testWidgets('goal detail\'s planned list on a desktop', (tester) async {
    await pumpApp(tester, location: '/personal/goals/$ladakh', size: desktop);
    expect(find.byType(GoalDetailPage), findsOneWidget);
    expect(find.text('₹6,500 to set aside'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
