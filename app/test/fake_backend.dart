import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/router/router.dart';
import 'package:splitkit/features/shell/app_mode.dart';
import 'package:splitkit/features/shell/sync_banner.dart';
import 'package:splitkit/features/sms/sms_source.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/theme/theme_mode.dart';

import 'fake_sms.dart';

dynamic fixture(String name) => jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());

/// Serves the captured API fixtures for GETs and records writes, so screens can be tested
/// with real response shapes and no server.
class FakeBackend {
  FakeBackend() {
    final groups = fixture('groups') as List;
    goa = groups.firstWhere((g) => g['name'] == 'Goa Trip') as Map<String, dynamic>;
    final expense = fixture('expense') as Map<String, dynamic>;
    dinnerId = expense['id'] as String;
    final plan = fixture('settle_up_plan') as Map<String, dynamic>;
    friendId = (plan['friend'] as Map)['id'] as String;
    get = {
      '/api/v1/me': (fixture('login') as Map)['user'],
      '/api/v1/groups': groups,
      for (final g in groups) '/api/v1/groups/${(g as Map)['id']}': g,
      '/api/v1/balances': fixture('balances'),
      '/api/v1/groups/${goa['id']}/balances': fixture('group_balances'),
      '/api/v1/feed': fixture('feed'),
      '/api/v1/expenses/$dinnerId': expense,
      '/api/v1/expenses/$dinnerId/history': <dynamic>[],
      '/api/v1/categories': fixture('categories'),
      '/api/v1/splits/methods': fixture('split_methods'),
      '/api/v1/friends/$friendId/settle-up': plan,
      '/api/v1/categories?scope=personal': fixture('personal_categories'),
      '/api/v1/categories?': [...fixture('categories') as List, ...fixture('personal_categories') as List],
      '/api/v1/personal/summary': fixture('personal_summary'),
      '/api/v1/personal/transactions': fixture('personal_list'),
      '/api/v1/analytics/personal': fixture('analytics_personal'),
      '/api/v1/analytics/groups/${goa['id']}': fixture('analytics_group'),
      '/api/v1/analytics/layout/personal': fixture('analytics_layout'),
    };
  }

  late final Map<String, dynamic> goa;
  late final String dinnerId;
  /// Vivek, whose settle-up plan is the fixture.
  late final String friendId;
  late final Map<String, dynamic> get;
  final writes = <(String method, String path, Map<String, dynamic> body)>[];
  final gets = <Uri>[];
  Map<String, (int, Object)> postResponses = {};

  /// Every stream the seeded user can see, as captured from the API (tool/capture_api_fixtures.py).
  /// Screens read from the local store, which syncs from these.
  late final Map<String, dynamic> snapshots = syncFixture('john');

  /// The seed without its allocation rules (its plans stay), for tests of writes that a rule
  /// pointing at the seed's Ladakh trip or Emergency savings would refuse (rule_points_here), or
  /// whose incomes would otherwise get plans.
  FakeBackend withoutAllocationRules() {
    for (final s in snapshots.values) {
      ((s as Map)['entities'] as List).removeWhere((e) => (e as Map)['entity'] == 'personal_allocation_rule');
    }
    return this;
  }

  /// Other users' streams, by bearer token (view-as tests serve Rahul's to the view-as token).
  final snapshotsByToken = <String, Map<String, dynamic>>{};

  static Map<String, dynamic> syncFixture(String user) =>
      ((jsonDecode(File('test/fixtures/sync/$user.json').readAsStringSync()) as Map)['snapshots'] as Map).cast();

  Map<String, dynamic> _snapshotsFor(http.Request req) {
    final token = (req.headers['Authorization'] ?? req.headers['authorization'] ?? '').replaceFirst('Bearer ', '');
    return snapshotsByToken[token] ?? snapshots;
  }

  /// Changes to hand out on the next POST /sync, per stream (seq must follow the snapshot's head).
  final pendingChanges = <String, List<Map<String, dynamic>>>{};
  int syncCalls = 0;

  http.Response _json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  http.Response _sync(http.Request req) {
    syncCalls++;
    final cursors = ((jsonDecode(req.body) as Map)['cursors'] as Map? ?? {}).cast<String, dynamic>();
    return _json({
      'streams': [
        for (final s in _snapshotsFor(req).entries)
          () {
            final head = s.value['head_seq'] as int;
            final changes = pendingChanges[s.key] ?? const [];
            final cursor = cursors[s.key] as int?;
            if (cursor == null) return {'stream': s.key, 'status': 'snapshot_required', 'head_seq': head, 'changes': [], 'has_more': false};
            final fresh = [for (final c in changes) if ((c['seq'] as int) > cursor) c];
            return {'stream': s.key, 'status': 'ok', 'head_seq': head + changes.length, 'changes': fresh, 'has_more': false};
          }(),
      ],
    });
  }

