import 'package:drift/drift.dart';

/// The embedding of each classified message (#109, ADR 0015): the examples of the Etichette automatiche come from
/// here. Local only, never synced: another device computes its own.
// ponytail: a removed message leaves its row, ignored by the joins on messages; clean up if the table grows.
@DataClassName('MessageEmbeddingRow')
class MessageEmbeddings() extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();

  /// The model that made [vector]: a row of another model is not comparable and is ignored.
  TextColumn get modelId => text()();

  /// Float32 little-endian.
  BlobColumn get vector => blob()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}
