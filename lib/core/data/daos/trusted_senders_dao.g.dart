// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trusted_senders_dao.dart';

// ignore_for_file: type=lint
mixin _$TrustedSendersDaoMixin on DatabaseAccessor<PostinoDatabase> {
  $TrustedSendersTable get trustedSenders => attachedDatabase.trustedSenders;
  TrustedSendersDaoManager get managers => TrustedSendersDaoManager(this);
}

class TrustedSendersDaoManager {
  final _$TrustedSendersDaoMixin _db;
  TrustedSendersDaoManager(this._db);
  $$TrustedSendersTableTableManager get trustedSenders =>
      $$TrustedSendersTableTableManager(
        _db.attachedDatabase,
        _db.trustedSenders,
      );
}
