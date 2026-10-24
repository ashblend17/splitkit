/// Names this app's data depends on, which stay as they are whatever the app is called: they
/// are names in storage and seeds of ids, not the app's name.
///
/// A phone or browser that has used the app keeps its session, settings and local database (with
/// changes not yet synced) only while the storage names match. Category rules' ids are uuid5 of
/// the url namespace and "`idSeed`:category-rule:…", on the server too (api/app/core/fixed_names.py):
/// rules already stored keep their ids only while it stays.
abstract final class FixedNames {
  static const _stored = 'splitkit';

  /// Seeds of ids that are worked out the same way on the server and every device.
  static const idSeed = _stored;

  // Device storage (SharedPreferences).
  static const token = '$_stored.token';
  static const user = '$_stored.user';
  static const apiOrigin = '$_stored.apiOrigin';
  static const theme = '$_stored.theme';
  static const mode = '$_stored.mode';

  /// The local database: a folder in the app's files on phones and desktops…
  static const databaseFolder = _stored;

  /// …and a name prefix in a browser.
  static const webDatabasePrefix = '${_stored}_u_';
}
