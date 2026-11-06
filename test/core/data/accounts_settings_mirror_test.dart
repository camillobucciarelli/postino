// The Accounts table as the mirror of the voci accounts/<accountId> (#142, ADR 0016).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_lock.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/settings_entry.dart';

import '../../support/fake_platform.dart';

const _ada = Account(
  id: 'gmail:ada@gmail.com',
  address: 'ada@gmail.com',
  provider: ProviderKind.gmail,
  color: 3,
  position: 2,
);
const _bob = Account(
  id: 'gmail:bob@gmail.com',
  address: 'bob@gmail.com',
  provider: ProviderKind.gmail,
  color: 1,
  position: 1,
);
final _t = DateTime.utc(2026, 11, 5);

void main() {
  late PostinoDatabase db;
  late FakeSecureStore keychain;
  late DeviceSettingsStore settings;
  late AccountsSettingsMirror mirror;
  setUp(() {
    db = PostinoDatabase.inMemory();
    keychain = FakeSecureStore();
    settings = DeviceSettingsStore(db);
    mirror = AccountsSettingsMirror(db, keychain, settings, AccountsLock());
  });
  tearDown(() async {
    await mirror.stop();
    await db.close();
  });

  Future<List<Account>> accounts() => MailStore(db).accounts();
  Future<void> put(Account a, {DateTime? at}) =>
      db.postinoSettingsDao.write(accountSettingsKey(a.id), encodeAccountSettings(a), at: at ?? _t);

  test('started, a voce for an Account missing here adds it da ricollegare, with its color and position', () async {
    mirror.start();
    await put(_ada);
    await pumpEventQueue();
    expect(await accounts(), [
      const Account(
        id: 'gmail:ada@gmail.com',
        address: 'ada@gmail.com',
        provider: ProviderKind.gmail,
        color: 3,
        position: 2,
        status: AccountStatus.daRicollegare,
      ),
    ]);
  });

  test('a changed voce updates color and position and keeps the local status', () async {
    await db.accountsDao.upsert(_ada);
    await put(
      const Account(
        id: 'gmail:ada@gmail.com',
        address: 'ada@gmail.com',
        provider: ProviderKind.gmail,
        color: 6,
        position: 0,
      ),
    );
    await mirror.reconcile();
    final a = (await accounts()).single;
    expect((a.color, a.position, a.status), (6, 0, AccountStatus.attivo));
  });

  test('a tombstone removes the Account here with its mail and its credentials', () async {
    await db.accountsDao.upsert(_ada);
    await db.customStatement("INSERT INTO labels VALUES ('${_ada.id}', 'L1', 'L1', 'etichetta')");
    await keychain.write('oauth:${_ada.id}', '{}');
    await keychain.write('database_key', 'k');
    await db.postinoSettingsDao.tombstoneAccount(_ada.id, at: _t);
    await mirror.reconcile();
    expect(await accounts(), isEmpty);
    expect(await db.select(db.labels).get(), isEmpty);
    expect(keychain.values.keys, ['database_key']);
  });

  test('the Account the sync runs on goes once its tombstone is uploaded, then the sync goes off', () async {
    mirror.start();
    await db.accountsDao.upsert(_ada);
    await keychain.write('oauth:${_ada.id}', '{}');
    await settings.setSettingsSyncAccount(_ada.id);
    await db.postinoSettingsDao.tombstoneAccount(_ada.id, at: _t);
    await pumpEventQueue();
    // Still to upload: its credentials are what uploads it.
    expect(await accounts(), [_ada]);
    expect(keychain.values.keys, ['oauth:${_ada.id}']);
    expect(await settings.settingsSyncAccount(), _ada.id);

    await db.postinoSettingsDao.markClean(await db.postinoSettingsDao.entries());
    await pumpEventQueue();
    expect(await accounts(), isEmpty);
    expect(keychain.values, isEmpty);
    expect(await settings.settingsSyncAccount(), isNull);
  });

  test('removing another Account leaves the sync on', () async {
    await db.accountsDao.upsert(_bob);
    await settings.setSettingsSyncAccount('gmail:other@gmail.com');
    await db.postinoSettingsDao.tombstoneAccount(_bob.id, at: _t);
    await mirror.reconcile();
    expect(await settings.settingsSyncAccount(), 'gmail:other@gmail.com');
  });

  test('a pass that fails leaves Account and mail; the mirror goes on and the next pass removes them', () async {
    mirror.start();
    await db.accountsDao.upsert(_ada);
    await db.customStatement("INSERT INTO labels VALUES ('${_ada.id}', 'L1', 'L1', 'etichetta')");
    await keychain.write('oauth:${_ada.id}', '{}');
    keychain.deleteFailure = Exception('keychain bloccato');
    await db.postinoSettingsDao.tombstoneAccount(_ada.id, at: _t);
    await pumpEventQueue();
    expect(await accounts(), [_ada]);
    expect(await db.select(db.labels).get(), hasLength(1));

    keychain.deleteFailure = null;
    await put(_bob);
    await pumpEventQueue();
    expect((await accounts()).map((a) => a.id), [_bob.id]);
    expect(await db.select(db.labels).get(), isEmpty);
    expect(keychain.values, isEmpty);
  });

  test('the held removal of the sync Account goes on when the sync is turned off', () async {
    mirror.start();
    await db.accountsDao.upsert(_ada);
    await settings.setSettingsSyncAccount(_ada.id);
    await db.postinoSettingsDao.tombstoneAccount(_ada.id, at: _t);
    await pumpEventQueue();
    expect(await accounts(), [_ada]);

    await settings.setSettingsSyncAccount(null);
    await pumpEventQueue();
    expect(await accounts(), isEmpty);
  });

  test('the held removal of the sync Account goes on when it turns da ricollegare', () async {
    mirror.start();
    await db.accountsDao.upsert(_ada);
    await settings.setSettingsSyncAccount(_ada.id);
    await db.postinoSettingsDao.tombstoneAccount(_ada.id, at: _t);
    await pumpEventQueue();
    expect(await accounts(), [_ada]);

    // A mail sync met an AuthFailure.
    await db.accountsDao.setStatus(_ada.id, AccountStatus.daRicollegare);
    await pumpEventQueue();
    expect(await accounts(), isEmpty);
    expect(await settings.settingsSyncAccount(), isNull);
  });

  test('a sync Account da ricollegare, which cannot upload, goes at once; its tombstone stays to upload', () async {
    const ada = Account(
      id: 'gmail:ada@gmail.com',
      address: 'ada@gmail.com',
      provider: ProviderKind.gmail,
      color: 3,
      position: 2,
      status: AccountStatus.daRicollegare,
    );
    await db.accountsDao.upsert(ada);
    await settings.setSettingsSyncAccount(ada.id);
    await db.postinoSettingsDao.tombstoneAccount(ada.id, at: _t);
    await mirror.reconcile();
    expect(await accounts(), isEmpty);
    expect(await settings.settingsSyncAccount(), isNull);
    expect((await db.postinoSettingsDao.readPrefixWithTombstones('accounts/')).single.dirty, isTrue);
  });

  group('a pass that fails is tried again by itself, on fake time', () {
    const base = Duration(seconds: 10);
    const ms = Duration(milliseconds: 1);

    /// Runs [body] in fake time on a fresh database and mirror, with the keychain failing and a tombstone for
    /// [_ada] from another device: already clean, so nothing here writes it again.
    void onFakeTime(void Function(FakeAsync time, PostinoDatabase db, AccountsSettingsMirror m) body) =>
        fakeAsync((time) {
          final db = PostinoDatabase.inMemory();
          final m = AccountsSettingsMirror(db, keychain, DeviceSettingsStore(db), AccountsLock(), retryAfter: base);
          keychain.deleteFailure = Exception('keychain bloccato');
          _now(time, db.accountsDao.upsert(_ada));
          _now(time, db.postinoSettingsDao.applyRemote([_remoteTombstone(_ada)]));
          m.start();
          time.elapse(Duration.zero);
          body(time, db, m);
          // ponytail: not awaited, the cancel of a drift stream never completes in fake time; stop cancels the retry
          // before its first await, which is what these tests need.
          unawaited(m.stop().then((_) => db.close()));
          time.flushMicrotasks();
        });

    /// The attempts just before [d] and at [d].
    (int, int) around(FakeAsync time, Duration d) {
      time.elapse(d - ms);
      final before = keychain.deletes;
      time.elapse(ms);
      return (before, keychain.deletes);
    }

    test('after 1, 2, 4, 8, 16 and then at most 32 times the base', () {
      onFakeTime((time, db, m) {
        var n = keychain.deletes;
        expect(n, 1);
        for (final k in [1, 2, 4, 8, 16, 32, 32, 32]) {
          expect(around(time, base * k), (n, n + 1), reason: '×$k');
          n++;
        }
      });
    });

    test('a pass that succeeds starts the delays again from the base', () {
      onFakeTime((time, db, m) {
        time.elapse(base);
        expect(keychain.deletes, 2);
        keychain.deleteFailure = null;
        time.elapse(base * 2);
        expect(_now(time, MailStore(db).accounts()), isEmpty);

        keychain.deleteFailure = Exception('keychain bloccato');
        _now(time, db.accountsDao.upsert(_bob));
        _now(time, db.postinoSettingsDao.applyRemote([_remoteTombstone(_bob)]));
        final n = keychain.deletes;
        expect(around(time, base), (n, n + 1));
      });
    });

    test('once stopped, the retry waiting does not fire', () {
      onFakeTime((time, db, m) {
        expect(keychain.deletes, 1);
        unawaited(m.stop());
        time.elapse(base * 64);
        expect(keychain.deletes, 1);
      });
    });
  });

  test('an Account here without a voce, or with a malformed one, is left alone', () async {
    await db.accountsDao.upsert(_ada);
    await db.accountsDao.upsert(_bob);
    await db.postinoSettingsDao.write(accountSettingsKey(_bob.id), '{"provider":"fastmail"}', at: _t);
    await mirror.reconcile();
    expect(await accounts(), [_bob, _ada]);
  });
}

/// The tombstone of [a] as it comes from another device.
SettingsEntry _remoteTombstone(Account a) =>
    SettingsEntry(key: accountSettingsKey(a.id), value: null, updatedAt: 1, deviceId: 'z', deleted: true);

/// [f], completed in fake time.
T _now<T>(FakeAsync time, Future<T> f) {
  late T value;
  var done = false;
  unawaited(
    f.then((v) {
      value = v;
      done = true;
    }),
  );
  time.elapse(Duration.zero);
  expect(done, isTrue, reason: 'not completed in fake time');
  return value;
}
