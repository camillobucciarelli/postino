import 'package:drift/drift.dart';

import '../../domain/message.dart';

@DataClassName('LabelRow')
class Labels() extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<LabelKind>()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}
