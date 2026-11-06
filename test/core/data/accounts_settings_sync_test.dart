// The Accounts synced between devices through the file of the Impostazioni di Postino (#142, ADR 0016):
// devices on in-memory databases, one shared fake backend standing for the file on Drive.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_lock.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/settings_sync.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_platform.dart';
import '../../support/fake_settings_backend.dart';
import '../../support/harness.dart';

/// One device without the DI: its database, its sync and its mirror of the Accounts, on the file in [backend].
class _Device(final FakeSettingsBackend backend, final FakeClock clock) {
  final db = PostinoDatabase.inMemory();
  final keychain = FakeSecureStore();
  late final settings = DeviceSettingsStore(db);
  late final sync = SettingsSync(db, settings, clock, FakeConnectivity(), backendFor: (_) => backend);
  late final mirror = AccountsSettingsMirror(db, keychain, settings, AccountsLock());

  Future<void> start() async {
    await settings.setSettingsSyncAccount('a1');
    mirror.start();
  }

  Future<void> close() async {
    await mirror.stop();
    await sync.stop();
    await db.close();
  }

  /// The voce of [a] written here, as connecting it or changing it does.
  Future<void> put(Account a) =>
      db.postinoSettingsDao.write(accountSettingsKey(a.id), encodeAccountSettings(a), at: clock.now());

  Future<void> syncNow() async {
    await sync.syncNow();
    await pumpEventQueue();
  }

  Future<List<Account>> accounts() => MailStore(db).accounts();
}

Account _account(String name, {int color = 0, int position = 0}) => Account(
  id: 'gmail:$name@gmail.com',
  address: '$name@gmail.com',
  provider: ProviderKind.gmail,
  color: color,
  position: position,
);

Map<String, Object?> _entries(String? file) =>
    (jsonDecode(file!) as Map<String, dynamic>)['entries'] as Map<String, Object?>;

