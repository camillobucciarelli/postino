import '../domain/account.dart';
import '../domain/message.dart';
import 'postino_database.dart';

/// Database rows to domain values, shared by the stores.
Account accountOf(AccountRow r) =>
    Account(id: r.id, address: r.address, provider: r.provider, color: r.color, position: r.position, status: r.status);

/// [labelIds]: only where they are read (an open Conversazione); lists pass the inbox.
Message messageOf(MessageRow r, [List<String> labelIds = const [inboxLabelId], String? snippet]) => Message(
  id: r.id,
  messageId: r.messageId,
  conversationId: r.conversationId,
  labelIds: labelIds,
  isRead: r.isRead,
  isStarred: r.isStarred,
  from: r.sender,
  fromName: r.senderName,
  to: lines(r.recipients),
  cc: lines(r.cc),
  bcc: lines(r.bcc),
  subject: r.subject,
  snippet: snippet ?? r.snippet,
  date: DateTime.fromMillisecondsSinceEpoch(r.date, isUtc: true),
  replyTo: r.replyTo,
  references: lines(r.references ?? ''),
);

/// The addresses a row keeps one per line.
List<String> lines(String s) => [
  for (final l in s.split('\n'))
    if (l.isNotEmpty) l,
];

/// A stored body with its attachments.
MessageBody bodyOf(BodyRow b) => MessageBody(b.body, b.kind, attachments: b.attachments);

/// The address of an Account of this database.
Future<String> addressOf(PostinoDatabase db, String accountId) async =>
    (await db.accountsDao.byPosition()).firstWhere((a) => a.id == accountId).address;
