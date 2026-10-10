import 'package:clock/clock.dart';

/// Where the app reads the time ("this month", "today", relative dates). The system clock,
/// except in tests, which pin it to the day their fixtures were captured
/// (test/flutter_test_config.dart).
Clock appClock = const Clock();
