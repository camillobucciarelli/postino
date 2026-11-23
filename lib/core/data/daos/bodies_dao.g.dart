// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bodies_dao.dart';

// ignore_for_file: type=lint
mixin _$BodiesDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $BodiesTable get bodies => attachedDatabase.bodies;
  BodiesDaoManager get managers => BodiesDaoManager(this);
}

class BodiesDaoManager {
  final _$BodiesDaoMixin _db;
  BodiesDaoManager(this._db);
  $$BodiesTableTableManager get bodies => $$BodiesTableTableManager(_db.attachedDatabase, _db.bodies);
}
