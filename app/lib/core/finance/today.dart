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

/// Today as a day key (20260925), from appClock (pinned in tests). [TodayTicker], at the app's
/// root, moves it at local midnight and when the app comes back.
final todayProvider = NotifierProvider<TodayController, int>(TodayController.new);

class TodayController extends Notifier<int> {
  @override
  int build() => dayKeyOf(appClock.now());

  /// Moves to today if the day has changed (listeners only hear of a new day).
  void refresh() {
    final today = dayKeyOf(appClock.now());
    if (today != state) state = today;
  }
}

/// Keeps [todayProvider] on today while it's in the tree: a timer to just after the next local
/// midnight, and a check when the app resumes (a phone asleep over midnight fires no timer). A
/// widget rather than the provider owns the timer, so it stops when the app (or a test's tree)
/// goes away.
class TodayTicker extends ConsumerStatefulWidget {
  const TodayTicker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TodayTicker> createState() => _TodayTickerState();
}

class _TodayTickerState extends ConsumerState<TodayTicker> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _tick);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = appClock.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), _tick);
  }

  void _tick() {
    ref.read(todayProvider.notifier).refresh();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
