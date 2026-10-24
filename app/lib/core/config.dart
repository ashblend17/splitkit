import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run --dart-define=API_ORIGIN=http://10.0.2.2:8000
class AppConfig {
  const AppConfig._();

  /// Scheme and host of the API, without a path (generated client paths start with /api/v1).
  /// Empty by default: the web build is served by nginx, which proxies /api to the API.
  static const apiOrigin = String.fromEnvironment('API_ORIGIN', defaultValue: '');

  /// Developer settings (the "Server" link on the login screen). On in debug builds; turn it on
  /// for a profile or release build with --dart-define=DEV_TOOLS=true.
  static const devTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: kDebugMode);

  /// A sender whose SMS are read as if from a bank, for trying the importer on an emulator
  /// (`adb emu sms send 5551234 "…"` sends from a number, not a bank header). Empty: none.
  static const smsTestSender = String.fromEnvironment('SMS_TEST_SENDER');

  /// What the app is called on screen. tool/build.sh passes .env's APP_NAME.
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: 'App');
}
