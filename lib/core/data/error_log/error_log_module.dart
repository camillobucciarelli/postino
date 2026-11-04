import 'package:file/local.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/error_log.dart';
import '../../domain/platform_services.dart';
import '../postino_database.dart';
import 'encrypted_error_log.dart';
import 'log_keys.dart';

@module
abstract class ErrorLogModule() {
  /// In the app's support folder, next to the database, under keys derived from the database's (#116).
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<ErrorLog> errorLog(SecureStore keychain, Clock clock) async => EncryptedErrorLog(
    const LocalFileSystem().directory('${(await getApplicationSupportDirectory()).path}/logs'),
    logKeysFrom(await PostinoDatabase.keyFrom(keychain)),
    clock,
  );
}
