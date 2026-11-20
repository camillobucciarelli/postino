import '../domain/account.dart';
import '../domain/inbox_repository.dart' show InboxEntry;
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
  hasAttachments: r.hasAttachments,
);

/// One row per Conversazione of [rows] (message, its Account, label ids and whether the view shows it), which come
/// newest first: the first of each Conversazione is its latest message, and keeps the order. The row is made of the
/// messages the view shows only (`MessagesDao.inView`), as the Conversazione opened from it.
// ponytail: grouped in Dart over every message of the listed Conversazioni; a GROUP BY if big inboxes get slow.
List<InboxEntry> inboxEntriesOf(List<(AccountRow, MessageRow, List<String>, bool)> rows) {
  final groups = <(String, String), List<(AccountRow, MessageRow, List<String>, bool)>>{};
  // What the Conversazione opened from the view shows; its place too follows its latest message shown.
  for (final r in rows) {
    if (r.$4) (groups[(r.$1.id, r.$2.conversationId)] ??= []).add(r);
  }
  return [
    for (final g in groups.values)
      InboxEntry(
        account: accountOf(g.first.$1),
        // The Conversazione's labels: those of any of its messages shown.
        message: messageOf(g.first.$2, {for (final r in g) ...r.$3}.toList()),
        count: g.length,
        unread: g.any((r) => !r.$2.isRead),
      ),
  ];
}

/// The addresses a row keeps one per line.
List<String> lines(String s) => [
  for (final l in s.split('\n'))
    if (l.isNotEmpty) l,
];

/// A stored body with its attachments.
MessageBody bodyOf(BodyRow b) => MessageBody(b.body, b.kind, attachments: b.attachments);

/// The address of an Account of this database; null once it is removed (ADR 0016), a sync in flight included.
Future<String?> addressOf(PostinoDatabase db, String accountId) async =>
    (await db.accountsDao.byPosition()).where((a) => a.id == accountId).firstOrNull?.address;
