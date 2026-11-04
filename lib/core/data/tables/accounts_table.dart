import 'package:drift/drift.dart';

import '../../domain/account.dart';

@DataClassName('AccountRow')
class Accounts() extends Table {
  TextColumn get id => text()();
  TextColumn get address => text()();
  TextColumn get provider => textEnum<ProviderKind>()();
  IntColumn get color => integer()();
  IntColumn get position => integer()();
  TextColumn get status => textEnum<AccountStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}
