// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflicts_dao.dart';

// ignore_for_file: type=lint
mixin _$ConflictsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $ConflictsTable get conflicts => attachedDatabase.conflicts;
  $IntentsTable get intents => attachedDatabase.intents;
  ConflictsDaoManager get managers => ConflictsDaoManager(this);
}

class ConflictsDaoManager {
  final _$ConflictsDaoMixin _db;
  ConflictsDaoManager(this._db);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db.attachedDatabase, _db.conflicts);
  $$IntentsTableTableManager get intents =>
      $$IntentsTableTableManager(_db.attachedDatabase, _db.intents);
}
