import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The options the keychain plugin receives for a write of [store] on [platform].
  Future<Object?> accessibilityOf(KeychainStore store, TargetPlatform platform) async {
    Object? options;
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      options = (call.arguments as Map)['options'];
      return null;
    });
    debugDefaultTargetPlatformOverride = platform;
    try {
      await store.write('database_key', 'k3y');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
    return (options as Map?)?['accessibility'];
  }

  test('the database key is saved for this device only, the other secrets as before (#263)', () async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      expect(await accessibilityOf(KeychainStore.deviceOnly(), platform), 'first_unlock_this_device');
    }
    expect(await accessibilityOf(KeychainStore(), TargetPlatform.iOS), 'first_unlock');
  });
}
