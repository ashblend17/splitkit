import 'package:sembast_web/sembast_web.dart';
import '../fixed_names.dart';

DatabaseFactory get platformDatabaseFactory => databaseFactoryWeb;

Future<String> localDatabasePath(String userId) async => '${FixedNames.webDatabasePrefix}$userId';
