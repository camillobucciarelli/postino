// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drafts_dao.dart';

// ignore_for_file: type=lint
mixin _$DraftsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $DraftsTable get drafts => attachedDatabase.drafts;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $MessagesTable get messages => attachedDatabase.messages;
  $MessageLabelsTable get messageLabels => attachedDatabase.messageLabels;
  $BodiesTable get bodies => attachedDatabase.bodies;
  DraftsDaoManager get managers => DraftsDaoManager(this);
}

class DraftsDaoManager {
  final _$DraftsDaoMixin _db;
  DraftsDaoManager(this._db);
  $$DraftsTableTableManager get drafts => $$DraftsTableTableManager(_db.attachedDatabase, _db.drafts);
  $$AccountsTableTableManager get accounts => $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$MessagesTableTableManager get messages => $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db.attachedDatabase, _db.messageLabels);
  $$BodiesTableTableManager get bodies => $$BodiesTableTableManager(_db.attachedDatabase, _db.bodies);
}
