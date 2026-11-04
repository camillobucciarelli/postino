// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intents_dao.dart';

// ignore_for_file: type=lint
mixin _$IntentsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $IntentsTable get intents => attachedDatabase.intents;
  IntentsDaoManager get managers => IntentsDaoManager(this);
}

class IntentsDaoManager {
  final _$IntentsDaoMixin _db;
  IntentsDaoManager(this._db);
  $$IntentsTableTableManager get intents => $$IntentsTableTableManager(_db.attachedDatabase, _db.intents);
}
