import 'package:drift/drift.dart';

import '../../domain/account.dart';
import '../postino_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$AccountsDaoMixin {
  Future<void> upsert(Account a) => into(accounts).insert(
    AccountsCompanion.insert(
      id: a.id,
      address: a.address,
      provider: a.provider,
      color: a.color,
      position: a.position,
      status: a.status,
    ),
    mode: InsertMode.insertOrReplace,
  );

  /// Takes address, color and position from the synced voce, keeping the status of this device.
  Future<void> updateSettings(Account a) => (update(accounts)..where((t) => t.id.equals(a.id))).write(
    AccountsCompanion(address: Value(a.address), color: Value(a.color), position: Value(a.position)),
  );

  /// Whether the Account [id] is here.
  Future<bool> exists(String id) async =>
      await (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull() != null;

  Future<void> setStatus(String id, AccountStatus status) =>
      (update(accounts)..where((t) => t.id.equals(id))).write(AccountsCompanion(status: Value(status)));

  /// By position, then id: the order stays stable even when two Accounts share a position.
  SimpleSelectStatement<$AccountsTable, AccountRow> _byPosition() =>
      select(accounts)..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.id)]);

  Future<List<AccountRow>> byPosition() => _byPosition().get();

  Stream<List<AccountRow>> watchByPosition() => _byPosition().watch();

  /// Removes the Account's own row (Rimozione di un Account, #174).
  Future<void> deleteByAccount(String accountId) => (delete(accounts)..where((t) => t.id.equals(accountId))).go();
}
