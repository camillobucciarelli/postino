import 'package:drift/drift.dart';

/// Lists and the open Conversazione look messages up by Conversazione.
@TableIndex(name: 'messages_conversation', columns: {#accountId, #conversationId})
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  TextColumn get sender => text()();
  TextColumn get recipients => text()();
  TextColumn get subject => text()();
  TextColumn get snippet => text()();

  /// Milliseconds since epoch, UTC.
  IntColumn get date => integer()();
  BoolColumn get isRead => boolean()();
  BoolColumn get isStarred => boolean()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}
