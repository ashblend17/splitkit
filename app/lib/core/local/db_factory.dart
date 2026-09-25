/// Where each user's local database lives: a file on Android/iOS, IndexedDB on web.
library;

export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
