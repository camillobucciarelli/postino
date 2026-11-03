import 'package:drift/drift.dart';

/// Lists and the open Conversazione look messages up by Conversazione.
@TableIndex(
  name: 'messages_conversation',
  columns: {#accountId, #conversationId},
)
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();

  /// The sender's address; [senderName] its display name, if the `From` header has one (v7).
  TextColumn get sender => text()();
  TextColumn get senderName => text().nullable()();

  /// To and Cc, one `Name <address>` or bare address per line (v7: they were comma separated).
  TextColumn get recipients => text()();
  TextColumn get cc => text().withDefault(const Constant(''))();

  /// Bcc, as [cc]; only Bozze and sent messages have one (v10).
  TextColumn get bcc => text().withDefault(const Constant(''))();

  /// The `Reply-To` mailbox and the `References` Message-IDs, one per line; null in rows cached before v12 (#37; #36 takes v11 with its outbox).
  TextColumn get replyTo => text().nullable()();
  TextColumn get references => text().nullable()();
  TextColumn get subject => text()();
  TextColumn get snippet => text()();

  /// Milliseconds since epoch, UTC.
  IntColumn get date => integer()();
  BoolColumn get isRead => boolean()();
  BoolColumn get isStarred => boolean()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}
