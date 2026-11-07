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

  Future<void> setStatus(String id, AccountStatus status) =>
      (update(accounts)..where((t) => t.id.equals(id))).write(AccountsCompanion(status: Value(status)));

  SimpleSelectStatement<$AccountsTable, AccountRow> _byPosition() =>
      select(accounts)..orderBy([(t) => OrderingTerm.asc(t.position)]);

  Future<List<AccountRow>> byPosition() => _byPosition().get();

  Stream<List<AccountRow>> watchByPosition() => _byPosition().watch();

  /// Removes the Account's own row (Rimozione di un Account, #174).
  Future<void> deleteByAccount(String accountId) => (delete(accounts)..where((t) => t.id.equals(accountId))).go();
}
