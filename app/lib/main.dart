import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/config.dart';
import 'core/finance/today.dart';
import 'core/router/router.dart';
import 'core/session/session.dart';
import 'core/theme/theme_mode.dart';
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
  // Light, dark or as the device is set, read before the first frame so it doesn't flash.
  final savedTheme = await ThemeModeStore().read() ?? ThemeMode.system;
  // No automatic retries: failed requests show an error card with "Try again".
  runApp(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      savedApiOriginProvider.overrideWithValue(savedOrigin),
      savedAppModeProvider.overrideWithValue(savedMode),
      savedThemeModeProvider.overrideWithValue(savedTheme),
    ],
    child: const RootApp(),
  ));
}

/// Started by the phone (SmsBackground.kt) when a bank SMS arrives with the app closed, to
/// describe it for the notification. Here, in the main library, so release builds keep it.
@pragma('vm:entry-point')
Future<void> smsBackgroundMain() => runSmsBackground();

class RootApp extends ConsumerWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TodayTicker(
      child: SkThemedApp(title: AppConfig.appName, routerConfig: ref.watch(routerProvider), builder: appChrome),
    );
  }
}
