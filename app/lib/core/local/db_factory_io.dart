import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

DatabaseFactory get platformDatabaseFactory => databaseFactoryIo;

Future<String> localDatabasePath(String userId) async =>
    p.join((await getApplicationSupportDirectory()).path, 'splitkit', 'u_$userId.db');
