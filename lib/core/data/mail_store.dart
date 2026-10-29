import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import 'postino_database.dart';

@lazySingleton
class MailStore implements InboxRepository {
  MailStore(this._db);
  final PostinoDatabase _db;

  Future<void> addAccount(Account a) => _db.accountsDao.upsert(a);

  Future<List<Account>> accounts() async => [
    for (final r in await _db.accountsDao.byPosition()) _account(r),
  ];

  Future<void> setStatus(String accountId, AccountStatus status) =>
      _db.accountsDao.setStatus(accountId, status);

  Stream<List<Account>> watchAccounts() => _db.accountsDao
      .watchByPosition()
      .map((rows) => [for (final r in rows) _account(r)]);

  Future<String?> cursor(String accountId) => _db.messagesDao.cursor(accountId);

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  Future<void> applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
  }) => _db.messagesDao.applySync(accountId, batch, fullSnapshot: fullSnapshot);

  /// A page of the initial sync: stored right away, without touching the cursor.
  Future<void> applyPage(
    String accountId,
    List<Message> messages,
    Map<String, MessageBody> bodies,
  ) => _db.messagesDao.applySync(
    accountId,
    SyncBatch(cursor: '', messages: messages, bodies: bodies),
    saveCursor: false,
  );

  @override
  Stream<List<InboxEntry>> watchUnifiedInbox() => _entries(null, inboxLabelId);

  @override
  Stream<List<InboxEntry>> watchMessages(String accountId, String labelId) =>
      _entries(accountId, labelId);

  /// Rows come newest first: the first of each Conversazione is its latest message, and keeps the order.
  // ponytail: grouped in Dart over every message of the listed Conversazioni; a GROUP BY if big inboxes get slow.
  Stream<List<InboxEntry>> _entries(String? accountId, String labelId) => _db
      .messagesDao
      .watchMessages(accountId: accountId, labelId: labelId)
      .map((rows) {
        final groups = <(String, String), List<(AccountRow, MessageRow)>>{};
        for (final r in rows) {
          (groups[(r.$1.id, r.$2.conversationId)] ??= []).add(r);
        }
        return [
          for (final g in groups.values)
            InboxEntry(
              account: _account(g.first.$1),
              message: _message(g.first.$2),
              count: g.length,
              unread: g.any((r) => !r.$2.isRead),
            ),
        ];
      });

  @override
  Stream<List<ConversationMessage>> watchConversation(
    String accountId,
    String conversationId,
  ) => _db.messagesDao
      .watchConversation(accountId, conversationId)
      .map(
        (rows) => [
          for (final (m, b) in rows)
            (
              message: _message(m),
              body: b == null ? null : MessageBody(b.body, b.kind),
            ),
        ],
      );

  Future<void> saveBody(String accountId, String messageId, MessageBody body) =>
      _db.messagesDao.saveBody(accountId, messageId, body);

  Future<void> markConversationRead(String accountId, String conversationId) =>
      _db.messagesDao.markConversationRead(accountId, conversationId);

  Future<List<IntentRow>> pendingIntents(String accountId) =>
      _db.intentsDao.pending(accountId);

  Future<void> readDone(
    String accountId,
    List<String> messageIds, {
    required bool isRead,
  }) => _db.intentsDao.readDone(accountId, messageIds, isRead: isRead);

  @override
  Stream<List<Label>> watchLabels(String accountId) => _db.messagesDao
      .watchLabels(accountId)
      .map(
        (rows) => [
          for (final r in rows) Label(id: r.id, name: r.name, kind: r.kind),
        ],
      );

  static Account _account(AccountRow r) => Account(
    id: r.id,
    address: r.address,
    provider: r.provider,
    color: r.color,
    position: r.position,
    status: r.status,
  );

  static Message _message(MessageRow r) => Message(
    id: r.id,
    messageId: r.messageId,
    conversationId: r.conversationId,
    labelIds: const [inboxLabelId],
    isRead: r.isRead,
    isStarred: r.isStarred,
    from: r.sender,
    to: r.recipients.split(','),
    subject: r.subject,
    snippet: r.snippet,
    date: DateTime.fromMillisecondsSinceEpoch(r.date, isUtc: true),
  );
}

@module
abstract class MailStoreModule {
  /// The UI sees the store only through [InboxRepository].
  @lazySingleton
  InboxRepository inboxRepository(MailStore store) => store;
}
