// The voci of the Impostazioni di Postino as last-write-wins needs them (#124, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/settings_entry.dart';

final _t = DateTime.utc(2026, 11, 5);
final _ms = _t.millisecondsSinceEpoch;

void main() {
  late PostinoDatabase db;
  setUp(() => db = PostinoDatabase.inMemory());
  tearDown(() => db.close());

  test('a write is stamped with this device and to upload; null leaves a tombstone read as missing', () async {
    await db.postinoSettingsDao.write('auto_labels/a1', '{}', at: _t);
    final device = await db.deviceSettingsDao.deviceId();
    expect(await db.postinoSettingsDao.entries(), [
      SettingsEntry(key: 'auto_labels/a1', value: '{}', updatedAt: _ms, deviceId: device),
    ]);

    await db.postinoSettingsDao.write('auto_labels/a1', null, at: _t.add(const Duration(seconds: 1)));
    expect(await db.postinoSettingsDao.read('auto_labels/a1'), isNull);
    expect(await db.postinoSettingsDao.watch('auto_labels/a1').first, isNull);
    expect((await db.postinoSettingsDao.entries()).single.deleted, isTrue);
    expect(await db.postinoSettingsDao.watchDirty().first, 1);
  });

  test('the device id is random once, then stable', () async {
    final id = await db.deviceSettingsDao.deviceId();
    expect(id, hasLength(32));
    expect(await db.deviceSettingsDao.deviceId(), id);
  });

  test('a write never goes back in time behind the copy it replaces', () async {
    await db.postinoSettingsDao.applyRemote([
      SettingsEntry(key: 'k', value: '1', updatedAt: _ms + 5000, deviceId: 'zz'),
    ]);
    await db.postinoSettingsDao.write('k', '2', at: _t);
    expect((await db.postinoSettingsDao.entries()).single.updatedAt, _ms + 5001);
  });

  test('a remote copy is applied clean only when it wins over the one here', () async {
    await db.postinoSettingsDao.write('k', 'mine', at: _t);
    await db.postinoSettingsDao.applyRemote([
      SettingsEntry(key: 'k', value: 'old', updatedAt: _ms - 1, deviceId: 'zz'),
      SettingsEntry(key: 'n', value: 'new', updatedAt: _ms, deviceId: 'zz'),
    ]);
    expect(await db.postinoSettingsDao.read('k'), 'mine');
    expect(await db.postinoSettingsDao.read('n'), 'new');
    expect(await db.postinoSettingsDao.watchDirty().first, 1);
  });

  test('mark clean skips a voce written again since the upload', () async {
    await db.postinoSettingsDao.write('a', '1', at: _t);
    await db.postinoSettingsDao.write('b', '1', at: _t);
    final uploaded = await db.postinoSettingsDao.entries();
    await db.postinoSettingsDao.write('b', '2', at: _t.add(const Duration(seconds: 1)));
    await db.postinoSettingsDao.markClean(uploaded);
    final dirty = (await db.select(db.postinoSettings).get()).where((r) => r.dirty).map((r) => r.key);
    expect(dirty, ['b']);
  });

  test('removing an Account tombstones its synced voci, present here or not', () async {
    await db.postinoSettingsDao.write('auto_labels/a1', '{}', at: _t);
    await db.postinoSettingsDao.tombstoneAccount('a1', at: _t.add(const Duration(seconds: 1)));
    await db.postinoSettingsDao.tombstoneAccount('a2', at: _t);
    final entries = await db.postinoSettingsDao.entries();
    expect(
      {for (final e in entries) e.key: e.deleted},
      {'auto_labels/a1': true, 'accounts/a1': true, 'auto_labels/a2': true, 'accounts/a2': true},
    );
  });
}
