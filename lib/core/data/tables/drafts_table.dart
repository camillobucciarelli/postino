import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/message.dart';
import 'bodies_table.dart';

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

  /// A reply (#37, v12: #36 takes v11 with its outbox): In-Reply-To, the References one per line, the Provider's Conversazione id;
  /// a forward: the attachments taken over, as JSON. Null for a plain new message.
  TextColumn get inReplyTo => text().nullable()();
  TextColumn get references => text().nullable()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get attachments => text().map(const ForwardedAttachmentsConverter()).nullable()();

  /// Milliseconds since epoch, UTC.
  IntColumn get updatedAt => integer()();
  BoolColumn get pending => boolean()();
  BoolColumn get synced => boolean()();
  BoolColumn get remoteKnown => boolean()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}

/// [ForwardedAttachment]s as JSON: the [AttachmentsConverter] shape plus `sourceMessageId`.
class ForwardedAttachmentsConverter extends TypeConverter<List<ForwardedAttachment>, String> {
  const ForwardedAttachmentsConverter();

  static const _inner = AttachmentsConverter();

  @override
  List<ForwardedAttachment> fromSql(String fromDb) => [
    for (final a in jsonDecode(fromDb) as List)
      ForwardedAttachment(a['sourceMessageId'] as String, _inner.fromSql(jsonEncode([a])).single),
  ];

  @override
  String toSql(List<ForwardedAttachment> value) => jsonEncode([
    for (final a in value)
      {
        'sourceMessageId': a.sourceMessageId,
        ...(jsonDecode(_inner.toSql([a.attachment])) as List).single as Map,
      },
  ]);
}
