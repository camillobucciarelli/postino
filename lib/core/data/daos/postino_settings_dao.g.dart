// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'postino_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$PostinoSettingsDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $PostinoSettingsTable get postinoSettings => attachedDatabase.postinoSettings;
  PostinoSettingsDaoManager get managers => PostinoSettingsDaoManager(this);
}

class PostinoSettingsDaoManager {
  final _$PostinoSettingsDaoMixin _db;
  PostinoSettingsDaoManager(this._db);
  $$PostinoSettingsTableTableManager get postinoSettings =>
      $$PostinoSettingsTableTableManager(_db.attachedDatabase, _db.postinoSettings);
}
