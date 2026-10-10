import 'dart:async';

import 'package:clock/clock.dart';
import 'package:splitkit/core/clock.dart';

/// The day the fixtures in test/fixtures were captured. Screens default to "this month" and
/// "today", so every test runs on this day whatever the real date is.
final fixtureDay = DateTime(2026, 9, 25, 12);

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  appClock = Clock.fixed(fixtureDay);
  await testMain();
}
