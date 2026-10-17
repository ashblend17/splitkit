/// On-device timing (Phase 0): the app over the heavy dataset (test/perf/heavy_data.dart, about
/// five years of use) in a real store on the device's disk, with a fake API and a fake SMS inbox.
/// Three actions are traced, and the host (test_driver/perf_driver.dart) reports their frame build
/// and raster times and missed frames:
///
/// - `cold_start`: from a new app (session restored, store opened from disk, Ledger built) to
///   Overview showing this month's numbers. The process is already running, so this is the app's
///   part of a cold start, not the engine's.
/// - `scroll_transactions`: Transactions, flung from the top to the last entry of the month, its
///   pages loading on the way.
/// - `sms_first_read`: turning bank SMS on with 2,000 messages in the inbox, until what it found is
///   queued and Overview shows it.
///
/// Run it in profile mode on a phone (validation.md, "On-device timing"); it isn't part of
/// `flutter test`, which runs only test/.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart' show databaseFactoryIo;
import 'package:splitkit/core/clock.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/store.dart';
import 'package:splitkit/core/router/router.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/theme/theme_mode.dart';
import 'package:splitkit/features/personal/personal_history_page.dart';
import 'package:splitkit/features/shell/app_mode.dart';
import 'package:splitkit/features/sms/sms_importer.dart';
import 'package:splitkit/features/sms/sms_source.dart';
import 'package:splitkit/main.dart';

import '../test/fake_backend.dart' show MemoryModeStore, MemoryThemeStore, MemoryTokenStore;
import '../test/fake_sms.dart';
import '../test/perf/heavy_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Frames as the engine asks for them, as in the app, rather than only when the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // The heavy data ends on this day: Overview's month and Transactions' range are around it.
  appClock = Clock.fixed(DateTime(heavyEnd.year, heavyEnd.month, heavyEnd.day, 12));

  late HeavyData data;
  late String path;
  final wall = <String, int>{};
  final counts = <String, Object>{};

  setUpAll(() async {
    data = buildHeavyData();
    // The device store, written once: every stream at seq 100, as after a sync.
    final dir = Directory('${(await getTemporaryDirectory()).path}/splitkit-perf');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    path = '${dir.path}/u_${data.me}.db';
    final store = await LocalStore.open(databaseFactoryIo, path);
    final byStream = <String, List<LocalEntity>>{};
    for (final e in data.entities) {
      (byStream[e.stream] ??= []).add(e);
    }
    for (final MapEntry(key: stream, value: entities) in byStream.entries) {
      await store.replaceStream(stream, 100, entities);
    }
    await store.close();
    counts['entities'] = data.entities.length;
    counts['store_mb'] = (File(path).lengthSync() / 1048576).toStringAsFixed(1);
  });

  testWidgets('cold start, scrolling Transactions, a first read of 2,000 bank SMS', (tester) async {
    final profile = data.entities.firstWhere((e) => e.entity == 'profile').data;
    final sms = FakeSmsSource(available: true, access: true, inbox: heavySms(data));
    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(_api(profile)),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore('perf-token')),
        localDatabasePathProvider.overrideWithValue((_) async => path),
        syncIntervalProvider.overrideWithValue(null),
        savedAppModeProvider.overrideWithValue(AppMode.personal),
        appModeStoreProvider.overrideWithValue(MemoryModeStore(AppMode.personal)),
        savedThemeModeProvider.overrideWithValue(ThemeMode.light),
        themeModeStoreProvider.overrideWithValue(MemoryThemeStore(ThemeMode.light)),
        smsSourceProvider.overrideWithValue(sms),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    // 1. Cold start: the app, as main() starts it, to Overview's numbers for the month.
    await binding.traceAction(() async {
      final s = Stopwatch()..start();
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SplitkitApp()));
      await _pumpUntil(tester, find.textContaining('Spent in'));
      wall['cold_start_to_overview'] = s.elapsedMilliseconds;
    }, reportKey: 'cold_start');
    await tester.pumpAndSettle();

    // 2. Transactions, top to bottom.
    container.read(routerProvider).go('/personal/transactions');
    await _pumpUntil(tester, find.text('Per day'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byType(PersonalHistoryPage),
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
        )
        .first;
    final position = tester.state<ScrollableState>(list).position;
    await binding.traceAction(() async {
      final s = Stopwatch()..start();
      var flings = 0;
      for (var still = 0; still < 3 && flings < 300; flings++) {
        final end = position.maxScrollExtent;
        await tester.fling(list, const Offset(0, -900), 4000);
        await tester.pumpAndSettle();
        final atEnd = position.pixels >= position.maxScrollExtent - 1;
        final allLoaded = find.textContaining('Showing the newest').evaluate().isEmpty;
        still = atEnd && allLoaded && position.maxScrollExtent == end ? still + 1 : 0;
      }
      wall['scroll_transactions'] = s.elapsedMilliseconds;
      counts['flings'] = flings;
      counts['scrolled_px'] = position.pixels.round();
    }, reportKey: 'scroll_transactions');

    // 3. A first read of the inbox, from Overview.
    container.read(routerProvider).go('/personal');
    await tester.pumpAndSettle();
    final ops = (await container.read(localStoreProvider.future)).outbox.length;
    await binding.traceAction(() async {
      final s = Stopwatch()..start();
      final read = container.read(smsImporterProvider).setUp(heavyEnd.subtract(const Duration(days: 200)));
      SmsScan? found;
      unawaited(read.then((r) => found = r));
      while (found == null) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      wall['sms_first_read'] = s.elapsedMilliseconds;
      counts['sms'] = {'messages': sms.messages.length, 'added': found!.added, 'attached': found!.attached};
      await tester.pumpAndSettle();
      wall['sms_first_read_settled'] = s.elapsedMilliseconds;
    }, reportKey: 'sms_first_read');
    expect((counts['sms']! as Map)['added'], greaterThan(1500), reason: 'the inbox was read');
    expect((await container.read(localStoreProvider.future)).outbox.length, greaterThan(ops));

    binding.reportData = {...?binding.reportData, 'wall_clock_ms': wall, 'counts': counts};
    debugPrint('perf_test wall clock (ms): ${jsonEncode(wall)}; ${jsonEncode(counts)}');
  });
}

/// Pumps frames until [finder] finds something (or a minute passes).
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final s = Stopwatch()..start();
  while (finder.evaluate().isEmpty) {
    if (s.elapsed > const Duration(minutes: 1)) throw TimeoutException('Waiting for $finder', s.elapsed);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The API, as far as these actions need it: the session (restored and refreshed) and a sync with
/// nothing new. Anything else fails as if offline, so writes (the SMS read's) stay queued.
http.Client _api(Map<String, dynamic> user) => MockClient((req) async {
  http.Response json(Object body) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
  switch (req.url.path) {
    case '/api/v1/me':
      return json(user);
    case '/api/v1/auth/refresh':
      return json({'access_token': 'perf-token', 'token_type': 'bearer', 'expires_in': 604800, 'user': user});
    case '/api/v1/sync':
      final cursors = ((jsonDecode(req.body) as Map)['cursors'] as Map).cast<String, dynamic>();
      return json({
        'streams': [
          for (final MapEntry(key: stream, value: seq) in cursors.entries)
            {'stream': stream, 'status': 'ok', 'head_seq': seq, 'changes': [], 'has_more': false},
        ],
      });
  }
  throw http.ClientException('offline', req.url);
});
