// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attributes_dao.dart';

// ignore_for_file: type=lint
mixin _$AttributesDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $MessagesTable get messages => attachedDatabase.messages;
  $MessageLabelsTable get messageLabels => attachedDatabase.messageLabels;
  AttributesDaoManager get managers => AttributesDaoManager(this);
}

class AttributesDaoManager {
  final _$AttributesDaoMixin _db;
  AttributesDaoManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db.attachedDatabase, _db.messageLabels);
}
