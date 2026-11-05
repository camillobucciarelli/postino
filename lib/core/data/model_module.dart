import 'package:file/local.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/model_manager.dart';
import '../domain/platform_services.dart';
import 'file_model_manager.dart';

@module
abstract class ModelModule() {
  /// The on-device models (#108) in the app's support folder, out of the OS's cache purges.
  // ponytail: on iOS that folder goes into the iCloud backup; exclude it (NSURLIsExcludedFromBackupKey) once a
  // model is actually downloaded by users.
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<ModelManager> modelManager(http.Client client, Connectivity network) async => FileModelManager(
    client,
    network,
    const LocalFileSystem().directory('${(await getApplicationSupportDirectory()).path}/models'),
  );
}
