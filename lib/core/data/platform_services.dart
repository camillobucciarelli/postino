import 'dart:async';
import 'dart:io' show Process;

import 'package:connectivity_plus/connectivity_plus.dart' as plus;
import 'package:file/local.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/message.dart';
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
  SystemLinkOpener()
    : _launch = _launchExternal,
      _openFile = _openFilex,
      _platform = null;

  /// [platform] stands for [defaultTargetPlatform].
  @visibleForTesting
  SystemLinkOpener.test({
    required this._launch,
    required this._openFile,
    required TargetPlatform this._platform,
  });

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
    if (url.isScheme('file') &&
        url.pathSegments.isNotEmpty &&
        isExecutableName(url.pathSegments.last)) {
      return;
    }
    // ponytail: a link or file nothing can open does nothing; a Snackbar if users ever ask why.
    try {
      await (url.isScheme('file') && mobile && !kIsWeb
          ? _openFile(url.toFilePath())
          : _launch(url));
    } catch (_) {}
  }

  static Future<void> _launchExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  static Future<void> _openFilex(String path) => OpenFilex.open(path);
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
    if (to == null) return;
    await const LocalFileSystem().file(path).copy(to.path);
    // File.copy does not promise the extended attributes come along.
    await quarantine(to.path);
  }
}

/// Marks [path] as downloaded from the internet, so macOS' Gatekeeper checks it before it runs (#75):
/// the `com.apple.quarantine` attribute browsers and Mail set. A no-op elsewhere; errors are swallowed.
/// [platform] stands for [defaultTargetPlatform].
// ponytail: xattr via /usr/bin/xattr (a native binary since macOS 12.3; the sandbox lets a child process
// write the app's own files); setxattr via dart:ffi if the spawn ever fails.
Future<void> quarantine(String path, {TargetPlatform? platform}) async {
  if (kIsWeb || (platform ?? defaultTargetPlatform) != TargetPlatform.macOS) {
    return;
  }
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  try {
    await Process.run('/usr/bin/xattr', [
      '-w',
      'com.apple.quarantine',
      '0081;${seconds.toRadixString(16)};Postino;',
      path,
    ]);
  } catch (_) {}
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
      quarantine: quarantine,
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
