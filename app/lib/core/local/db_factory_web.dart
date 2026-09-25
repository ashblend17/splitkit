import 'package:sembast_web/sembast_web.dart';

DatabaseFactory get platformDatabaseFactory => databaseFactoryWeb;

Future<String> localDatabasePath(String userId) async => 'splitkit_u_$userId';
