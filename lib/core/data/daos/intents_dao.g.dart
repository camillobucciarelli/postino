// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intents_dao.dart';

// ignore_for_file: type=lint
mixin _$IntentsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $IntentsTable get intents => attachedDatabase.intents;
  $ConflictsTable get conflicts => attachedDatabase.conflicts;
  $MessagesTable get messages => attachedDatabase.messages;
  IntentsDaoManager get managers => IntentsDaoManager(this);
}

class IntentsDaoManager {
  final _$IntentsDaoMixin _db;
  IntentsDaoManager(this._db);
  $$IntentsTableTableManager get intents =>
      $$IntentsTableTableManager(_db.attachedDatabase, _db.intents);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db.attachedDatabase, _db.conflicts);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
}
