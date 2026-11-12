import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../domain/auto_label_classifier.dart';

import '../postino_database.dart';
import '../tables/bodies_table.dart';
import '../tables/message_embeddings_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'message_embeddings_dao.g.dart';

/// The embeddings of the messages (#109), one per message: a newer model's vector replaces the older one.
@DriftAccessor(tables: [MessageEmbeddings, Messages, MessageLabels, Bodies])
class MessageEmbeddingsDao(super.attachedDatabase)
    extends DatabaseAccessor<PostinoDatabase>
    with _$MessageEmbeddingsDaoMixin {
  /// Nothing when the message is gone meanwhile (its Account removed, #174): checked in the same transaction.
  Future<void> save(String accountId, String messageId, String modelId, List<double> vector) => transaction(() async {
    final known = await (select(
      messages,
    )..where((t) => t.accountId.equals(accountId) & t.id.equals(messageId))).getSingleOrNull();
    if (known == null) return;
    await into(messageEmbeddings).insertOnConflictUpdate(
      MessageEmbeddingsCompanion.insert(
        accountId: accountId,
        messageId: messageId,
        modelId: modelId,
        vector: _bytes(vector),
      ),
    );
  });

  /// The vectors of [modelId] among the [limit] newest messages of the Account with the Etichetta [labelId].
  Future<List<List<double>>> examples(
    String accountId,
    String labelId,
    String modelId, {
    int limit = maxAutoLabelExamples,
  }) async => [
    for (final r in await customSelect(
      'SELECT e.vector FROM message_embeddings e JOIN ( '
      'SELECT m.id, m.date FROM messages m JOIN message_labels l ON l.account_id = m.account_id AND l.message_id = m.id '
      'WHERE m.account_id = ?1 AND l.label_id = ?2 ORDER BY m.date DESC LIMIT ?4 '
      ') n ON n.id = e.message_id WHERE e.account_id = ?1 AND e.model_id = ?3',
      variables: [Variable(accountId), Variable(labelId), Variable(modelId), Variable(limit)],
      readsFrom: {messageEmbeddings},
    ).get())
      _vector(r.read<Uint8List>('vector')),
  ];

  /// Among the [limit] newest messages of the Account with the Etichetta [labelId], those without a vector of
  /// [modelId], with their body if downloaded.
  Future<List<(MessageRow, BodyRow?)>> unembedded(
    String accountId,
    String labelId,
    String modelId, {
    int limit = maxAutoLabelExamples,
  }) async {
    final query =
        select(messages).join([
            innerJoin(
              messageLabels,
              messageLabels.accountId.equalsExp(messages.accountId) &
                  messageLabels.messageId.equalsExp(messages.id) &
                  messageLabels.labelId.equals(labelId),
            ),
            leftOuterJoin(
              bodies,
              bodies.accountId.equalsExp(messages.accountId) & bodies.messageId.equalsExp(messages.id),
            ),
            leftOuterJoin(
              messageEmbeddings,
              messageEmbeddings.accountId.equalsExp(messages.accountId) &
                  messageEmbeddings.messageId.equalsExp(messages.id) &
                  messageEmbeddings.modelId.equals(modelId),
            ),
          ])
          ..where(messages.accountId.equals(accountId))
          ..orderBy([OrderingTerm.desc(messages.date)])
          ..limit(limit);
    return [
      for (final r in await query.get())
        if (r.readTableOrNull(messageEmbeddings) == null) (r.readTable(messages), r.readTableOrNull(bodies)),
    ];
  }

  /// The messages [ids] of the Account still in cache, with their body if downloaded: those a background sync left to
  /// the Etichettatura automatica of the next one (#212). At most SQLite's 999 variables' worth.
  Future<List<(MessageRow, BodyRow?)>> withBodies(String accountId, List<String> ids) async {
    final query = select(messages).join([
      leftOuterJoin(bodies, bodies.accountId.equalsExp(messages.accountId) & bodies.messageId.equalsExp(messages.id)),
    ])..where(messages.accountId.equals(accountId) & messages.id.isIn(ids));
    return [for (final r in await query.get()) (r.readTable(messages), r.readTableOrNull(bodies))];
  }

  static Uint8List _bytes(List<double> v) {
    final out = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      out.setFloat32(i * 4, v[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }

  static List<double> _vector(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return [for (var i = 0; i < bytes.length ~/ 4; i++) data.getFloat32(i * 4, Endian.little)];
  }

  /// Removes the Account's message embeddings (Rimozione di un Account, #174).
  Future<void> deleteByAccount(String accountId) =>
      (delete(messageEmbeddings)..where((t) => t.accountId.equals(accountId))).go();
}
