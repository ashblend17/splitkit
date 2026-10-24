import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/splits/split_engine.dart';
import 'package:app/core/money/money.dart';
import 'package:app/core/theme/theme.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/gallery/components_gallery_page.dart';

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
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const ComponentsGalleryPage()));
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

  testWidgets('tapping a name with everyone ticked splits with only them; the checkbox still ticks one', (tester) async {
    setViewport(tester, const Size(430, 1400));
    final controller = SplitController(people: const [_you, _rahul, _aman, _vivek], totalMinor: 180000);
    await tester.pumpWidget(wrap(SplitSelector(controller: controller)));
    final ticked = [_you, _rahul, _aman, _vivek].where((p) => controller.isIncluded(p.id)).map((p) => p.id);

    await tester.tap(find.text('Rahul'));
    await tester.pump();
    expect(ticked, ['rahul']);
    expect(find.text('₹1,800'), findsOneWidget);
    expect(find.text('Not involved'), findsNWidgets(3));

    // From there each tap adds or removes one person.
    await tester.tap(find.text('You'));
    await tester.pump();
    expect(ticked, ['you', 'rahul']);
    await tester.tap(find.text('Rahul'));
    await tester.pump();
    expect(ticked, ['you']);

    // Everyone ticked again: a name tap narrows it down again.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.tap(find.byType(Checkbox).at(3));
    await tester.pump();
    expect(ticked, ['you', 'rahul', 'aman', 'vivek']);
    await tester.tap(find.text('Aman'));
    await tester.pump();
    expect(ticked, ['aman']);

    // A checkbox first leaves the others ticked, and a name tap after it ticks or unticks one.
    for (final p in const [_you, _rahul, _vivek]) {
      controller.toggle(p.id);
    }
    await tester.pump();
    expect(ticked, ['you', 'rahul', 'aman', 'vivek']);
    await tester.tap(find.byType(Checkbox).last); // untick Vivek
    await tester.pump();
    expect(ticked, ['you', 'rahul', 'aman']);
    await tester.tap(find.text('Rahul'));
    await tester.pump();
    expect(ticked, ['you', 'aman']);

    // The other methods' rows are for typing: a tap there changes nothing.
    await tester.tap(find.text('Shares'));
    await tester.pump();
    await tester.tap(find.text('Vivek'));
    await tester.pump();
    expect(ticked, ['you', 'aman']);
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

  testWidgets('tapping a bar shows its amount above it; tapping again puts the chart back', (tester) async {
    setViewport(tester, const Size(360, 400));
    await tester.pumpWidget(
      wrap(
        TrendBars(
          bars: [
            for (var i = 0; i < 12; i++) (label: '${i + 1} Sep', value: i == 3 ? 1916000 : 50000 + i, highlight: i == 3),
          ],
          formatTop: (v) => 'top $v',
          formatTip: (b) => '${b.label}: ₹${b.value ~/ 100}',
        ),
      ),
    );
    expect(find.text('top 1916000'), findsOneWidget); // the highlighted bar, as designed
    final chart = tester.getRect(find.byType(TrendBars));
    // A short bar, tapped near the top of the plot: its whole column counts.
    final short = tester.getRect(find.bySemanticsLabel('8 Sep: ₹500'));
    await tester.tapAt(Offset(short.center.dx, short.top + 4));
    await tester.pump();
    expect(find.text('8 Sep: ₹500'), findsOneWidget);
    expect(find.text('top 1916000'), findsNothing, reason: 'one figure at a time');
    await tester.tapAt(Offset(short.center.dx, short.top + 4));
    await tester.pump();
    expect(find.text('8 Sep: ₹500'), findsNothing);
    expect(find.text('top 1916000'), findsOneWidget);

    // At either end the readout stays inside the chart.
    for (final label in ['1 Sep: ₹500', '12 Sep: ₹500']) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      final pill = tester.getRect(find.text(label));
      expect((pill.left >= chart.left, pill.right <= chart.right), (true, true), reason: label);
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
    }
  });

  testWidgets('pointing at a bar with a mouse shows its amount', (tester) async {
    setViewport(tester, const Size(360, 400));
    await tester.pumpWidget(
      wrap(
        TrendBars(
          bars: [for (var i = 0; i < 5; i++) (label: 'M$i', value: 1000 * (i + 1), highlight: i == 4)],
          formatTop: (v) => 'top $v',
          formatTip: (b) => '${b.label} is ${b.value}',
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.bySemanticsLabel('M1 is 2000')));
    await tester.pump();
    expect(find.text('M1 is 2000'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('M1 is 2000'), findsNothing);
    expect(find.text('top 5000'), findsOneWidget);
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

  testWidgets('breakdown amounts stay on one line, over bars that are all the same length', (tester) async {
    setViewport(tester, const Size(300, 400)); // a card in the carousel on a phone
    await tester.pumpWidget(
      wrap(
        BreakdownBars(
          rows: const [(label: 'Rent', value: 41094505), (label: 'Uncategorised', value: 500)],
          format: (v) => formatMinor(v, currency: 'INR'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final big = tester.getSize(find.text('₹4,10,945.05'));
    expect(big.height, lessThan(24), reason: 'one line');
    final label = tester.renderObject<RenderParagraph>(find.text('Uncategorised'));
    expect(label.didExceedMaxLines, isFalse, reason: 'not cut short');
    // Each bar's track runs the whole row, whatever its amount, so the bars compare.
    final tracks = find.byWidgetPredicate((w) => w is FractionallySizedBox).evaluate().map((e) {
      return tester.getSize(find.byWidget(e.widget).first).width;
    });
    expect(tracks.first, greaterThan(200));
    expect(tracks.last, closeTo(tracks.first * 500 / 41094505, 1));
  });

  testWidgets('figures count up to their amount, at once when the phone asks for no animations', (tester) async {
    String fmt(int v) => formatMinor(v, currency: 'INR');
    Widget money(int v, {bool still = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: wrap(AnimatedMoney(value: v, format: fmt, style: const TextStyle())),
    );
    await tester.pumpWidget(money(220300));
    expect(find.text('₹2,203'), findsNothing, reason: 'still counting');
    await tester.pumpAndSettle();
    expect(find.text('₹2,203'), findsOneWidget);
    expect(find.bySemanticsLabel('₹2,203'), findsOneWidget);
    // Another period: from the old figure to the new one.
    await tester.pumpWidget(money(119100));
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.widget<Text>(find.byType(Text)).data!;
    expect(midway, isNot(anyOf('₹1,191', '₹0')));
    await tester.pumpAndSettle();
    expect(find.text('₹1,191'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(money(220300, still: true));
    await tester.pump();
    expect(find.text('₹2,203'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing moving');
  });

  testWidgets('averages: so far against usual, and how much more when it is over', (tester) async {
    setViewport(tester, const Size(320, 600));
    await tester.pumpWidget(
      wrap(
        AverageBars(
          rows: const [
            (label: 'Food', average: 421800, now: 820800),
            (label: 'Rent', average: 2000000, now: 1500000),
            (label: 'Travel', average: 0, now: 436100),
          ],
          format: (v) => formatMinor(v, currency: 'INR'),
          unit: 'month',
          nowLabel: 'September so far',
          glyphs: (label) => label == 'Food' ? 'food' : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('September so far'), findsOneWidget);
    expect(find.text('Usual month'), findsOneWidget);
    expect(find.text('₹8,208'), findsOneWidget);
    expect(find.text('Usually ₹4,218 · ₹3,990 more', findRichText: true), findsOneWidget);
    expect(find.text('Usually ₹20,000', findRichText: true), findsOneWidget); // under: no "more"
    expect(find.text('Nothing in a usual month', findRichText: true), findsOneWidget);
    expect(
      find.bySemanticsLabel('Food: ₹8,208 September so far, ₹4,218 in a usual month, ₹3,990 more'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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

  testWidgets("both modes' tab bars add Admin only for admins", (tester) async {
    await tester.pumpWidget(
      wrap(BottomNav(destinations: NavDestination.split(), current: 'home', onSelected: (_) {})),
    );
    expect(find.text('Admin'), findsNothing);
    await tester.pumpWidget(
      wrap(BottomNav(destinations: NavDestination.personal(admin: true), current: 'admin', onSelected: (_) {})),
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
      'swap',
      'chart',
      'target',
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
