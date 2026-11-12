// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_dao.dart';

// ignore_for_file: type=lint
mixin _$SearchDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $MessagesTable get messages => attachedDatabase.messages;
  $MessageLabelsTable get messageLabels => attachedDatabase.messageLabels;
  $BodiesTable get bodies => attachedDatabase.bodies;
  SearchDaoManager get managers => SearchDaoManager(this);
}

class SearchDaoManager {
  final _$SearchDaoMixin _db;
  SearchDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db.attachedDatabase, _db.messageLabels);
  $$BodiesTableTableManager get bodies =>
      $$BodiesTableTableManager(_db.attachedDatabase, _db.bodies);
}
