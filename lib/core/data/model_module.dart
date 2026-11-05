import 'dart:ffi';
import 'dart:io';

import 'package:file/local.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/embedding_models.dart';
import '../domain/error_log.dart';
import '../domain/model_download.dart';
import '../domain/model_manager.dart';
import '../domain/platform_services.dart';
import '../domain/text_embedder.dart';
import 'file_model_manager.dart';
import 'llamadart_embedding_engine.dart';
import 'managed_model_download.dart';
import 'on_device_text_embedder.dart';

@module
abstract class ModelModule() {
  /// The embedding model of this device (ADR 0015): `Abi.current()` is the process's, so Rosetta reads as x64.
  static final _embedding = embeddingModelFor(Platform.operatingSystem, Abi.current().toString().split('_').last);

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

  /// The download of the embedding model, as the UI follows it.
  @LazySingleton(env: [Environment.prod])
  ModelDownload modelDownload(ModelManager manager) => ManagedModelDownload(manager, _embedding);

  /// The embedding model, on llamadart.
  @LazySingleton(env: [Environment.prod])
  TextEmbedder textEmbedder(ModelManager manager, ErrorLog log) =>
      OnDeviceTextEmbedder(manager, _embedding, LlamadartEmbeddingEngine.load, log);
}
