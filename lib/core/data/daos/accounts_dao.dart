import 'package:drift/drift.dart';

import '../../domain/account.dart';
import '../postino_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<PostinoDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.attachedDatabase);

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

  Future<List<AccountRow>> byPosition() =>
      (select(accounts)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
}
