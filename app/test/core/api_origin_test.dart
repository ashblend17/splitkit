import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/fixed_names.dart';
import 'package:app/core/session/session.dart';

import '../fake_backend.dart';

void main() {
  test('normalizeApiOrigin keeps scheme, host and port only', () {
    expect(normalizeApiOrigin(' http://10.0.2.2:8000/ '), 'http://10.0.2.2:8000');
    expect(normalizeApiOrigin('https://api.example.com/api/v1'), 'https://api.example.com');
    expect(normalizeApiOrigin('192.168.1.20:8000'), isNull);
    expect(normalizeApiOrigin('ftp://host'), isNull);
    expect(normalizeApiOrigin(''), isNull);
  });

  test('switching servers logs out, saves the choice and sends requests there', () async {
    SharedPreferences.setMockInitialValues({FixedNames.token: 'old-token'});
    final hosts = <String>[];
    final container = ProviderContainer(overrides: [
      httpClientProvider.overrideWithValue(MockClient((req) async {
        hosts.add(req.url.authority);
        return http.Response('{"error":{"code":"unauthorized","message":"Log in again"}}', 401);
      })),
    ]);
    addTearDown(container.dispose);

    await container.read(apiOriginProvider.notifier).set('http://192.168.1.20:8000');

    expect(container.read(apiOriginProvider), 'http://192.168.1.20:8000');
    expect(container.read(apiOriginProvider.notifier).isOverridden, isTrue);
    expect(await ApiOriginStore().read(), 'http://192.168.1.20:8000');
    expect(await TokenStore().read(), isNull);
    expect(container.read(sessionProvider).value, isNull);

    await expectLater(container.read(sessionProvider.notifier).login('a@b.co', 'pw'), throwsA(anything));
    expect(hosts, ['192.168.1.20:8000']);

    await container.read(apiOriginProvider.notifier).set(null);
    expect(container.read(apiOriginProvider.notifier).isOverridden, isFalse);
    expect(await ApiOriginStore().read(), isNull);
  });

  test('a server saved on an earlier launch is used from the start', () {
    final container = ProviderContainer(overrides: [savedApiOriginProvider.overrideWithValue('http://10.0.2.2:8000')]);
    addTearDown(container.dispose);
    expect(container.read(apiOriginProvider), 'http://10.0.2.2:8000');
  });

  testWidgets('login screen shows the server link in debug builds', (tester) async {
    await pumpApp(tester, token: null);
    expect(find.text('Server: this site'), findsOneWidget);
  });
}
