import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/config.dart';
import 'core/router/router.dart';
import 'core/session/session.dart';
import 'core/theme/theme.dart';
import 'features/shell/app_mode.dart';
import 'features/shell/sync_banner.dart';
import 'features/sms/sms_background.dart';

Future<void> main() async {
  // Real paths (/groups/…) instead of /#/groups/…; nginx serves index.html for any path.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // A server picked in the developer settings; builds without them always use API_ORIGIN.
  final savedOrigin = AppConfig.devTools ? await ApiOriginStore().read() : null;
  // Split or Personal: the app opens in the mode it was left in.
  final savedMode = await AppModeStore().read() ?? AppMode.split;
  // No automatic retries: failed requests show an error card with "Try again".
  runApp(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      savedApiOriginProvider.overrideWithValue(savedOrigin),
      savedAppModeProvider.overrideWithValue(savedMode),
    ],
    child: const SplitkitApp(),
  ));
}

/// Started by the phone (SmsBackground.kt) when a bank SMS arrives with the app closed, to
/// describe it for the notification. Here, in the main library, so release builds keep it.
@pragma('vm:entry-point')
Future<void> smsBackgroundMain() => runSmsBackground();

class SplitkitApp extends ConsumerWidget {
  const SplitkitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Splitkit',
      debugShowCheckedModeBanner: false,
      theme: buildSplitkitTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: appChrome,
    );
  }
}
