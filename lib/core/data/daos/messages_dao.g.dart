// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messages_dao.dart';

// ignore_for_file: type=lint
mixin _$MessagesDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $MessagesTable get messages => attachedDatabase.messages;
  $MessageLabelsTable get messageLabels => attachedDatabase.messageLabels;
  $BodiesTable get bodies => attachedDatabase.bodies;
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  $IntentsTable get intents => attachedDatabase.intents;
  $ConflictsTable get conflicts => attachedDatabase.conflicts;
  MessagesDaoManager get managers => MessagesDaoManager(this);
}

class MessagesDaoManager {
  final _$MessagesDaoMixin _db;
  MessagesDaoManager(this._db);
  $$AccountsTableTableManager get accounts => $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$MessagesTableTableManager get messages => $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db.attachedDatabase, _db.messageLabels);
  $$BodiesTableTableManager get bodies => $$BodiesTableTableManager(_db.attachedDatabase, _db.bodies);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
  $$IntentsTableTableManager get intents => $$IntentsTableTableManager(_db.attachedDatabase, _db.intents);
  $$ConflictsTableTableManager get conflicts => $$ConflictsTableTableManager(_db.attachedDatabase, _db.conflicts);
}
