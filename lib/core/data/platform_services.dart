import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as plus;
import 'package:file/local.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/platform_services.dart';
import 'attachment_cache.dart';
import 'postino_database.dart';

/// Keychain (iOS/macOS), Keystore (Android), Credential Manager (Windows), libsecret (Linux).
// ponytail: first_unlock so the future background isolate can read the key with the device locked.
@Singleton(as: SecureStore, env: [Environment.prod])
class KeychainStore implements SecureStore {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

@Singleton(as: Clock, env: [Environment.prod])
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();

  @override
  Stream<void> every(Duration period) => Stream<void>.periodic(period);
}

/// Network state from the OS (connectivity_plus).
// ponytail: "has a network interface", not "reaches the Provider"; a captive portal reads as online, and the sync's OfflineFailure covers it.
@Singleton(as: Connectivity, env: [Environment.prod])
class SystemConnectivity implements Connectivity {
  SystemConnectivity() {
    unawaited(_plus.checkConnectivity().then(_update, onError: (_) {}));
  }

  final _plus = plus.Connectivity();
  bool _online = true;

  bool _update(List<plus.ConnectivityResult> r) =>
      _online = r.any((c) => c != plus.ConnectivityResult.none);

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onChanged =>
      _plus.onConnectivityChanged.map(_update).distinct();
}

@Singleton(as: LinkOpener, env: [Environment.prod])
class SystemLinkOpener implements LinkOpener {
  // ponytail: a link nothing can open does nothing; a Snackbar if users ever ask why.
  @override
  Future<void> open(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// The system Save As dialog (file_selector), on desktop only.
@Singleton(as: FileSaver, env: [Environment.prod])
class SystemFileSaver implements FileSaver {
  @override
  bool get available =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  Future<void> save(String path, String name) async {
    final to = await getSaveLocation(suggestedName: name);
    if (to != null) await const LocalFileSystem().file(path).copy(to.path);
  }
}

@module
abstract class AttachmentModule {
  /// The cache in the app's support folder (out of the OS's cache purges, so offline holds), the copies in its temporary one.
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<AttachmentStorage> attachmentStorage() async {
    const fs = LocalFileSystem();
    return AttachmentStorage.open(
      fs.directory(
        '${(await getApplicationSupportDirectory()).path}/attachments',
      ),
      fs.directory(
        '${(await getTemporaryDirectory()).path}/postino-attachments',
      ),
    );
  }
}

@module
abstract class DatabaseModule {
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<PostinoDatabase> database(SecureStore keychain) async {
    final dir = await getApplicationSupportDirectory();
    return PostinoDatabase.open('${dir.path}/postino.db', keychain);
  }
}

@module
abstract class HttpModule {
  @Singleton(env: [Environment.prod])
  http.Client client() => http.Client();
}
