import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_only_key.dart';

import '../../support/fake_platform.dart';

void main() {
  const name = 'database_key';
  const key = 'k3y';

  test('a key an older version saved is rewritten device only, once', () async {
    final keychain = FakeSecureStore()..values[name] = key;

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, contains(name), reason: 'rewritten under the device-only attribute');
    expect(keychain.values.keys, unorderedEquals([name, '$name.device_only']), reason: 'the copy is gone');

    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, isEmpty);
  });

  test('no key: nothing to migrate', () async {
    final keychain = FakeSecureStore();
    expect(await readDeviceOnly(keychain, name), isNull);
    expect(keychain.values, isEmpty);
  });

  test('a failed copy leaves the key as it was, and the next start migrates', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add('$name.migrating');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.device_only'], isNotNull);
  });

  test('a rewrite that lost the key (deleted, not added) is recovered from the copy at the next start', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key, reason: 'this start still opens the database');
    expect(keychain.values, {'$name.migrating': key});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values.keys, unorderedEquals([name, '$name.device_only']));
  });

  test('a keychain that cannot be read is an error, never a missing key', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failure = Exception('keychain bloccato');
    await expectLater(readDeviceOnly(keychain, name), throwsException);
  });
}
