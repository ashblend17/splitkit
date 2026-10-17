import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/design_system/design_system.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// [inner], with every answer [delay] late, as over a network.
http.Client _slow(http.Client inner, Duration delay) => MockClient((req) async {
  await Future<void>.delayed(delay);
  final copy = http.Request(req.method, req.url)
    ..headers.addAll(req.headers)
    ..bodyBytes = req.bodyBytes;
  return http.Response.fromStream(await inner.send(copy));
});

void main() {
  setUpAll(loadFonts);

  // ISS-038: a browser tab that isn't showing gets no frames. Time passes and timers run, but
  // nothing is built, so what only a screen asks for waits until the tab is shown: reloading
  // /home in a background tab left the store unopened, and the address at /splash, for seconds.
  testWidgets('the device data opens as soon as the session has a user, without waiting for a frame', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, client: _slow(be.client, const Duration(milliseconds: 20)), settle: false);
    final container = appContainer(tester); // the splash, on the first frame
    var waited = Duration.zero;
    Future<void> noFrames(bool Function() until) async {
      while (!until() && waited < const Duration(seconds: 2)) {
        await tester.binding.delayed(const Duration(milliseconds: 10));
        waited += const Duration(milliseconds: 10);
      }
    }

    await noFrames(() => container.read(sessionProvider).value != null);
    expect(container.read(sessionProvider).value, isNotNull, reason: 'the session is restored with no frames');
    expect(container.exists(localStoreProvider), isTrue, reason: 'the store is opened with the session');

    // The first sync too: the data is ready before the tab is shown.
    await noFrames(() => container.exists(ledgerProvider) && container.read(ledgerProvider).hasValue);
    expect(container.read(ledgerProvider).hasValue, isTrue);
    expect(waited, lessThan(const Duration(seconds: 1)));
    expect(find.byType(TransactionCard), findsNothing, reason: 'nothing built yet: still the splash');

    // Shown: Home has its data within a couple of frames.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(TransactionCard), findsWidgets);
    await tester.pumpAndSettle(); // the background sync's last answers
  });
}
