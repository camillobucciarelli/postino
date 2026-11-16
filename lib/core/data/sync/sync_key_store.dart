import 'package:injectable/injectable.dart';

import '../../domain/platform_services.dart';
import '../device_only_key.dart';
import 'sync_key.dart';

/// Where this device keeps its Chiave di sincronizzazione (ADR 0019): one only, the one of the file it reads, in the
/// store of `database_key` and with its accessibility (ADR 0017), so it follows neither iCloud Keychain nor backups.
/// During «Rigenera la chiave» the new key waits beside it as [pendingName] until the file is known to use it.
@lazySingleton
class SyncKeyStore(@Named(deviceOnlyKeychainName) final SecureStore _keychain) {
  /// The name of the key in the keychain.
  static const name = 'settings_sync_key';

  /// The name of a regenerated key whose upload has not been confirmed yet.
  static const pendingName = '$name.pending';

  /// The key, null before this device has one; a keychain that cannot be read throws.
  Future<SyncKey?> read() => _read(name);

  /// Keeps [key] in place of the one before.
  Future<void> write(SyncKey key) => writeDeviceOnly(_keychain, name, key.encode());

  /// A regenerated key not confirmed yet: the upload may have reached Drive even when its answer was lost.
  Future<SyncKey?> readPending() => _read(pendingName);

  /// Keeps [key] as the regenerated one, before its upload.
  Future<void> writePending(SyncKey key) => writeDeviceOnly(_keychain, pendingName, key.encode());

  /// Forgets the regenerated key: promoted, or never used by the file.
  Future<void> clearPending() async {
    await _keychain.delete(pendingName);
    await _keychain.delete('$pendingName.device_only');
  }

  Future<SyncKey?> _read(String item) async => switch (await readDeviceOnly(_keychain, item)) {
    final saved? => SyncKey.decode(saved),
    null => null,
  };
}
