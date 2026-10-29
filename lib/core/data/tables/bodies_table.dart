import 'package:drift/drift.dart';

import '../../domain/message.dart';

/// Downloaded message bodies, apart from [Messages] so the lists stay light.
@DataClassName('BodyRow')
class Bodies extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  TextColumn get body => text()();

  /// HTML or plain text; the default only fills the rows of v1-v4, which the migration then sorts.
  TextColumn get kind =>
      textEnum<BodyKind>().withDefault(Constant(BodyKind.testo.name))();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}
