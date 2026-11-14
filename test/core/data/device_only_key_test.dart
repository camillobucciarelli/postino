import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_only_key.dart';

import '../../support/fake_platform.dart';

void main() {
  const name = 'database_key';
  const key = 'k3y';

  test('a key an older version saved is rewritten device only, once, its copy kept', () async {
    final keychain = FakeSecureStore()..values[name] = key;

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [
      '$name.copy',
      '$name.copied',
      name,
      '$name.device_only',
    ], reason: 'copied before the rewrite');
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});

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
    expect(keychain.values, {'$name.copy': key, '$name.copied': '1'});

    // The next start fails again: the copy, the only one left, is not touched.
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name]);
    expect(keychain.values, {'$name.copy': key, '$name.copied': '1'});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a rewrite read back different is restored from the copy, never the other way round', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..corruptWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.copy'], key);
    expect(keychain.values['$name.device_only'], isNull, reason: 'tried again at the next start');

    // The next start finds the key wrong and the copy right: the copy wins, and is not written.
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name]);
    expect(keychain.values['$name.copy'], key);

    keychain.corruptWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a copy read back different is never trusted: the key, untouched, is copied again', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..corruptWrites.add('$name.copy');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values[name], key, reason: 'not rewritten without a good copy');
    expect(keychain.values['$name.copied'], isNull);

    keychain.corruptWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a copy saved but not marked as checked is copied again from the key', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add('$name.copied');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, ['$name.copy', '$name.copied'], reason: 'the key not rewritten');

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.device_only'], '1');
  });

  test('a rewrite checked but not marked done is finished from the copy at the next start', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add('$name.device_only');

    expect(await readDeviceOnly(keychain, name), key);
    keychain.failingWrites.clear();
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name, '$name.device_only']);
  });

  test('only a checked copy is left (the key lost elsewhere): it is the key', () async {
    final keychain = FakeSecureStore()
      ..values['$name.copy'] = key
      ..values['$name.copied'] = '1';

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values[name], key);
    expect(keychain.writes, [name, '$name.device_only']);
  });

  test('a key deleted after the migration is restored from its copy', () async {
    final keychain = FakeSecureStore()
      ..values['$name.copy'] = key
      ..values['$name.copied'] = '1'
      ..values['$name.device_only'] = '1';

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values[name], key);
  });

  test('only an unchecked copy left: the only value, better than a new key that wipes the database', () async {
    final keychain = FakeSecureStore()..values['$name.copy'] = key;

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a copy that cannot be read is an error, never a missing copy', () async {
    final keychain = _FailingRead('$name.copy')..values[name] = key;
    await expectLater(readDeviceOnly(keychain, name), throwsException);
    expect(keychain.writes, isEmpty);
  });

  test('a new key read back different is an error, not a key the next start cannot open with', () async {
    final keychain = FakeSecureStore()..corruptWrites.add(name);
    await expectLater(writeDeviceOnly(keychain, name, key), throwsStateError);
    expect(keychain.values['$name.device_only'], isNull, reason: 'migrated, as any key found, at the next start');
  });

  test('a keychain that cannot be read is an error, never a missing key', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failure = Exception('keychain bloccato');
    await expectLater(readDeviceOnly(keychain, name), throwsException);
  });
}

/// A keychain whose reads of [key] throw: that item locked, the others readable.
class _FailingRead(final String key) extends FakeSecureStore {
  @override
  Future<String?> read(String key) async => key == this.key ? throw Exception('keychain bloccato') : super.read(key);
}
