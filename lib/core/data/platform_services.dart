import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
}

// ponytail: always online until the offline indicator needs a real signal (connectivity_plus).
@Singleton(as: Connectivity, env: [Environment.prod])
class AlwaysOnline implements Connectivity {
  @override
  bool get isOnline => true;
  @override
  Stream<bool> get onChanged => const Stream.empty();
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
