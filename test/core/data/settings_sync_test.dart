// The Impostazioni di Postino synced between devices through one file (#124, ADR 0016):
// two in-memory databases, one shared fake backend standing for the file on Drive.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/auto_labels_store.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/settings_sync.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_document.dart';

import '../../support/fake_platform.dart';
import '../../support/fake_settings_backend.dart';

/// One device: its database, its Impostazioni and its sync, on the file in [backend].
class _Device(final FakeSettingsBackend backend, final FakeClock clock) {
  final db = PostinoDatabase.inMemory();
  final connectivity = FakeConnectivity();
  late final settings = DeviceSettingsStore(db);
  late final labels = AutoLabelsStore(db, clock);
  late final sync = SettingsSync(db, settings, clock, connectivity, backendFor: (_) => backend);

  Future<int> dirty() => db.postinoSettingsDao.watchDirty().first;
}

Map<String, Object?> _entries(String? file) =>
    (jsonDecode(file!) as Map<String, dynamic>)['entries'] as Map<String, Object?>;

/// Lets the cycles a trigger started run to the end.
Future<void> _settled() => pumpEventQueue(times: 200);

void main() {
  late FakeSettingsBackend file;
  late FakeClock clock;
  late _Device a;
  late _Device b;
  // Two devices: two databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(() async {
    file = FakeSettingsBackend();
    clock = FakeClock(DateTime.utc(2026, 11, 5, 9));
    a = _Device(file, clock);
    b = _Device(file, clock);
    await a.settings.setSettingsSyncAccount('a1');
    await b.settings.setSettingsSyncAccount('a1');
  });
  tearDown(() async {
    await a.sync.stop();
    await b.sync.stop();
    await a.db.close();
    await b.db.close();
  });

  void tick() => clock.advance(const Duration(seconds: 1));

  test('a change on one device reaches the other: the Etichette automatiche of an Account', () async {
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    await a.sync.syncNow();
    await b.sync.syncNow();
    expect(await b.labels.watch('a1').first, {'L1': (automatic: true, description: null)});
    expect(await a.dirty(), 0);
    expect(await b.dirty(), 0);
  });

  test('concurrent edits: on the same voce the last wins, on different voci both stay', () async {
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    await a.labels.setAutomatic('a2', 'X', automatic: true);
    tick();
    await b.labels.setAutomatic('a1', 'L2', automatic: true);
    await b.labels.setAutomatic('a3', 'Y', automatic: true);
    for (final d in [a, b, a]) {
      await d.sync.syncNow();
    }
    for (final d in [a, b]) {
      expect(await d.labels.watch('a1').first, {'L2': (automatic: true, description: null)});
      expect((await d.labels.watch('a2').first).keys, ['X']);
      expect((await d.labels.watch('a3').first).keys, ['Y']);
    }
  });

  test('removing an Account writes tombstones that an older copy does not bring back', () async {
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    await a.sync.syncNow();
    await b.sync.syncNow();
    // B edits offline, then A removes the Account later.
    tick();
    await b.labels.setAutomatic('a1', 'L2', automatic: true);
    tick();
    await a.db.postinoSettingsDao.tombstoneAccount('a1', at: clock.now());
    for (final d in [a, b, a, b]) {
      await d.sync.syncNow();
    }
    expect(await a.labels.watch('a1').first, isEmpty);
    expect(await b.labels.watch('a1').first, isEmpty);
    expect(_entries(file.file)['auto_labels/a1'], containsPair('deleted', true));
  });

  test('the Impostazioni del dispositivo and voci outside the closed list never reach the file', () async {
    await a.settings.setSidebarExpanded(expanded: true);
    await a.db.postinoSettingsDao.write('local/x', '1', at: clock.now());
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    await a.sync.syncNow();
    expect(_entries(file.file).keys, ['auto_labels/a1']);
    expect(file.file, isNot(contains('sidebar')));
    expect(file.file, isNot(contains('settings_sync_account')));
  });

  test('offline the local edits stay dirty and upload when the network returns', () async {
    a.sync.start();
    a.connectivity.online = false;
    await pumpEventQueue();
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    clock.advance(settingsDebounce);
    await a.sync.syncNow();
    expect(file.writes, 0);
    expect(await a.dirty(), 1);

    a.connectivity.online = true;
    await _settled();
    expect(_entries(file.file).keys, ['auto_labels/a1']);
    expect(await a.dirty(), 0);
  });

  test('a failed upload keeps the voci dirty for the next cycle', () async {
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    file.failure = const DriveScopeFailure();
    await a.sync.syncNow();
    expect(await a.dirty(), 1);
    file.failure = null;
    await a.sync.syncNow();
    expect(await a.dirty(), 0);
  });

  test('a file from a newer Postino is read but never overwritten', () async {
    final newer = jsonEncode({
      'schemaVersion': settingsSchemaVersion + 1,
      'entries': {
        'auto_labels/a1': {
          'value': {
            'L1': {'automatic': true},
          },
          'updatedAt': 1,
          'deviceId': 'z',
          'deleted': false,
        },
      },
    });
    file.file = newer;
    await a.labels.setAutomatic('a2', 'X', automatic: true);
    await a.sync.syncNow();
    expect(await a.labels.watch('a1').first, {'L1': (automatic: true, description: null)});
    expect(file.file, newer);
    expect(file.writes, 0);
    expect(await a.dirty(), 1);
  });

  test('without a chosen Account nothing is read or written', () async {
    await a.settings.setSettingsSyncAccount(null);
    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    await a.sync.syncNow();
    expect((file.reads, file.writes), (0, 0));
  });

  test('started, it syncs at once, after the local writes pause, on the poll and when the Account is chosen', () async {
    await a.settings.setSettingsSyncAccount(null);
    a.sync.start();
    await pumpEventQueue();
    expect(file.reads, 0);

    await a.settings.setSettingsSyncAccount('a1');
    await _settled();
    expect(file.reads, 1);

    await a.labels.setAutomatic('a1', 'L1', automatic: true);
    await pumpEventQueue();
    expect(file.writes, 0);
    clock.advance(settingsDebounce);
    await _settled();
    expect(file.writes, 1);

    await b.labels.setAutomatic('a2', 'X', automatic: true);
    await b.sync.syncNow();
    clock.advance(settingsPollEvery);
    await _settled();
    expect((await a.labels.watch('a2').first).keys, ['X']);
  });
}
