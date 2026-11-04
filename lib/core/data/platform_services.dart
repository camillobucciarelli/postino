import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as plus;
import 'package:file/local.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import '../domain/message.dart';
import '../domain/model_manager.dart';
import '../domain/platform_services.dart';
import 'attachment_cache.dart';
import 'file_model_manager.dart';
import 'postino_database.dart';
import 'sync/outbox_sender.dart' show sendWindow;

/// Keychain (iOS/macOS), Keystore (Android), Credential Manager (Windows), libsecret (Linux).
// ponytail: first_unlock so the future background isolate can read the key with the device locked.
@Singleton(as: SecureStore, env: [Environment.prod])
class KeychainStore() implements SecureStore {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

@Singleton(as: Clock, env: [Environment.prod])
class SystemClock() implements Clock {
  @override
  DateTime now() => DateTime.now();

  @override
  Stream<void> every(Duration period) => Stream<void>.periodic(period);
}

/// Network state from the OS (connectivity_plus).
// ponytail: "has a network interface", not "reaches the Provider"; a captive portal reads as online, and the sync's OfflineFailure covers it.
@Singleton(as: Connectivity, env: [Environment.prod])
class SystemConnectivity() implements Connectivity {
  this {
    unawaited(_plus.checkConnectivity().then(_update, onError: (_) {}));
  }

  final _plus = plus.Connectivity();
  bool _online = true;

  bool _update(List<plus.ConnectivityResult> r) => _online = r.any((c) => c != plus.ConnectivityResult.none);

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onChanged => _plus.onConnectivityChanged.map(_update).distinct();

  // ponytail: Wi-Fi as connectivity_plus sees it, so a phone's hotspot counts as Wi-Fi; Android's
  // isActiveNetworkMetered if a metered Wi-Fi ever surprises a user.
  @override
  Future<bool> onWifi() async {
    try {
      return (await _plus.checkConnectivity()).contains(plus.ConnectivityResult.wifi);
    } on Exception {
      return false;
    }
  }
}

@Singleton(as: LinkOpener, env: [Environment.prod])
class SystemLinkOpener implements LinkOpener {
  SystemLinkOpener() : _launch = _launchExternal, _openFile = _openFilex, _platform = null;

  /// `platform` stands for [defaultTargetPlatform].
  @visibleForTesting
  SystemLinkOpener.test({required this._launch, required this._openFile, required TargetPlatform this._platform});

  final Future<void> Function(Uri url) _launch;
  final Future<void> Function(String path) _openFile;
  final TargetPlatform? _platform;

  /// A local file (an attachment) opens in the system's app: url_launcher does it on desktop,
  /// Android and iOS need open_filex (its FileProvider; Quick Look and "Open in").
  @override
  Future<void> open(Uri url) async {
    final mobile = switch (_platform ?? defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    // Defence in depth (#75): the Conversazione never asks, but an executable is never launched from here.
    if (url.isScheme('file') && url.pathSegments.isNotEmpty && isExecutableName(url.pathSegments.last)) {
      return;
    }
    // ponytail: a link or file nothing can open does nothing; a Snackbar if users ever ask why.
    try {
      await (url.isScheme('file') && mobile && !kIsWeb ? _openFile(url.toFilePath()) : _launch(url));
    } on Object catch (_) {}
  }

  static Future<void> _launchExternal(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  static Future<void> _openFilex(String path) => OpenFilex.open(path);
}

/// The system Save As dialog (file_selector), on desktop only.
@Singleton(as: FileSaver, env: [Environment.prod])
class SystemFileSaver() implements FileSaver {
  @override
  bool get available =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
        _ => false,
      };

  @override
  Future<void> save(String path, String name) async {
    final to = await getSaveLocation(suggestedName: name);
    if (to != null) await const LocalFileSystem().file(path).copy(to.path);
  }
}

@module
abstract class AttachmentModule() {
  /// The cache in the app's support folder (out of the OS's cache purges, so offline holds), the copies in its temporary one.
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<AttachmentStorage> attachmentStorage() async {
    const fs = LocalFileSystem();
    return AttachmentStorage.open(
      fs.directory('${(await getApplicationSupportDirectory()).path}/attachments'),
      fs.directory('${(await getTemporaryDirectory()).path}/postino-attachments'),
    );
  }
}

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

@module
abstract class DatabaseModule() {
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<PostinoDatabase> database(SecureStore keychain) async {
    final dir = await getApplicationSupportDirectory();
    return PostinoDatabase.open('${dir.path}/postino.db', keychain);
  }
}

@module
abstract class HttpModule() {
  @Singleton(env: [Environment.prod])
  http.Client client() => http.Client();
}

/// iOS: a `beginBackgroundTask` per Account, begun at Invia while still in foreground (it only matters once
/// backgrounded) and ended when the outbox empties or at expiration. Android: a WorkManager one-shot after
/// [sendWindow] whose isolate flushes the outbox (see background_send.dart). Desktop: the process lives.
@LazySingleton(as: BackgroundSender, env: [Environment.prod])
class SystemBackgroundSender() implements BackgroundSender {
  static const channel = MethodChannel('it.postino/background');

  /// Name of the WorkManager task; [workName] is unique per Account.
  static const task = 'postino.send';
  static String workName(String accountId) => '$task.$accountId';

  /// iOS task identifiers, one per Account; a second hold replaces the open one, which may have expired.
  final _tasks = <String, int>{};

  /// The iOS task held for the Account, if any.
  @visibleForTesting
  int? taskId(String accountId) => _tasks[accountId];

  static TargetPlatform? get _mobile => kIsWeb
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS || TargetPlatform.android => defaultTargetPlatform,
          _ => null,
        };

  @override
  Future<void> hold(String accountId) async {
    switch (_mobile) {
      case TargetPlatform.iOS:
        // iOS may have expired the open task already (its 30 s are gone): ended (harmless if so) and begun anew.
        if (_tasks.remove(accountId) case final old?) {
          try {
            await channel.invokeMethod<void>('endBackgroundTask', old);
          } on PlatformException catch (e) {
            debugPrint('[background] end of task $old failed, $e');
          }
        }
        final id = await channel.invokeMethod<int>('beginBackgroundTask');
        if (id != null && id != 0) _tasks[accountId] = id;
      case TargetPlatform.android:
        await Workmanager().registerOneOffTask(
          workName(accountId),
          task,
          inputData: {'accountId': accountId},
          initialDelay: sendWindow,
          constraints: Constraints(networkType: NetworkType.connected),
          // Maps to APPEND_OR_REPLACE: keeps a worker that is sending right now (replace would cancel it, its row
          // staying claimed with no retry) and starts a fresh chain after a cancelled or failed one (plain APPEND
          // would cancel the new work too).
          existingWorkPolicy: ExistingWorkPolicy.update,
        );
      default:
    }
  }

  @override
  Future<void> release(String accountId) async {
    switch (_mobile) {
      case TargetPlatform.iOS:
        if (_tasks.remove(accountId) case final id?) {
          await channel.invokeMethod<void>('endBackgroundTask', id);
        }
      case TargetPlatform.android:
        await Workmanager().cancelByUniqueName(workName(accountId));
      default:
    }
  }
}
