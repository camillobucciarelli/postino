import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:postino/core/data/tables/messages_table.dart' show Messages;

import '../../domain/message.dart';
import '../json_objects.dart';

/// Downloaded message bodies, apart from [Messages] so the lists stay light.
@DataClassName('BodyRow')
class Bodies extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  TextColumn get body => text()();

  /// HTML or plain text; the default only fills the rows of v1-v4, which the migration then sorts.
  TextColumn get kind => textEnum<BodyKind>().withDefault(Constant(BodyKind.testo.name))();

  /// The attachments, as JSON `[{"id", "name", "size"}]` (v9); null in rows stored before, which did not know them.
  TextColumn get attachments => text().map(const AttachmentsConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}

/// [Attachment]s as JSON.
class AttachmentsConverter extends TypeConverter<List<Attachment>, String> {
  const AttachmentsConverter();

  @override
  List<Attachment> fromSql(String fromDb) => [
    for (final a in jsonObjects(jsonDecode(fromDb)))
      Attachment(
        id: a['id'] as String,
        name: a['name'] as String,
        size: a['size'] as int,
        mimeType: a['mimeType'] as String?,
      ),
  ];

  @override
  String toSql(List<Attachment> value) => jsonEncode([
    for (final a in value) {'id': a.id, 'name': a.name, 'size': a.size, if (a.mimeType != null) 'mimeType': a.mimeType},
  ]);
}
