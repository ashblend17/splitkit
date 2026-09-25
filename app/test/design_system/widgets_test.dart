import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/splits/split_engine.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/gallery/components_gallery_page.dart';

import '../helpers.dart';

const _you = SkPerson(id: 'you', name: 'You', initials: 'AC');
const _rahul = SkPerson(id: 'rahul', name: 'Rahul');
const _aman = SkPerson(id: 'aman', name: 'Aman');
const _vivek = SkPerson(id: 'vivek', name: 'Vivek');

void main() {
  setUpAll(loadFonts);

  for (final size in const [Size(1440, 3600), Size(834, 5000), Size(390, 9000)]) {
    testWidgets('gallery renders without overflow at ${size.width.toInt()}px', (tester) async {
      setViewport(tester, size);
      await tester.pumpWidget(MaterialApp(theme: buildSplitkitTheme(), home: const ComponentsGalleryPage()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Components'), findsOneWidget);
      expect(find.text('Split is valid'), findsWidgets);
      expect(find.text('₹100 still needs to be allocated'), findsOneWidget);
    });
  }

  testWidgets('SplitSelector validates live as you type', (tester) async {
    setViewport(tester, const Size(430, 1400));
    final controller = SplitController(
      people: const [_you, _rahul, _aman, _vivek],
      totalMinor: 180000,
      values: {
        'exact': {'you': '600', 'rahul': '400', 'aman': '500', 'vivek': '200'},
      },
    );
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            SplitSelector(controller: controller, payerId: 'rahul', payerName: 'Rahul'),
            SplitSummary(controller: controller),
          ],
        ),
      ),
    );

    expect(find.text('₹450'), findsNWidgets(4));
    expect(find.text('Split is valid'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last); // untick Vivek
    await tester.pump();
    expect(find.text('₹600'), findsNWidgets(3));
    expect(find.text('Not involved'), findsOneWidget);

    await tester.tap(find.text('Exact'));
    await tester.pump();
    expect(find.text('₹100 still needs to be allocated'), findsOneWidget);
    expect(find.text('Paid the bill'), findsOneWidget);
    expect(find.text('Owes Rahul'), findsNWidgets(3));

    await tester.enterText(find.byType(TextField).first, '700');
    await tester.pump();
    expect(find.text('Split is valid'), findsOneWidget);
    expect(controller.shares!.map((s) => s.shareMinor), [70000, 40000, 50000, 20000]);

    await tester.enterText(find.byType(TextField).first, '800');
    await tester.pump();
    expect(find.text('₹100 over the total — reduce someone'), findsOneWidget);

    await tester.tap(find.text('Percent'));
    await tester.pump();
    expect(find.textContaining('100% (₹1,800) still needs'), findsOneWidget);
  });

  testWidgets('split tabs come from the registry', (tester) async {
    await tester.pumpWidget(
      wrap(
        SplitMethodTabs(
          methods: splitRegistry.all,
          selected: 'equal',
          onSelected: (_) {},
          style: SplitTabsStyle.inline,
        ),
      ),
    );
    for (final label in ['= Equal', '₹ Exact', '% Percent', '× Shares']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('BalanceCard words follow the sign', (tester) async {
    for (final (net, words) in [
      (115000, 'Overall, you are owed'),
      (-5000, 'Overall, you owe'),
      (0, "You're all settled up"),
    ]) {
      await tester.pumpWidget(wrap(BalanceCard(netMinor: net, youOweMinor: 0, youAreOwedMinor: 0)));
      expect(find.text(words), findsOneWidget);
    }
  });

  testWidgets('AmountInput groups digits the Indian way and reports minor units', (tester) async {
    int? value;
    await tester.pumpWidget(wrap(AmountInput(onChanged: (m) => value = m)));
    await tester.enterText(find.byType(TextField), '180000.5');
    await tester.pump();
    expect(find.text('1,80,000.5'), findsOneWidget);
    expect(value, 18000050);
  });

  testWidgets('TransactionCard reads as one sentence to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const TransactionCard(
          title: 'Dinner at Thalassa',
          subtitle: 'Rahul paid ₹1,800 · split 4 ways',
          tag: 'Goa Trip',
          when: '9:40 PM',
          label: 'you owe',
          amount: '₹450',
          glyph: 'food',
          tone: MoneyTone.owe,
          adminBadge: true,
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Dinner at Thalassa. Rahul paid ₹1,800 · split 4 ways. you owe ₹450. Edited by an admin'),
      findsOneWidget,
    );
    expect(find.text('Admin'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('bottom nav adds Admin only for admins', (tester) async {
    await tester.pumpWidget(
      wrap(BottomNav(destinations: NavDestination.primary(), current: 'home', onSelected: (_) {})),
    );
    expect(find.text('Admin'), findsNothing);
    await tester.pumpWidget(
      wrap(BottomNav(destinations: NavDestination.primary(admin: true), current: 'admin', onSelected: (_) {})),
    );
    expect(find.text('Admin'), findsOneWidget);
  });

  test('initials and stable avatar colours', () {
    expect(initialsFor('Ansh C'), 'AC');
    expect(initialsFor('Vivek Iyer'), 'VI');
    expect(initialsFor('Priya'), 'PR');
    expect(SkAvatarColors.forId('abc'), SkAvatarColors.forId('abc'));
  });

  test('every glyph used by navigation and categories exists', () {
    for (final g in [
      'home',
      'groups',
      'wallet',
      'user',
      'shield',
      'food',
      'transport',
      'shopping',
      'entertainment',
      'travel',
      'rent',
      'bills',
      'health',
      'income',
      'other',
    ]) {
      expect(SkIcon.has(g), isTrue, reason: g);
    }
  });
}
