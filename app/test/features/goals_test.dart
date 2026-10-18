import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/router/router.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/common/common.dart';
import 'package:splitkit/features/goals/goal_detail_page.dart';
import 'package:splitkit/features/goals/goals_page.dart';
import 'package:splitkit/features/shell/app_mode.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// The seed's goals (test/fixtures/sync/john.json) on the fixtures' day, 25 Sep 2026.
const ladakh = '79002d77-7486-552b-a16c-d73921823dca'; // contributions: ₹17,000 of ₹60,000 by 31 May 2027
const fund = '44810de1-2cb6-5600-bbda-885df88b8d98'; // follows Emergency savings (₹1,20,000) of ₹2,70,000
const gold = '70ade64d-7342-5050-ae56-d1f1a10c3c84'; // by hand: ₹68,000 of ₹2,00,000
const sip = '9ca547fb-7076-576a-8278-d6b129425c96'; // the ₹5,000 Index fund SIP, counted toward no goal

const tall = Size(390, 1400);
const desktop = Size(1440, 900);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The seed with goal [id]'s synced row changed by [changes].
FakeBackend _withGoal(String id, Map<String, dynamic> changes, [FakeBackend? backend]) {
  final be = backend ?? FakeBackend();
  for (final s in be.snapshots.values) {
    for (final e in (s as Map)['entities'] as List) {
      if ((e as Map)['entity'] == 'personal_goal' && (e['data'] as Map)['id'] == id) (e['data'] as Map).addAll(changes);
    }
  }
  return be;
}

/// The seed with no goals at all.
FakeBackend _noGoals() {
  final be = FakeBackend();
  for (final s in be.snapshots.values) {
    ((s as Map)['entities'] as List).removeWhere(
      (e) => const {'personal_goal', 'personal_goal_contribution'}.contains((e as Map)['entity']),
    );
  }
  return be;
}

List<(String, String, Map?)> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

List<Map> _items(Map? body) => (body!['items'] as List).cast<Map>();

Finder _inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.descendant(of: find.byKey(key), matching: find.byType(TextField)), text);
  await tester.pump();
}

/// Opens goal [id]'s menu and picks [option].
Future<void> _menu(WidgetTester tester, String option) async {
  await _tap(tester, find.bySemanticsLabel('Goal options'));
  await _tap(tester, find.text(option).last);
}

