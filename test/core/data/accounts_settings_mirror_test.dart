// The Accounts table as the mirror of the voci accounts/<accountId> (#142, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/row_mappers.dart';
import 'package:postino/core/domain/account.dart';

import '../../support/fake_platform.dart';

const _ada = Account(
  id: 'gmail:ada@gmail.com',
  address: 'ada@gmail.com',
  provider: ProviderKind.gmail,
  color: 3,
  position: 2,
);
final _t = DateTime.utc(2026, 11, 5);

void main() {
  late PostinoDatabase db;
  late FakeSecureStore keychain;
  late AccountsSettingsMirror mirror;
  setUp(() {
    db = PostinoDatabase.inMemory();
    keychain = FakeSecureStore();
    mirror = AccountsSettingsMirror(db, keychain);
  });
  tearDown(() async {
    await mirror.stop();
    await db.close();
  });

  Future<List<Account>> accounts() async => [for (final r in await db.accountsDao.byPosition()) accountOf(r)];
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

  test('an Account here without a voce, or with a malformed one, is left alone', () async {
    await db.accountsDao.upsert(_ada);
    const bob = Account(
      id: 'gmail:bob@gmail.com',
      address: 'bob@gmail.com',
      provider: ProviderKind.gmail,
      color: 1,
      position: 1,
    );
    await db.accountsDao.upsert(bob);
    await db.postinoSettingsDao.write(accountSettingsKey(bob.id), '{"provider":"fastmail"}', at: _t);
    await mirror.reconcile();
    expect(await accounts(), [bob, _ada]);
  });
}
