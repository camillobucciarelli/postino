import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/message_embeddings_table.dart';

part 'message_embeddings_dao.g.dart';

/// The embeddings of the messages (#109), one per message: a newer model's vector replaces the older one.
@DriftAccessor(tables: [MessageEmbeddings])
class MessageEmbeddingsDao(super.attachedDatabase)
    extends DatabaseAccessor<PostinoDatabase>
    with _$MessageEmbeddingsDaoMixin {
  Future<void> save(String accountId, String messageId, String modelId, List<double> vector) => into(messageEmbeddings)
      .insertOnConflictUpdate(
        MessageEmbeddingsCompanion.insert(
          accountId: accountId,
          messageId: messageId,
          modelId: modelId,
          vector: _bytes(vector),
        ),
      );

  /// The vectors of [modelId] among the [limit] newest messages of the Account with the Etichetta [labelId].
  Future<List<List<double>>> examples(String accountId, String labelId, String modelId, {int limit = 50}) async => [
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
}
