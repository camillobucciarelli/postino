import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/html_text.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import '../domain/outbox_repository.dart';
import 'outbox_store.dart';
import 'postino_database.dart';
import 'row_mappers.dart';

@lazySingleton
class MailStore(final PostinoDatabase _db) implements InboxRepository {
  Future<void> addAccount(Account a) => _db.accountsDao.upsert(a);

  Future<List<Account>> accounts() async => [for (final r in await _db.accountsDao.byPosition()) accountOf(r)];

  Future<void> setStatus(String accountId, AccountStatus status) => _db.accountsDao.setStatus(accountId, status);

  Stream<List<Account>> watchAccounts() =>
      _db.accountsDao.watchByPosition().map((rows) => [for (final r in rows) accountOf(r)]);

  Future<String?> cursor(String accountId) => _db.messagesDao.cursor(accountId);

  /// True when the Account already has the message with Provider id [id].
  Future<bool> hasMessage(String accountId, String id) => _db.messagesDao.exists(accountId, id);

  /// The messages of [messages] the Account does not have yet.
  Future<List<Message>> unknown(String accountId, List<Message> messages) async => [
    for (final m in messages)
      if (!await hasMessage(accountId, m.id)) m,
  ];

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  /// Nothing is written for an Account removed meanwhile (ADR 0016): a sync in flight does not bring its mail back.
  Future<void> applySync(String accountId, SyncBatch batch, {bool fullSnapshot = false}) => _db.transaction(() async {
    if (!await _db.accountsDao.exists(accountId)) return;
    await _db.messagesDao.applySync(accountId, batch, fullSnapshot: fullSnapshot);
    // ponytail: only here, a page of Conversazione says nothing about the Bozze. A window remains if the Gmail
    // history does not list the new DRAFT yet: the acknowledged row goes, and comes back with the next sync.
    await _db.draftsDao.reconcile(accountId);
  });

  /// A page of the initial sync: stored right away, without touching the cursor.
  /// Nothing, as in [applySync], for an Account removed meanwhile.
  Future<void> applyPage(String accountId, List<Message> messages, Map<String, MessageBody> bodies) =>
      _db.transaction(() async {
        if (!await _db.accountsDao.exists(accountId)) return;
        await _db.messagesDao.applySync(
          accountId,
          SyncBatch(cursor: '', messages: messages, bodies: bodies),
          saveCursor: false,
        );
      });

  @override
  Stream<List<InboxEntry>> watchUnifiedInbox() => _entries(null, inboxLabelId);

  @override
  Stream<List<InboxEntry>> watchMessages(String accountId, String labelId) => _entries(accountId, labelId);

  /// Rows come newest first: the first of each Conversazione is its latest message, and keeps the order.
  // ponytail: grouped in Dart over every message of the listed Conversazioni; a GROUP BY if big inboxes get slow.
  Stream<List<InboxEntry>> _entries(String? accountId, String labelId) =>
      _db.messagesDao.watchMessages(accountId: accountId, labelId: labelId).map((rows) {
        final groups = <(String, String), List<(AccountRow, MessageRow, List<String>)>>{};
        for (final r in rows) {
          (groups[(r.$1.id, r.$2.conversationId)] ??= []).add(r);
        }
        return [
          for (final g in groups.values)
            InboxEntry(
              account: accountOf(g.first.$1),
              // The Conversazione's labels: those of any of its messages.
              message: messageOf(g.first.$2, {for (final r in g) ...r.$3}.toList()),
              count: g.length,
              unread: g.any((r) => !r.$2.isRead),
            ),
        ];
      });

  @override
  Stream<List<ConversationMessage>> watchConversation(String accountId, String conversationId) => _db.messagesDao
      .watchConversation(accountId, conversationId)
      .map(
        (rows) => [
          for (final (m, b, labelIds) in rows) (message: messageOf(m, labelIds), body: b == null ? null : bodyOf(b)),
        ],
      );

  Future<void> saveBody(String accountId, String messageId, MessageBody body) =>
      _db.bodiesDao.saveBody(accountId, messageId, body);

  Future<void> markConversationRead(String accountId, String conversationId) =>
      _db.messagesDao.markConversationRead(accountId, conversationId);

  Future<List<IntentRow>> pendingIntents(String accountId) => _db.intentsDao.pending(accountId);

  Future<void> readDone(String accountId, List<String> messageIds, {required bool isRead}) =>
      _db.intentsDao.readDone(accountId, messageIds, isRead: isRead);

  /// Puts the Etichetta on the messages here at once (or takes it off) and queues the intents (ADR 0008),
  /// in one transaction.
  Future<void> queueLabels(String accountId, Iterable<String> messageIds, String labelId, {required bool add}) =>
      _db.intentsDao.queueLabels(accountId, messageIds, labelId, add: add);

  Future<List<LabelIntentRow>> pendingLabelIntents(String accountId) => _db.intentsDao.pendingLabels(accountId);

  Future<void> labelDone(String accountId, String messageId, String labelId, {required bool added}) =>
      _db.intentsDao.labelDone(accountId, messageId, labelId, added: added);

  /// The Provider refused the intent: it leaves the queue and the change is undone here.
  Future<void> labelRejected(String accountId, String messageId, String labelId, {required bool added}) =>
      _db.intentsDao.labelRejected(accountId, messageId, labelId, added: added);

  /// An Etichetta just created on the Provider, listed before the next sync brings it.
  Future<void> saveLabel(String accountId, Label label) => _db.labelsDao.upsert(accountId, label);

  @override
  Stream<List<Message>> watchDrafts(String accountId) => _db.draftsDao
      .watchAll(accountId)
      .map(
        (rows) => [
          for (final (r, local) in rows) messageOf(r, const [draftLabelId], local ? listSnippet(r.snippet) : null),
        ],
      );

  /// Another isolate (the WorkManager sender) may have written the file: the streams read it again.
  void refreshAfterExternalWrites() => _db.markTablesUpdated(_db.allTables);

  @override
  Stream<List<OutgoingEntry>> watchOutbox(String accountId) => Stream.fromFuture(addressOf(_db, accountId)).asyncExpand(
    (from) => _db.outboxDao
        .watch(accountId)
        .map(
          (rows) => [
            for (final r in rows)
              OutgoingEntry(
                message: OutgoingMessage(
                  messageId: r.messageId,
                  from: from,
                  to: lines(r.recipients),
                  cc: lines(r.cc),
                  bcc: lines(r.bcc),
                  subject: r.subject,
                  body: r.body,
                ),
                sendAfter: r.sendAfter,
                failed: r.failed,
              ),
          ],
        ),
  );

  @override
  Stream<Set<(String, String)>> watchUnreadFolders() => _db.messagesDao.watchUnreadFolders();

  @override
  Stream<List<Label>> watchLabels(String accountId) => _db.labelsDao
      .watchLabels(accountId)
      .map((rows) => [for (final r in rows) Label(id: r.id, name: r.name, kind: r.kind)]);
}

@module
abstract class MailStoreModule() {
  /// The UI sees the store only through [InboxRepository].
  @lazySingleton
  InboxRepository inboxRepository(MailStore store) => store;

  /// The engine writes the offline queue only through [OutboxRepository].
  @lazySingleton
  OutboxRepository outboxRepository(OutboxStore store) => store;
}
