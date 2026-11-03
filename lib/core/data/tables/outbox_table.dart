import 'package:drift/drift.dart';

/// The outbox (#36): each row is the intent «make sure message X is sent» (ADR 0008), with the MIME rendered at
/// Invia so the same bytes go whenever it is replayed, and the fields Inviati and the UI show while it waits.
/// It leaves once the Provider has it, or with Annulla within the window.
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get accountId => text()();

  /// RFC 5322 Message-ID header, the idempotency key on the Provider.
  TextColumn get messageId => text()();

  /// The rendered RFC 5322 text.
  TextColumn get raw => text()();

  /// One address per line, as `messages.recipients`.
  TextColumn get recipients => text()();
  TextColumn get cc => text()();
  TextColumn get bcc => text()();
  TextColumn get subject => text()();

  /// HTML.
  TextColumn get body => text()();

  /// The Gmail thread of a reply or forward (#37), sent with it so it threads in Inviati too.
  TextColumn get conversationId => text().nullable()();

  /// Milliseconds since epoch, UTC: the end of the Annulla invio window.
  IntColumn get sendAfter => integer()();

  /// Milliseconds since epoch, UTC: until then one isolate (foreground or WorkManager) owns the send of this row.
  IntColumn get claimedUntil => integer().nullable()();

  /// The Provider refused it for good (too big, Bozza gone): not retried, the UI shows it as failed.
  BoolColumn get failed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}
