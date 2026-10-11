import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/splits/split_engine.dart';
import 'package:splitkit/core/money/money.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/gallery/components_gallery_page.dart';

import '../helpers.dart';

const _you = SkPerson(id: 'you', name: 'You', initials: 'JD');
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

    // Shares start at one each for whoever was ticked (not Vivek).
    await tester.tap(find.text('Shares'));
    await tester.pump();
    expect(find.text('3 shares'), findsOneWidget);
    expect(find.text('Split is valid'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.pump();
    expect(controller.shares!.map((s) => s.shareMinor), [90000, 45000, 45000, 0]);
  });

  testWidgets("the highlighted bar's figure stays inside a narrow chart", (tester) async {
    setViewport(tester, const Size(330, 400));
    await tester.pumpWidget(
      wrap(
        TrendBars(
          bars: [
            for (var i = 0; i < 12; i++) (label: 'M$i', value: i == 11 ? 25050 : 3000000, highlight: i == 11),
          ],
          formatTop: (v) => '₹250.50',
          formatTip: (b) => b.label,
        ),
      ),
    );
    final chart = tester.getRect(find.byType(TrendBars));
    final label = tester.getRect(find.text('₹250.50'));
    expect(label.width, greaterThan(30), reason: 'laid out whole, not squeezed into the bar and painted past it');
    expect(label.right, lessThanOrEqualTo(chart.right));
    expect(label.left, greaterThanOrEqualTo(chart.left));
  });

  testWidgets('22 month bars on a phone: whole labels every few bars, none clipped', (tester) async {
    setViewport(tester, const Size(360, 400));
    final labels = ['2025', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      '2026', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'];
    await tester.pumpWidget(
      wrap(
        TrendBars(
          bars: [for (final (i, l) in labels.indexed) (label: l, value: 1000 + i, highlight: false)],
          formatTop: (v) => '$v',
          formatTip: (b) => b.label,
        ),
      ),
    );
    final shown = tester.widgetList<Text>(find.descendant(of: find.byType(TrendBars), matching: find.byType(Text)));
    expect(shown.length, lessThan(labels.length), reason: 'some labels skipped');
    expect(find.text('2025'), findsOneWidget);
    final chart = tester.getRect(find.byType(TrendBars));
    for (final t in shown) {
      final r = tester.getRect(find.byWidget(t));
      expect(r.width, greaterThanOrEqualTo(14), reason: '"${t.data}" laid out whole');
      expect((r.left >= chart.left - 0.5, r.right <= chart.right + 0.5), (true, true), reason: '"${t.data}" inside the chart');
    }
  });

  testWidgets('breakdown amounts stay on one line, all the same width', (tester) async {
    setViewport(tester, const Size(360, 400));
    await tester.pumpWidget(
      wrap(
        BreakdownBars(
          rows: const [(label: 'Rent', value: 41094505), (label: 'Uncategorised', value: 500)],
          format: (v) => formatMinor(v, currency: 'INR'),
        ),
      ),
    );
    final big = tester.getSize(find.text('₹4,10,945.05'));
    expect(big.height, lessThan(24), reason: 'one line');
    expect(tester.getSize(find.text('₹5')).width, big.width);
    final label = tester.renderObject<RenderParagraph>(find.text('Uncategorised'));
    expect(label.didExceedMaxLines, isFalse, reason: 'not cut short');
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

  testWidgets('BalanceCard: nothing either way is grey, and huge amounts stay on one line', (tester) async {
    setViewport(tester, const Size(360, 800));
    await tester.pumpWidget(wrap(const BalanceCard(netMinor: -999999999999, youOweMinor: 999999999999, youAreOwedMinor: 0)));
    Color colorOf(String text) => tester.widget<Text>(find.text(text).last).style!.color!; // the tile
    expect(colorOf('₹0'), SkColors.ink2);
    expect(colorOf('₹9,99,99,99,999.99'), SkColors.owe);
    expect(tester.getSize(find.text('₹9,99,99,99,999.99').last).height, lessThan(40), reason: 'one line');
  });

  testWidgets('AmountInput groups digits the Indian way and reports minor units', (tester) async {
    int? value;
    await tester.pumpWidget(wrap(AmountInput(onChanged: (m) => value = m)));
    await tester.enterText(find.byType(TextField), '180000.5');
    await tester.pump();
    expect(find.text('1,80,000.5'), findsOneWidget);
    expect(value, 18000050);
  });

  testWidgets('AmountInput groups dollars in thousands and stops at the largest amount', (tester) async {
    int? value;
    await tester.pumpWidget(wrap(AmountInput(currency: 'USD', onChanged: (m) => value = m)));
    await tester.enterText(find.byType(TextField), '180000');
    await tester.pump();
    expect(find.text('180,000'), findsOneWidget);
    expect(value, 18000000);
    await tester.enterText(find.byType(TextField), '1234567890123');
    await tester.pump();
    expect(find.text('180,000'), findsOneWidget, reason: 'more than 8 whole digits is ignored');
  });

  test('split values keep to what the API stores', () {
    String type(TextInputFormatter f, String before, String after) => f
        .formatEditUpdate(TextEditingValue(text: before), TextEditingValue(text: after))
        .text;
    const percent = SplitValueFormatter(whole: 6, places: 4);
    expect(type(percent, '33.333', '33.3333'), '33.3333');
    expect(type(percent, '33.3333', '33.33333'), '33.3333', reason: 'a fifth decimal is ignored');
    expect(type(percent, '1', '1.2.'), '1', reason: 'one decimal point');
    const exact = SplitValueFormatter(whole: 8, places: 2);
    expect(type(exact, '', '1,234.5'), '1234.5');
    expect(type(exact, '12.34', '12.345'), '12.34');
  });

  testWidgets('AmountInput shrinks long amounts so they still fit', (tester) async {
    await tester.pumpWidget(wrap(const AmountInput()));
    double size() => tester.widget<EditableText>(find.byType(EditableText)).style.fontSize!;
    await tester.enterText(find.byType(TextField), '500');
    await tester.pump();
    expect(size(), 56);
    await tester.enterText(find.byType(TextField), '99999999.99');
    await tester.pump();
    expect(find.text('9,99,99,999.99'), findsOneWidget);
    expect(size(), 28);
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
    expect(initialsFor('John Doe'), 'JD');
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
