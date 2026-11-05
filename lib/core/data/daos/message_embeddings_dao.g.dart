// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_embeddings_dao.dart';

// ignore_for_file: type=lint
mixin _$MessageEmbeddingsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $MessageEmbeddingsTable get messageEmbeddings =>
      attachedDatabase.messageEmbeddings;
  MessageEmbeddingsDaoManager get managers => MessageEmbeddingsDaoManager(this);
}

class MessageEmbeddingsDaoManager {
  final _$MessageEmbeddingsDaoMixin _db;
  MessageEmbeddingsDaoManager(this._db);
  $$MessageEmbeddingsTableTableManager get messageEmbeddings =>
      $$MessageEmbeddingsTableTableManager(
        _db.attachedDatabase,
        _db.messageEmbeddings,
      );
}
