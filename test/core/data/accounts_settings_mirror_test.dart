// The Accounts table as the mirror of the voci accounts/<accountId> (#142, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';

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
    mirror = AccountsSettingsMirror(db, keychain, settings);
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

  test('removing the Account the sync runs on turns the sync off; another one leaves it on', () async {
    await db.accountsDao.upsert(_ada);
    await settings.setSettingsSyncAccount(_ada.id);
    await db.postinoSettingsDao.tombstoneAccount(_ada.id, at: _t);
    await mirror.reconcile();
    expect(await settings.settingsSyncAccount(), isNull);

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

  test('an Account here without a voce, or with a malformed one, is left alone', () async {
    await db.accountsDao.upsert(_ada);
    await db.accountsDao.upsert(_bob);
    await db.postinoSettingsDao.write(accountSettingsKey(_bob.id), '{"provider":"fastmail"}', at: _t);
    await mirror.reconcile();
    expect(await accounts(), [_bob, _ada]);
  });
}
