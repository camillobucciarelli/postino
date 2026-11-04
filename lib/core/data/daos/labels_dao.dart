import 'package:drift/drift.dart';

import '../../domain/message.dart';
import '../postino_database.dart';
import '../tables/labels_table.dart';

part 'labels_dao.g.dart';

/// The Account's labels. The `*In` methods add to a [Batch] of the caller's transaction (ADR 0008).
@DriftAccessor(tables: [Labels])
class LabelsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$LabelsDaoMixin {
  /// Drops every label of the Account: a full snapshot brings them all again.
  void deleteAllIn(Batch b, String accountId) => b.deleteWhere(labels, (t) => t.accountId.equals(accountId));

  void upsertAllIn(Batch b, String accountId, List<Label> all) => b.insertAll(labels, [
    for (final l in all) LabelsCompanion.insert(accountId: accountId, id: l.id, name: l.name, kind: l.kind),
  ], mode: InsertMode.insertOrReplace);

  /// The Account's own Etichette, by name.
  Stream<List<LabelRow>> watchLabels(String accountId) =>
      (select(labels)
            ..where((t) => t.accountId.equals(accountId) & t.kind.equalsValue(LabelKind.etichetta))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();
}
