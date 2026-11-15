import 'package:injectable/injectable.dart';

import '../../domain/platform_services.dart';
import '../device_only_key.dart';
import 'sync_key.dart';

/// Where this device keeps its Chiave di sincronizzazione (ADR 0019): one only, the one of the file it reads, in the
/// store of `database_key` and with its accessibility (ADR 0017), so it follows neither iCloud Keychain nor backups.
@lazySingleton
class SyncKeyStore(@Named(deviceOnlyKeychainName) final SecureStore _keychain) {
  /// The name of the key in the keychain.
  static const name = 'settings_sync_key';

  /// The key, null before this device has one; a keychain that cannot be read throws.
  Future<SyncKey?> read() async => switch (await readDeviceOnly(_keychain, name)) {
    final saved? => SyncKey.decode(saved),
    null => null,
  };

  /// Keeps [key] in place of the one before.
  Future<void> write(SyncKey key) => writeDeviceOnly(_keychain, name, key.encode());
}