void main() {
  // Two devices: two databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('between two devices', () {
    late FakeSettingsBackend file;
    late FakeClock clock;
    late _Device a;
    late _Device b;
    setUp(() async {
      file = FakeSettingsBackend();
      clock = FakeClock(DateTime.utc(2026, 11, 5, 9));
      a = _Device(file, clock);
      b = _Device(file, clock);
      await a.start();
      await b.start();
    });
    tearDown(() async {
      await a.close();
      await b.close();
    });

    void tick() => clock.advance(const Duration(seconds: 1));

    test('concurrent edits: on the same Account the last wins, on different Accounts both stay', () async {
      await a.put(_account('ada', color: 1));
      await a.put(_account('xavier', position: 1));
      tick();
      await b.put(_account('ada', color: 2));
      await b.put(_account('yuri', position: 2));
      for (final d in [a, b, a]) {
        await d.syncNow();
      }
      for (final d in [a, b]) {
        final all = {for (final x in await d.accounts()) x.address: x};
        expect(all.keys, ['ada@gmail.com', 'xavier@gmail.com', 'yuri@gmail.com']);
        expect(all['ada@gmail.com']!.color, 2);
      }
    });

    test('at the same updatedAt the larger deviceId wins', () async {
      await a.put(_account('ada', color: 1));
      await b.put(_account('ada', color: 2));
      for (final d in [a, b, a]) {
        await d.syncNow();
      }
      final aId = await a.db.deviceSettingsDao.deviceId();
      final bId = await b.db.deviceSettingsDao.deviceId();
      final expected = aId.compareTo(bId) > 0 ? 1 : 2;
      for (final d in [a, b]) {
        expect((await d.accounts()).single.color, expected);
      }
    });

    test('a remote change of color keeps the status here', () async {
      await a.put(_account('ada', color: 1));
      await a.syncNow();
      await b.syncNow();
      await b.db.accountsDao.setStatus('gmail:ada@gmail.com', AccountStatus.attivo);
      tick();
      await a.put(_account('ada', color: 4));
      await a.syncNow();
      await b.syncNow();
      final ada = (await b.accounts()).single;
      expect((ada.color, ada.status), (4, AccountStatus.attivo));
    });

    test(
      'removing an Account takes it off the other device, credentials too; an older copy does not bring it back',
      () async {
        await a.put(_account('ada', color: 1));
        await a.syncNow();
        await b.syncNow();
        await b.keychain.write('oauth:gmail:ada@gmail.com', '{}');
        // B edits offline, then A removes the Account later.
        tick();
        await b.put(_account('ada', color: 5));
        tick();
        await a.db.postinoSettingsDao.tombstoneAccount('gmail:ada@gmail.com', at: clock.now());
        for (final d in [a, b, a, b]) {
          await d.syncNow();
        }
        expect(await a.accounts(), isEmpty);
        expect(await b.accounts(), isEmpty);
        expect(b.keychain.values, isEmpty);
        expect(_entries(file.file)['accounts/gmail:ada@gmail.com'], containsPair('deleted', true));
      },
    );

    test('removing the sync Account reaches the other device before its credentials go', () async {
      await a.settings.setSettingsSyncAccount('gmail:ada@gmail.com');
      await a.put(_account('ada'));
      await a.keychain.write('oauth:gmail:ada@gmail.com', '{}');
      await a.syncNow();
      await b.syncNow();
      expect(await b.accounts(), hasLength(1));
      // Connected on A: a sync Account da ricollegare could not upload, and would go at once.
      await a.db.accountsDao.setStatus('gmail:ada@gmail.com', AccountStatus.attivo);

      tick();
      await a.db.postinoSettingsDao.tombstoneAccount('gmail:ada@gmail.com', at: clock.now());
      await pumpEventQueue();
      await a.syncNow();
      await b.syncNow();

      expect(_entries(file.file)['accounts/gmail:ada@gmail.com'], containsPair('deleted', true));
      expect(await b.accounts(), isEmpty);
      expect(await a.accounts(), isEmpty);
      expect(a.keychain.values, isEmpty);
      expect(await a.settings.settingsSyncAccount(), isNull);
    });

    test('voci from a newer Postino under a prefix unknown here stay in the file', () async {
      file.file = jsonEncode({
        'schemaVersion': 2,
        'entries': {
          'themes/x': {'value': 1, 'updatedAt': 1, 'deviceId': 'z', 'deleted': false},
        },
      });
      await a.put(_account('ada'));
      await a.syncNow();
      expect(_entries(file.file).keys, containsAll(['themes/x', 'accounts/gmail:ada@gmail.com']));
      expect(await a.db.postinoSettingsDao.read('themes/x'), isNull);
    });
  });

  group('a new device', () {
    /// The Impostazioni di Postino of the device in the DI, synced with [file].
    Future<SettingsSync> syncedWith(Harness h, FakeSettingsBackend file) async {
      final db = getIt<PostinoDatabase>();
      final settings = DeviceSettingsStore(db);
      await settings.setSettingsSyncAccount('gmail:ada@gmail.com');
      return SettingsSync(db, settings, h.clock, h.connectivity, backendFor: (_) => file);
    }

    test('its first Account, connected before the sync is on, takes the synced color and position', () async {
      final file = FakeSettingsBackend();

      // Device A: ada (0, 0) and bob (1, 1), synced.
      var h = await Harness.create();
      h
        ..providerFor('gmail:ada@gmail.com')
        ..providerFor('gmail:bob@gmail.com');
      await getIt<AccountsRepository>().connectGmail();
      h.consent.address = 'bob@gmail.com';
      await getIt<AccountsRepository>().connectGmail();
      await (await syncedWith(h, file)).syncNow();
      Object? bobInFile() => (_entries(file.file)['accounts/gmail:bob@gmail.com']! as Map<String, Object?>)['value'];
      final bobOnA = bobInFile();
      expect(bobOnA, {'address': 'bob@gmail.com', 'provider': 'gmail', 'color': 1, 'position': 1});

      // Device B, as the app goes: the onboarding connects bob (the first Account here, so 0, 0), then
      // «Sincronizza su…» turns the sync on.
      await pumpEventQueue();
      h = await Harness.create();
      final mirror = getIt<AccountsSettingsMirror>()..start();
      addTearDown(mirror.stop);
      h
        ..providerFor('gmail:bob@gmail.com')
        ..consent.address = 'bob@gmail.com';
      await getIt<AccountsRepository>().connectGmail();
      await (await syncedWith(h, file)).syncNow();
      await pumpEventQueue();

      expect((await getIt<MailStore>().accounts()).map((x) => (x.address, x.color, x.position, x.status)), [
        ('ada@gmail.com', 0, 0, AccountStatus.daRicollegare),
        ('bob@gmail.com', 1, 1, AccountStatus.attivo),
      ]);
      expect(bobInFile(), bobOnA);
    });

    test(
      'gets the Accounts da ricollegare, identical; reconnecting one makes no duplicate nor rewrites its voce',
      () async {
        final file = FakeSettingsBackend();

        // Device A: two Accounts connected, then synced.
        var h = await Harness.create();
        h
          ..providerFor('gmail:ada@gmail.com')
          ..providerFor('gmail:bob@gmail.com');
        await getIt<AccountsRepository>().connectGmail();
        h.consent.address = 'bob@gmail.com';
        await getIt<AccountsRepository>().connectGmail();
        await (await syncedWith(h, file)).syncNow();
        final onA = await getIt<MailStore>().accounts();
        expect(onA.map((x) => (x.address, x.color, x.position)), [('ada@gmail.com', 0, 0), ('bob@gmail.com', 1, 1)]);

        // No credential in the file: the tokens of the fake consent are `access-token-<n>`, `refresh-token-<n>`.
        for (final secret in ['access', 'refresh', 'token', 'expires']) {
          expect(file.file, isNot(contains(secret)));
        }

        // Device B: a fresh database on the same file, once the mail sync of A is over.
        await pumpEventQueue();
        h = await Harness.create();
        final mirror = getIt<AccountsSettingsMirror>()..start();
        addTearDown(mirror.stop);
        final sync = await syncedWith(h, file);
        await sync.syncNow();
        await pumpEventQueue();
        final onB = await getIt<MailStore>().accounts();
        expect(onB.map((x) => (x.id, x.address, x.provider, x.color, x.position)), [
          for (final x in onA) (x.id, x.address, x.provider, x.color, x.position),
        ]);
        expect(onB.map((x) => x.status), everyElement(AccountStatus.daRicollegare));

        final key = accountSettingsKey('gmail:ada@gmail.com');
        final before = await getIt<PostinoDatabase>().postinoSettingsDao.readRow(key);
        h.providerFor('gmail:ada@gmail.com');
        h.clock.advance(const Duration(minutes: 1));
        await getIt<AccountsRepository>().connectGmail(loginHint: 'ada@gmail.com');
        await pumpEventQueue();

        final after = await getIt<MailStore>().accounts();
        expect(after.map((x) => (x.address, x.color, x.position, x.status)), [
          ('ada@gmail.com', 0, 0, AccountStatus.attivo),
          ('bob@gmail.com', 1, 1, AccountStatus.daRicollegare),
        ]);
        expect(await getIt<PostinoDatabase>().postinoSettingsDao.readRow(key), before);
      },
    );
  });
}
