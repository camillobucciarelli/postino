// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_embeddings_dao.dart';

// ignore_for_file: type=lint
mixin _$MessageEmbeddingsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $MessageEmbeddingsTable get messageEmbeddings =>
      attachedDatabase.messageEmbeddings;
  $MessagesTable get messages => attachedDatabase.messages;
  $MessageLabelsTable get messageLabels => attachedDatabase.messageLabels;
  $BodiesTable get bodies => attachedDatabase.bodies;
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
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db.attachedDatabase, _db.messageLabels);
  $$BodiesTableTableManager get bodies =>
      $$BodiesTableTableManager(_db.attachedDatabase, _db.bodies);
}
