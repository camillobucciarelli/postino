import 'package:drift/drift.dart';

@DataClassName('MessageLabelRow')
class MessageLabels extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  TextColumn get labelId => text()();

  @override
  Set<Column> get primaryKey => {accountId, messageId, labelId};
}
