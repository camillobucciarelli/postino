import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_only_key.dart';

import '../../support/fake_platform.dart';

void main() {
  const name = 'database_key';
  const key = 'k3y';

  test('a key an older version saved is rewritten device only, once, its copy kept', () async {
    final keychain = FakeSecureStore()..values[name] = key;

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, ['$name.copy', name, '$name.device_only'], reason: 'copied before the rewrite');
    expect(keychain.values, {name: key, '$name.copy': key, '$name.device_only': '1'});

    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, isEmpty);
  });

  test('a key saved by writeDeviceOnly is never migrated', () async {
    final keychain = FakeSecureStore();
    await writeDeviceOnly(keychain, name, key);
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
      ..failingWrites.add('$name.copy');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.device_only'], isNotNull);
  });

  test('a rewrite that lost the key (deleted, not added) is recovered from the copy, never rewritten', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key, reason: 'this start still opens the database');
    expect(keychain.values, {'$name.copy': key});

    // The next start fails again: the copy, the only one left, is not touched.
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name]);
    expect(keychain.values, {'$name.copy': key});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.device_only': '1'});
  });

  test('a rewrite read back different leaves the migration undone', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..corruptWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.copy'], key);
    expect(keychain.values['$name.device_only'], isNull, reason: 'tried again at the next start');
  });

  test('a keychain that cannot be read is an error, never a missing key', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failure = Exception('keychain bloccato');
    await expectLater(readDeviceOnly(keychain, name), throwsException);
  });
}
