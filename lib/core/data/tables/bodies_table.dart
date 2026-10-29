import 'package:drift/drift.dart';

/// Downloaded message bodies, apart from [Messages] so the lists stay light.
@DataClassName('BodyRow')
class Bodies extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}
