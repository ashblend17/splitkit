import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:splitkit/core/router/router.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/theme/theme.dart';

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
    amanId = (plan['friend'] as Map)['id'] as String;
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
      '/api/v1/friends/$amanId/settle-up': plan,
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
  late final String amanId;
  late final Map<String, dynamic> get;
  final writes = <(String method, String path, Map<String, dynamic> body)>[];
  final gets = <Uri>[];
  Map<String, (int, Object)> postResponses = {};

  http.Client get client => MockClient((req) async {
        final path = req.url.path;
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

class _MemoryTokenStore extends TokenStore {
  _MemoryTokenStore(this.token);
  String? token;

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

/// Pumps the whole app (router, shell, theme) at a phone size unless [size] says otherwise,
/// signed in unless [token] is null.
Future<FakeBackend> pumpApp(
  WidgetTester tester, {
  String? location,
  String? token = 'test-token',
  FakeBackend? backend,
  Size size = const Size(390, 844),
}) async {
  final be = backend ?? FakeBackend();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(be.client),
      tokenStoreProvider.overrideWithValue(_MemoryTokenStore(token)),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: buildSplitkitTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  if (location != null) {
    router.go(location);
    await tester.pumpAndSettle();
  }
  return be;
}
