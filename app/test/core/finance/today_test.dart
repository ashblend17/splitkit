import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/clock.dart';
import 'package:app/core/finance/today.dart';

/// TodayTicker (core/finance/today.dart): today moves at local midnight while the ticker is in
/// the tree, and its timer goes away with it.
void main() {
  testWidgets('today moves just after midnight, and the timer stops with the tree', (tester) async {
    final pinned = appClock;
    addTearDown(() => appClock = pinned);
    var now = DateTime(2026, 9, 25, 23, 59, 30);
    appClock = Clock(() => now);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TodayTicker(child: SizedBox()),
      ),
    );
    expect(container.read(todayProvider), 20260925);

    now = DateTime(2026, 9, 26, 0, 0, 1);
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(todayProvider), 20260926);

    // Unmounting cancels the next midnight's timer (the test fails on a pending one).
    await tester.pumpWidget(const SizedBox());
  });

  test('refresh changes nothing on the same day', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(todayProvider);
    var heard = 0;
    container.listen(todayProvider, (_, _) => heard++);
    container.read(todayProvider.notifier).refresh();
    expect((container.read(todayProvider), heard), (first, 0));
  });
}
