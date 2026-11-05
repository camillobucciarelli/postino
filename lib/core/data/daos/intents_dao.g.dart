// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intents_dao.dart';

// ignore_for_file: type=lint
mixin _$IntentsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $IntentsTable get intents => attachedDatabase.intents;
  $LabelIntentsTable get labelIntents => attachedDatabase.labelIntents;
  $MessageLabelsTable get messageLabels => attachedDatabase.messageLabels;
  IntentsDaoManager get managers => IntentsDaoManager(this);
}

class IntentsDaoManager {
  final _$IntentsDaoMixin _db;
  IntentsDaoManager(this._db);
  $$IntentsTableTableManager get intents =>
      $$IntentsTableTableManager(_db.attachedDatabase, _db.intents);
  $$LabelIntentsTableTableManager get labelIntents =>
      $$LabelIntentsTableTableManager(_db.attachedDatabase, _db.labelIntents);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db.attachedDatabase, _db.messageLabels);
}
