import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/draft_content.dart';
import '../../domain/message.dart';
import '../json_objects.dart';
import 'bodies_table.dart';

/// The Bozze (#35): each row is both the local save and the intent «make sure Bozza X has this content»
/// (ADR 0008: it merges by nature, the last one wins). [pending]: content not yet on the Provider;
/// [synced]: saved there at least once (the replay updates instead of creating);
/// [remoteKnown]: a sync listed it as a DRAFT message (a later disappearance means deleted or sent elsewhere).
@DataClassName('DraftRow')
class Drafts() extends Table {
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

  /// The expected value (#149, v19): the impronta (`DraftContent.fingerprint`) of the version the Provider had at the
  /// last upload or sync; null before the first one, and the replay then writes regardless.
  TextColumn get expected => text().nullable()();

  /// The Provider's version while the Bozza is in Conflitto (#149): it is not replayed until the user chooses.
  TextColumn get conflict => text().map(const DraftContentConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}

/// [ForwardedAttachment]s as JSON: the [AttachmentsConverter] shape plus `sourceMessageId`.
class const ForwardedAttachmentsConverter() extends TypeConverter<List<ForwardedAttachment>, String> {
  static const _inner = AttachmentsConverter();

  @override
  List<ForwardedAttachment> fromSql(String fromDb) => [
    for (final a in jsonObjects(jsonDecode(fromDb)))
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

/// A [DraftContent] as JSON.
class const DraftContentConverter() extends TypeConverter<DraftContent, String> {
  @override
  DraftContent fromSql(String fromDb) {
    final j = jsonDecode(fromDb) as Map<String, dynamic>;
    List<String> list(String k) => [for (final a in j[k] as List) a as String];
    return DraftContent(
      to: list('to'),
      cc: list('cc'),
      bcc: list('bcc'),
      subject: j['subject'] as String,
      body: j['body'] as String,
    );
  }

  @override
  String toSql(DraftContent value) =>
      jsonEncode({'to': value.to, 'cc': value.cc, 'bcc': value.bcc, 'subject': value.subject, 'body': value.body});
}