void main() {
  setUpAll(loadFonts);

  group('the Goals tab', () {
    testWidgets('on a phone: active goals as cards, with "New goal" floating', (tester) async {
      await pumpApp(tester, location: '/personal/goals', size: tall);
      expect(find.text('ACTIVE'), findsOneWidget);
      for (final name in ['Emergency fund', 'Ladakh trip', 'Gold coins']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('₹17,000 of ₹60,000 · 28%'), findsOneWidget);
      expect(find.text('₹4,777.78/month to May 2027'), findsOneWidget);
      expect(find.text('On track'), findsOneWidget);
      expect(find.text('₹1,20,000 of ₹2,70,000 · 44%'), findsOneWidget);
      expect(find.text('₹68,000 of ₹2,00,000 · 34%'), findsOneWidget);
      expect(find.text('No target date: progress only'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Saved ₹17,000'), findsOneWidget);
      expect(find.text('PAUSED'), findsNothing);
      final fab = tester.widget<AddSplitFab>(find.byType(AddSplitFab));
      expect(fab.label, 'New goal');
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).current, 'goals');
      expect(find.byType(ModeSwitch), findsOneWidget); // a tab root

      await _tap(tester, find.text('Ladakh trip'));
      expect(find.byType(GoalDetailPage), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Back to goals'));
      expect(find.byType(GoalsPage), findsOneWidget);
    });

    testWidgets('on a desktop: cards in columns and "New goal" by the title', (tester) async {
      await pumpApp(tester, location: '/personal/goals', size: desktop);
      expect(find.byType(CardColumns), findsOneWidget);
      expect(find.byType(AddSplitFab), findsNothing);
      await _tap(tester, find.widgetWithText(SkButton, 'New goal'));
      expect(_inSheet(find.text('Add goal')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paused, then done and archived, folded away', (tester) async {
      final be = _withGoal(gold, {'status': 'paused'}, _withGoal(fund, {'status': 'archived'}));
      await pumpApp(tester, backend: be, location: '/personal/goals', size: tall);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget); // Gold coins' chip
      expect(find.text('DONE AND ARCHIVED (1)'), findsOneWidget);
      expect(find.text('Emergency fund'), findsNothing);
      await _tap(tester, find.text('DONE AND ARCHIVED (1)'));
      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('with no goals, an offer to set one', (tester) async {
      await pumpApp(tester, backend: _noGoals(), location: '/personal/goals', size: tall);
      expect(find.text('No goals yet'), findsOneWidget);
      expect(find.text('Save towards something: a trip, an emergency fund, a gadget.'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'New goal'));
      expect(_inSheet(find.text('Add goal')), findsOneWidget);
    });
  });

  group('a goal', () {
    testWidgets('counting contributions: progress, months left, what each month needs, history', (tester) async {
      await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      expect(find.text('Ladakh trip'), findsOneWidget);
      expect(find.text('28%'), findsOneWidget);
      expect(find.text('₹17,000 of ₹60,000'), findsOneWidget);
      expect(find.bySemanticsLabel('Left to save: ₹43,000'), findsOneWidget);
      expect(find.bySemanticsLabel('Target date: May 2027'), findsOneWidget);
      expect(find.bySemanticsLabel('Time left: 9 months left'), findsOneWidget);
      expect(find.bySemanticsLabel('Needed each month: ₹4,777.78'), findsOneWidget);
      expect(find.textContaining('Expected'), findsNothing);
      // Newest first.
      expect(find.text('₹2,000'), findsOneWidget);
      expect(find.text('₹15,000'), findsOneWidget);
      expect(tester.getTopLeft(find.text('₹2,000')).dy, lessThan(tester.getTopLeft(find.text('₹15,000')).dy));
      expect(find.textContaining('Saved before I started tracking'), findsOneWidget);
      expect(tester.widget<AddSplitFab>(find.byType(AddSplitFab)).label, 'Add money');
      expect(find.byType(ModeSwitch), findsNothing); // opened from a tab
    });

    testWidgets('over its target: 100% shown, the true % and how much over beneath', (tester) async {
      await pumpApp(
        tester,
        backend: _withGoal(gold, {'manual_progress_minor': 22400000}),
        location: '/personal/goals/$gold',
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('112% · ₹24,000 over'), findsOneWidget);
      expect(find.text('Reached'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Left to save')), findsNothing);
      expect(find.widgetWithText(SkButton, 'Mark complete'), findsOneWidget);
    });

    testWidgets('overdue, and behind its trajectory', (tester) async {
      await pumpApp(
        tester,
        backend: _withGoal(ladakh, {'target_date': '2026-09-13'}),
        location: '/personal/goals/$ladakh',
      );
      expect(find.text('Overdue by 12 days'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Needed each month')), findsNothing);

      // 36 days of 72 gone, so ₹30,000 by now.
      await pumpApp(
        tester,
        backend: _withGoal(ladakh, {'target_date': '2026-10-31'}),
        location: '/personal/goals/$ladakh',
      );
      expect(find.text('Behind'), findsOneWidget);
      expect(find.text('Expected ₹30,000 by now'), findsOneWidget);
    });

    testWidgets('an estimate with returns, labelled as one', (tester) async {
      await pumpApp(
        tester,
        backend: _withGoal(ladakh, {'expected_return_bp': 80}),
        location: '/personal/goals/$ladakh',
      );
      expect(find.text('ESTIMATE WITH RETURNS'), findsOneWidget);
      expect(find.textContaining("If what's saved earns 0.8% a month, about ₹"), findsOneWidget);
    });

    testWidgets("following an account: its balance, a way to move money there, no floating button", (tester) async {
      await pumpApp(tester, location: '/personal/goals/$fund', size: tall);
      expect(find.text('Follows Emergency savings · balance ₹1,20,000'), findsOneWidget);
      expect(find.text('No target date: progress only'), findsOneWidget);
      expect(find.byType(AddSplitFab), findsNothing);
      expect(find.text('Contributions'), findsNothing);
      await _tap(tester, find.text('Move money to Emergency savings'));
      expect(find.text('Add transfer'), findsOneWidget);
    });

    testWidgets('tracked by hand: Update progress', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$gold', size: tall);
      be.offline = true;
      expect(find.byType(AddSplitFab), findsNothing);
      await _tap(tester, find.widgetWithText(SkButton, 'Update progress'));
      await _type(tester, const Key('progress-amount'), '70000');
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Save')));
      final (method, path, body) = _queued(tester).single;
      expect((method, path, body!['manual_progress_minor']), ('PUT', '/api/v1/personal/goals/$gold', 7000000));
      expect(find.text('₹70,000 of ₹2,00,000'), findsOneWidget);
      expect(find.text('Gold coins: ₹70,000 saved'), findsOneWidget);
    });

    testWidgets('delete, with Undo', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      be.offline = true;
      await _menu(tester, 'Delete');
      await _tap(tester, find.widgetWithText(InkWell, 'Delete').last);
      expect(_queued(tester).single.$1, 'DELETE');
      expect(find.byType(GoalsPage), findsOneWidget);
      expect(find.text('Deleted Ladakh trip'), findsOneWidget);
      expect(find.text('Ladakh trip'), findsNothing);
      await _tap(tester, find.text('Undo'));
      expect(_queued(tester).last.$2, '/api/v1/personal/goals/$ladakh/restore');
      expect(find.text('Ladakh trip'), findsOneWidget);
    });

    testWidgets('pause, then resume', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      be.offline = true;
      await _menu(tester, 'Pause');
      expect(_queued(tester).single.$3!['status'], 'paused');
      expect(find.text('Paused'), findsOneWidget);
      await _menu(tester, 'Resume');
      expect(_queued(tester).last.$3!['status'], 'active');
      expect(find.text('On track'), findsOneWidget);
    });

    testWidgets('a goal that isn\'t there', (tester) async {
      await pumpApp(tester, location: '/personal/goals/a0000000-0000-4000-8000-000000000000', size: tall);
      expect(find.text("This isn't here"), findsOneWidget);
    });
  });

  group('the editor', () {
    testWidgets('a new goal', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals', size: tall);
      be.offline = true;
      await _tap(tester, find.byType(AddSplitFab));
      expect(find.text('New goal'), findsWidgets);
      await _type(tester, const Key('goal-name'), 'New laptop');
      await _type(tester, const Key('goal-target'), '90000');
      await _type(tester, const Key('goal-return'), '0.5');
      await _tap(tester, find.widgetWithText(SkButton, 'Add goal'));
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('POST', '/api/v1/personal/goals'));
      expect(
        (body!['name'], body['target_minor'], body['tracking_mode'], body['target_date'], body['expected_return_bp']),
        ('New laptop', 9000000, 'contribution', null, 50),
      );
      expect(find.text('New laptop'), findsOneWidget);
      expect(find.text('₹0 of ₹90,000 · 0%'), findsOneWidget);
    });

    testWidgets('a new goal that follows an account, offered only those it can follow', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals', size: tall);
      be.offline = true;
      await _tap(tester, find.byType(AddSplitFab));
      await _type(tester, const Key('goal-name'), 'House');
      await _type(tester, const Key('goal-target'), '500000');
      await _tap(tester, find.text('Account balance'));
      expect(_inSheet(find.text('Emergency savings')), findsNothing); // Emergency fund follows it
      expect(_inSheet(find.text('ICICI Credit card ··9012')), findsNothing); // what you owe
      // Cash takes the money Ladakh trip counts (its cash jar): following it would count it twice.
      await _tap(tester, _inSheet(find.text('Cash')));
      expect(find.text('Balance ₹2,500'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'Add goal'));
      expect(_queued(tester), isEmpty);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.textContaining('Ladakh trip')), findsOneWidget);
      await _tap(tester, _inSheet(find.text('Zerodha')));
      expect(find.text('Balance ₹85,750'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'Add goal'));
      final body = _queued(tester).single.$3!;
      expect(
        (body['tracking_mode'], body['linked_account_id']),
        ('linked_balance', '3ba3ab40-68eb-5169-bd41-e06f44ea0e71'),
      );
    });

    testWidgets('editing a goal saves its full state', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      be.offline = true;
      await _menu(tester, 'Edit');
      expect(find.text('Edit goal'), findsOneWidget);
      await _type(tester, const Key('goal-name'), 'Ladakh and Spiti');
      await _tap(tester, find.text('Clear'));
      await _tap(tester, find.widgetWithText(SkButton, 'Save changes'));
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('PUT', '/api/v1/personal/goals/$ladakh'));
      expect((body!['name'], body['target_date'], body['target_minor']), ('Ladakh and Spiti', null, 6000000));
      expect(find.text('Ladakh and Spiti'), findsOneWidget);
      expect(find.text('No target date: progress only'), findsOneWidget);
    });

    testWidgets('switching to by hand starts from today\'s progress', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      be.offline = true;
      await _menu(tester, 'Edit');
      await _tap(tester, find.widgetWithText(SkButton, 'Change'));
      expect(find.text('Track Ladakh trip another way'), findsOneWidget);
      await _tap(tester, find.text('By hand'));
      expect(find.text('17,000'), findsOneWidget); // prefilled
      expect(find.text('₹17,000'), findsNWidgets(2)); // now and after
      await _tap(tester, find.widgetWithText(SkButton, 'Switch'));
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('PUT', '/api/v1/personal/goals/$ladakh'));
      expect((body!['tracking_mode'], body['manual_progress_minor']), ('manual', 1700000));
      expect(find.text('Ladakh trip is now tracked by hand'), findsOneWidget);
      expect(find.byType(AddSplitFab), findsNothing);
    });

    testWidgets('switching to contributions records a starting amount, in one batch', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$gold', size: tall);
      be.offline = true;
      await _menu(tester, 'Edit');
      await _tap(tester, find.widgetWithText(SkButton, 'Change'));
      await _tap(tester, find.text('Contributions'));
      expect(find.text('Record a starting amount of ₹68,000'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'Switch'));
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('POST', '/api/v1/personal/batch'));
      expect(
        [for (final i in _items(body)) (i['kind'], i['op'])],
        [('goal', 'update'), ('goal_contribution', 'create')],
      );
      expect(find.text('₹68,000 of ₹2,00,000'), findsOneWidget);
    });
  });

  group('adding money', () {
    Future<FakeBackend> open(WidgetTester tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      be.offline = true;
      await _tap(tester, find.byType(AddSplitFab));
      expect(_inSheet(find.text('To Ladakh trip')), findsOneWidget);
      return be;
    }

    testWidgets('not recorded anywhere: a contribution on its own', (tester) async {
      await open(tester);
      await _type(tester, const Key('contribution-amount'), '500');
      await _type(tester, const Key('contribution-note'), 'Coins');
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add money')));
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('POST', '/api/v1/personal/goal-contributions'));
      expect(
        (body!['amount_minor'], body['transaction_id'], body['date'], body['note']),
        (50000, null, '2026-09-25', 'Coins'),
      );
      expect(find.text('Added ₹500 to Ladakh trip'), findsOneWidget);
      expect(find.text('₹17,500 of ₹60,000'), findsOneWidget);
    });

    testWidgets('between my accounts: the transfer and the contribution, in one batch', (tester) async {
      await open(tester);
      await _type(tester, const Key('contribution-amount'), '1000');
      await _tap(tester, find.text('Between my accounts'));
      await _tap(tester, _inSheet(find.text('HDFC ··4821')).first);
      await _tap(tester, _inSheet(find.text('Cash')).last);
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add money')));
      final (_, path, body) = _queued(tester).single;
      expect(path, '/api/v1/personal/batch');
      expect(
        [for (final i in _items(body)) (i['kind'], i['op'])],
        [('transaction', 'create'), ('transaction', 'create'), ('goal_contribution', 'create')],
      );
      expect(find.text('₹18,000 of ₹60,000'), findsOneWidget);
    });

    testWidgets('invested: the investment and the contribution, in one batch', (tester) async {
      await open(tester);
      await _type(tester, const Key('contribution-amount'), '2500');
      await _tap(tester, find.text('Invested'));
      await _tap(tester, _inSheet(find.text('HDFC ··4821')));
      await _tap(tester, _inSheet(find.text('Nifty 50 index fund')));
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add money')));
      final items = _items(_queued(tester).single.$3);
      expect(
        [for (final i in items) (i['kind'], i['op'])],
        [('transaction', 'create'), ('goal_contribution', 'create')],
      );
      final entry = items.first['transaction'] as Map;
      expect((entry['type'], entry['holding_id']), ('investment_contribution', '4df4e7ab-a0dd-51d0-bf85-5f4a024a292b'));
    });

    testWidgets('an existing entry: one that counts toward no goal yet', (tester) async {
      await open(tester);
      await _tap(tester, find.text('An existing entry'));
      // The cash withdrawal already counts toward this goal; its out-leg isn't money in.
      expect(find.text('Cash withdrawal'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('entry:$sip')));
      expect(find.text('5,000'), findsOneWidget);
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add money')));
      final body = _queued(tester).single.$3!;
      expect((body['transaction_id'], body['amount_minor']), (sip, 500000));
    });

    testWidgets('a refusal says why, and nothing is queued', (tester) async {
      await open(tester);
      await _type(tester, const Key('contribution-amount'), '1000');
      await _tap(tester, find.text('Between my accounts'));
      await _tap(tester, _inSheet(find.text('HDFC ··4821')).first);
      await _tap(tester, _inSheet(find.text('Emergency savings')).last);
      await _tap(tester, _inSheet(find.widgetWithText(SkButton, 'Add money')));
      expect(_queued(tester), isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.textContaining('Emergency')), findsOneWidget);
      expect(_inSheet(find.text('To Ladakh trip')), findsOneWidget); // still open
    });

    testWidgets('a contribution edited, then deleted with Undo', (tester) async {
      final be = await pumpApp(tester, location: '/personal/goals/$ladakh', size: tall);
      be.offline = true;
      await _tap(tester, find.bySemanticsLabel('Options for ₹15,000 on Mon, 31 Aug'));
      await _tap(tester, find.text('Edit').last);
      await _type(tester, const Key('contribution-amount'), '14000');
      await _tap(tester, find.widgetWithText(SkButton, 'Save changes'));
      expect(_queued(tester).single.$3!['amount_minor'], 1400000);
      expect(find.text('₹16,000 of ₹60,000'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Options for ₹14,000 on Mon, 31 Aug'));
      await _tap(tester, find.text('Delete').last);
      expect(_queued(tester).last.$1, 'DELETE');
      expect(find.text('₹2,000 of ₹60,000'), findsOneWidget);
      await _tap(tester, find.text('Undo'));
      expect(find.text('₹16,000 of ₹60,000'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('Personal has a Goals tab, unless Features.goals is off', (tester) async {
      await pumpApp(tester, mode: AppMode.personal);
      List<String> tabs() => [for (final d in tester.widget<BottomNav>(find.byType(BottomNav)).destinations) d.key];
      expect(tabs(), ['overview', 'transactions', 'goals', 'insights', 'profile', 'admin']);

      final off = [featuresProvider.overrideWithValue(const Features(goals: false))];
      await pumpApp(tester, mode: AppMode.personal, overrides: off);
      expect(tabs(), ['overview', 'transactions', 'insights', 'profile', 'admin']);
      expect(find.text('All goals'), findsNothing); // nor Overview's card
      appContainer(tester).read(routerProvider).go('/personal/goals/$ladakh');
      await tester.pumpAndSettle();
      expect(find.byType(GoalDetailPage), findsNothing);
      expect(find.text('Only you see this'), findsOneWidget); // back on Overview
    });

    testWidgets("an admin's six Personal tabs fit a 320px phone", (tester) async {
      await pumpApp(tester, mode: AppMode.personal, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final nav = find.byType(BottomNav);
      final pills = find.descendant(of: nav, matching: find.byType(AnimatedContainer));
      expect(pills, findsNWidgets(6));
      final tabWidth = (320 - 16) / 6;
      for (final pill in pills.evaluate()) {
        expect((pill.renderObject! as RenderBox).size.width, lessThanOrEqualTo(tabWidth));
      }
    });

    testWidgets('the rail keeps "Add entry" on Goals', (tester) async {
      await pumpApp(tester, location: '/personal/goals', size: const Size(834, 1112));
      expect(tester.widget<NavRail>(find.byType(NavRail)).addLabel, 'Add entry');
      expect(find.widgetWithText(SkButton, 'New goal'), findsOneWidget);
    });
  });

  group("Overview's goals", () {
    for (final (name, size) in [('a phone', tall), ('a desktop', desktop)]) {
      testWidgets('on $name: the first three active goals, each opening its page', (tester) async {
        await pumpApp(tester, location: '/personal', size: size);
        expect(find.text('All goals'), findsOneWidget);
        expect(find.text('₹17,000 of ₹60,000 · 28%'), findsOneWidget);
        expect(find.text('Gold coins'), findsOneWidget);
        await _tap(tester, find.text('Ladakh trip'));
        expect(find.byType(GoalDetailPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('with none, an offer to set one', (tester) async {
      await pumpApp(tester, backend: _noGoals(), location: '/personal', size: tall);
      expect(find.text('Set a goal'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'New goal'));
      expect(_inSheet(find.text('Add goal')), findsOneWidget);
    });
  });

  group('ActualPlannedBar', () {
    testWidgets('actual is filled, planned only outlined, and both are read out', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ActualPlannedBar(actual: 0.2, planned: 0.5, actualLabel: '₹2,000', plannedLabel: '₹6,500'),
            ),
          ),
        ),
      );
      final actual = tester.widget<Container>(find.byKey(const Key('bar-actual')));
      final planned = tester.widget<Container>(find.byKey(const Key('bar-planned')));
      expect((actual.decoration! as BoxDecoration).color, SkColors.personal);
      final outline = planned.decoration! as BoxDecoration;
      expect((outline.color, outline.border!.top.width, outline.border!.top.color), (null, 1.5, SkColors.personal));
      expect(tester.getSize(find.byKey(const Key('bar-actual'))).width, 60);
      expect(find.bySemanticsLabel('Saved ₹2,000'), findsOneWidget);
      expect(find.bySemanticsLabel('Planned ₹6,500, not yet saved'), findsOneWidget);
      handle.dispose();
    });
  });
}
