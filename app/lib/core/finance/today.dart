/// Today, for every view that depends on the date (goals' months left, behind, overdue): one
/// provider that moves at local midnight and when the app comes back to the foreground, so no
/// view reads DateTime.now() itself and each is worked out again only when the day changes.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock.dart';
import 'model.dart' show dayKeyOf;

export 'model.dart' show dayKeyOf, daysBetween;

/// Today as a day key (20260925), from appClock (pinned in tests).
final todayProvider = NotifierProvider<TodayController, int>(TodayController.new);

/// Keeps [todayProvider] on today: a timer to just after the next local midnight, and a check
/// when the app resumes (a phone asleep over midnight fires no timer).
class TodayController extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    final lifecycle = _listen();
    ref.onDispose(() {
      _timer?.cancel();
      lifecycle?.dispose();
    });
    return _schedule();
  }

  /// A listener for the app coming back, or null where there's no Flutter binding (plain Dart
  /// tests).
  AppLifecycleListener? _listen() {
    try {
      WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
    return AppLifecycleListener(onResume: _refresh);
  }

  /// Today's key, with the timer set for the next midnight.
  int _schedule() {
    _timer?.cancel();
    final now = appClock.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), _refresh);
    return dayKeyOf(now);
  }

  void _refresh() {
    final today = _schedule();
    if (today != state) state = today;
  }
}
