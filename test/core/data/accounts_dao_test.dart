// The Accounts table as the mirror of the synced voci needs it (#142, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';

Account _a(String id, {int color = 0, int position = 0, AccountStatus status = AccountStatus.attivo}) => Account(
  id: id,
  address: '$id@example.com',
  provider: ProviderKind.gmail,
  color: color,
  position: position,
  status: status,
);

void main() {
  late PostinoDatabase db;
  setUp(() => db = PostinoDatabase.inMemory());
  tearDown(() => db.close());

  test('listed by position, then id, so equal positions keep a stable order', () async {
    for (final a in [_a('c', position: 1), _a('b'), _a('a', position: 1)]) {
      await db.accountsDao.upsert(a);
    }
    expect((await db.accountsDao.byPosition()).map((r) => r.id), ['b', 'a', 'c']);
  });

  test('updateSettings takes address, color and position and keeps the status', () async {
    await db.accountsDao.upsert(_a('a', status: AccountStatus.daRicollegare));
    await db.accountsDao.updateSettings(
      const Account(id: 'a', address: 'new@example.com', provider: ProviderKind.gmail, color: 5, position: 3),
    );
    final r = (await db.accountsDao.byPosition()).single;
    expect((r.address, r.color, r.position, r.status), ('new@example.com', 5, 3, AccountStatus.daRicollegare));
  });

  test('remove takes the Account and its local mail, and leaves the other Accounts alone', () async {
    for (final id in ['a', 'b']) {
      await db.accountsDao.upsert(_a(id));
      await db.customStatement("INSERT INTO labels VALUES ('$id', 'L1', 'L1', 'etichetta')");
      await db.customStatement("INSERT INTO sync_cursors (account_id, cursor) VALUES ('$id', '7')");
      await db.messageEmbeddingsDao.save(id, 'm1', 'model', [0.5]);
    }
    await db.accountsDao.remove('a');

    expect((await db.accountsDao.byPosition()).map((r) => r.id), ['b']);
    for (final t in db.allTables) {
      if (!t.columnsByName.containsKey('account_id')) continue;
      final ids = await db.customSelect('SELECT account_id FROM ${t.actualTableName}').get();
      expect(ids.map((r) => r.read<String>('account_id')), everyElement('b'), reason: t.actualTableName);
    }
    expect(await db.select(db.labels).get(), hasLength(1));
  });
}
