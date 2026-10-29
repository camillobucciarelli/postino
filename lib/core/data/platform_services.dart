import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as plus;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/platform_services.dart';
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