  /// Every request fails as if there were no network.
  bool offline = false;

  /// What POST /auth/refresh hands out (by default the same token back).
  String? refreshTo;

  http.Client get client => MockClient((req) async {
        if (offline) throw http.ClientException('Network is unreachable', req.url);
        final path = req.url.path;
        if (path == '/api/v1/sync') return _sync(req);
        if (path == '/api/v1/auth/refresh') {
          final token = (req.headers['Authorization'] ?? '').replaceFirst('Bearer ', '');
          return _json({...fixture('login') as Map, 'access_token': refreshTo ?? token});
        }
        if (path.startsWith('/api/v1/sync/snapshot/')) {
          final snap = _snapshotsFor(req)[Uri.decodeComponent(path.substring('/api/v1/sync/snapshot/'.length))];
          return snap == null ? _json({'error': {'code': 'not_found', 'message': 'Not found'}}, 404) : _json(snap);
        }
        if (req.method == 'GET') {
          gets.add(req.url);
          final scoped = req.url.queryParameters['scope'];
          final body = get['$path?${scoped == null ? '' : 'scope=$scoped'}'] ?? get[path];
          if (body == null) return http.Response('{"error":{"code":"not_found","message":"Not found"}}', 404);
          return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
        }
        final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
        writes.add((req.method, path, body));
        final (status, response) = postResponses[path] ?? (200, <String, dynamic>{});
        return http.Response.bytes(utf8.encode(jsonEncode(response)), status, headers: {'content-type': 'application/json'});
      });
}

var _databases = 0;

/// The token (and saved user) in memory. Pass the same one to two `pumpApp` calls to simulate
/// a restart.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore(this.token);
  String? token;
  UserOut? user;

  @override
  Future<UserOut?> readUser() async => user;
  @override
  Future<void> writeUser(UserOut u) async => user = u;

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

/// Keeps the Split / Personal choice in memory instead of SharedPreferences.
class MemoryThemeStore implements ThemeModeStore {
  MemoryThemeStore([this.mode]);
  ThemeMode? mode;

  @override
  Future<ThemeMode?> read() async => mode;

  @override
  Future<void> write(ThemeMode mode) async => this.mode = mode;
}

class MemoryModeStore implements AppModeStore {
  MemoryModeStore([this.mode]);
  AppMode? mode;

  @override
  Future<AppMode?> read() async => mode;

  @override
  Future<void> write(AppMode mode) async => this.mode = mode;
}

/// Pumps the whole app (router, shell, theme) at a phone size unless [size] says otherwise,
/// signed in unless [token] is null. [mode] is the mode saved from last time; [modes] sees
/// what the app saves. Without [settle], it stops after the first frame.
Future<FakeBackend> pumpApp(
  WidgetTester tester, {
  String? location,
  String? token = 'test-token',
  FakeBackend? backend,
  Size size = const Size(390, 844),
  String? database,
  TokenStore? tokens,
  http.Client? client,
  List<Override> overrides = const [],
  Duration? syncInterval,
  AppMode mode = AppMode.split,
  MemoryModeStore? modes,
  ThemeMode theme = ThemeMode.system,
  MemoryThemeStore? themes,
  SmsSource? sms,
  bool settle = true,
}) async {
  final be = backend ?? FakeBackend();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(client ?? be.client),
      tokenStoreProvider.overrideWithValue(tokens ?? MemoryTokenStore(token)),
      localDatabaseFactoryProvider.overrideWithValue(databaseFactoryMemory),
      localDatabasePathProvider.overrideWithValue((userId) async => database ?? 'test-${_databases++}-$userId'),
      syncIntervalProvider.overrideWithValue(syncInterval), // no timer unless asked for
      savedAppModeProvider.overrideWithValue(mode),
      appModeStoreProvider.overrideWithValue(modes ?? MemoryModeStore(mode)),
      savedThemeModeProvider.overrideWithValue(theme),
      themeModeStoreProvider.overrideWithValue(themes ?? MemoryThemeStore(theme)),
      // No phone inbox unless a test brings one (tests run as Android).
      smsSourceProvider.overrideWithValue(sms ?? FakeSmsSource()),
      ...overrides,
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: SkThemedApp(routerConfig: router, builder: appChrome),
  ));
  if (!settle) return be;
  await tester.pumpAndSettle();
  if (location != null) {
    router.go(location);
    await tester.pumpAndSettle();
  }
  return be;
}

/// The provider container behind the app [pumpApp] built.
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// Runs a write started from the test body. Widget tests run on a fake clock and the local
/// database waits on timers, so keep pumping until it finishes.
Future<T> runWrite<T>(WidgetTester tester, Future<T> write) async {
  var done = false;
  Object? error;
  late T value;
  write.then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!done) throw StateError('write did not finish');
  if (error != null) throw error!;
  await tester.pumpAndSettle();
  return value;
}
