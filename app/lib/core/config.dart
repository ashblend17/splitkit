/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run --dart-define=API_ORIGIN=http://10.0.2.2:8000
class AppConfig {
  const AppConfig._();

  /// Scheme and host of the API, without a path (generated client paths start with /api/v1).
  /// Empty by default: the web build is served by nginx, which proxies /api to the API.
  static const apiOrigin = String.fromEnvironment('API_ORIGIN', defaultValue: '');
}
