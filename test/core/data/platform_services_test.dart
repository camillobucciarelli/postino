import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_only_key.dart';
import 'package:postino/core/data/platform_services.dart';
import 'package:postino/core/domain/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The options the keychain plugin receives for a write of [store] on [platform].
  Future<Map<Object?, Object?>> optionsOf(SecureStore store, TargetPlatform platform) async {
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
    return options! as Map<Object?, Object?>;
  }

  test('the database key is saved for this device only, the other secrets as before (#263)', () async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      expect((await optionsOf(KeychainStore.deviceOnly(), platform))['accessibility'], 'first_unlock_this_device');
    }
    expect((await optionsOf(KeychainStore(), TargetPlatform.iOS))['accessibility'], 'first_unlock');
    expect((await optionsOf(KeychainStore(), TargetPlatform.macOS))['usesDataProtectionKeychain'], 'false');
  });

  test(
    'a macOS release keeps the database key in the Data Protection keychain, moved from the legacy one (#270)',
    () async {
      final store = deviceOnlyKeychainFor(TargetPlatform.macOS, release: true);
      expect(store, isA<MovingKeychain>());
      final moving = store as MovingKeychain;
      final to = await optionsOf(moving.to, TargetPlatform.macOS);
      expect(to['usesDataProtectionKeychain'], 'true');
      expect(to['accessibility'], 'first_unlock_this_device');
      expect((await optionsOf(moving, TargetPlatform.macOS))['usesDataProtectionKeychain'], 'true');
      expect((await optionsOf(moving.from, TargetPlatform.macOS))['usesDataProtectionKeychain'], 'false');
    },
  );

  test(
    'Debug and Profile on macOS (no provisioning profile) and the other platforms keep the keychain of #263',
    () async {
      for (final (platform, release) in [
        (TargetPlatform.macOS, false),
        (TargetPlatform.iOS, true),
        (TargetPlatform.android, true),
        (TargetPlatform.windows, true),
        (TargetPlatform.linux, true),
      ]) {
        expect(deviceOnlyKeychainFor(platform, release: release), isA<KeychainStore>(), reason: '$platform $release');
      }
      expect(
        (await optionsOf(
          deviceOnlyKeychainFor(TargetPlatform.macOS, release: false),
          TargetPlatform.macOS,
        ))['usesDataProtectionKeychain'],
        'false',
      );
    },
  );
}
