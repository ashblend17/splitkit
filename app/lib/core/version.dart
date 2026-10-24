/// This build of the app (Android, iOS and web): its version, on its own (the server has its
/// own), and the build number tool/build.sh gives it. Semantic versioning; tool/version.sh bumps
/// it with pubspec.yaml's (test/core/version_test.dart keeps them equal) and app/CHANGELOG.md.
/// See README "Versions and releases".
abstract final class AppVersion {
  static const name = '1.0.0';

  /// The commit count it was built at, or empty for `flutter run`.
  static const build = String.fromEnvironment('BUILD_NUMBER');

  /// "1.0.0 (92)", or "1.0.0" without a build number.
  static String get label => build.isEmpty || build == '0' ? name : '$name ($build)';
}
