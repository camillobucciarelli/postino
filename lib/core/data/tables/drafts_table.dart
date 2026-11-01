import 'package:drift/drift.dart';

/// The Bozze (#35): each row is both the local save and the intent «make sure Bozza X has this content»
/// (ADR 0008: it merges by nature, the last one wins). [pending]: content not yet on the Provider;
/// [synced]: saved there at least once (the replay updates instead of creating);
/// [remoteKnown]: a sync listed it as a DRAFT message (a later disappearance means deleted or sent elsewhere).
// ponytail: no value-at-enqueue, Conflitti come at step 3.
@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get accountId => text()();

  /// RFC 5322 Message-ID header, the stable identity on every client.
  TextColumn get messageId => text()();

  /// One address per line, as `messages.recipients`.
  TextColumn get recipients => text()();
  TextColumn get cc => text()();
  TextColumn get bcc => text()();
  TextColumn get subject => text()();

  /// HTML.
  TextColumn get body => text()();

  /// Milliseconds since epoch, UTC.
  IntColumn get updatedAt => integer()();
  BoolColumn get pending => boolean()();
  BoolColumn get synced => boolean()();
  BoolColumn get remoteKnown => boolean()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}
