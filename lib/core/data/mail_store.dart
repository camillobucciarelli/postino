import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/conflict.dart';
import '../domain/draft_conflict.dart';
import '../domain/draft_content.dart';
import '../domain/html_text.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_action.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import '../domain/outbox_repository.dart';
import 'action_codec.dart';
import 'outbox_store.dart';
import 'postino_database.dart';
import 'row_mappers.dart';

/// A voce of the offline queue, decoded: `expected` null forces the write.
typedef QueuedAction = ({String messageId, MailAction action, Object? expected});

@lazySingleton
class MailStore(final PostinoDatabase _db) implements InboxRepository {
  Future<void> addAccount(Account a) => _db.accountsDao.upsert(a);

  Future<List<Account>> accounts() async => [for (final r in await _db.accountsDao.byPosition()) accountOf(r)];

  Future<void> setStatus(String accountId, AccountStatus status) => _db.accountsDao.setStatus(accountId, status);

  /// Deletes the Account and everything of it here, in one transaction (#174): messages, bodies, Etichette, Bozze,
  /// queued Azioni and Conflitti, outbox, embeddings. Nothing reaches the Provider. Its synced Impostazioni di Postino
  /// (the Etichette automatiche) become tombstones dated [at] (ADR 0016): the removal reaches every device.
  Future<void> removeAccount(String accountId, {required DateTime at}) => _db.transaction(() async {
    await _db.postinoSettingsDao.tombstoneAccount(accountId, at: at);
    for (final delete in [
      _db.messagesDao.deleteByAccount,
      _db.bodiesDao.deleteByAccount,
      _db.labelsDao.deleteByAccount,
      _db.intentsDao.deleteByAccount,
      _db.conflictsDao.deleteByAccount,
      _db.draftsDao.deleteByAccount,
      _db.outboxDao.deleteByAccount,
      _db.messageEmbeddingsDao.deleteByAccount,
      _db.accountsDao.deleteByAccount,
    ]) {
      await delete(accountId);
    }
  });

  /// Drops what the Account would still send to the Provider (queued Azioni, outbox) at once, ahead of the removal
  /// (#174): a send already running finds its next row gone and sends nothing more. The Bozze stay until the
  /// removal: an upload in flight would read a missing one as «delete it on the Provider».
  Future<void> dropQueue(String accountId) => _db.transaction(() async {
    await _db.intentsDao.deleteByAccount(accountId);
    await _db.outboxDao.deleteByAccount(accountId);
  });

  Stream<List<Account>> watchAccounts() =>
      _db.accountsDao.watchByPosition().map((rows) => [for (final r in rows) accountOf(r)]);

  Future<String?> cursor(String accountId) => _db.messagesDao.cursor(accountId);

  /// True when the Account already has the message with Provider id [id].
  Future<bool> hasMessage(String accountId, String id) => _db.messagesDao.exists(accountId, id);

  /// The Provider ids of the Account's stored messages.
  Future<List<String>> messageIds(String accountId) => _db.messagesDao.ids(accountId);

  /// The Message-ID (RFC 5322) of the message with Provider id [id]: how an adapter finds it again once its id is gone.
  /// A sync may have removed the message from here (it moved); the voce queued over it kept its Message-ID.
  Future<String?> rfcMessageId(String accountId, String id) async =>
      await _db.messagesDao.rfcMessageId(accountId, id) ?? await _db.intentsDao.rfcMessageId(accountId, id);

  /// The messages of [messages] the Account does not have yet.
  Future<List<Message>> unknown(String accountId, List<Message> messages) async => [
    for (final m in messages)
      if (!await hasMessage(accountId, m.id)) m,
  ];

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  Future<void> applySync(String accountId, SyncBatch batch, {bool fullSnapshot = false}) async {
    await _db.messagesDao.applySync(accountId, batch, fullSnapshot: fullSnapshot);
    // ponytail: only here, a page of Conversazione says nothing about the Bozze. A window remains if the Gmail
    // history does not list the new DRAFT yet: the acknowledged row goes, and comes back with the next sync.
    await _db.draftsDao.reconcile(accountId);
  }

  /// A page of the initial sync: stored right away, without touching the cursor.
  Future<void> applyPage(String accountId, List<Message> messages, Map<String, MessageBody> bodies) async {
    await _db.messagesDao.applySync(
      accountId,
      SyncBatch(cursor: '', messages: messages, bodies: bodies),
      saveCursor: false,
    );
  }

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

  @override
  Stream<Message?> watchMessage(String accountId, String messageId) =>
      _db.messagesDao.watchOne(accountId, messageId).map((r) => r == null ? null : messageOf(r.$1, r.$2));

  Future<void> saveBody(String accountId, String messageId, MessageBody body) =>
      _db.bodiesDao.saveBody(accountId, messageId, body);

  /// Marks the Conversazione's unread messages read here and queues the Azione (ADR 0008).
  Future<void> markConversationRead(String accountId, String conversationId) async =>
      queue(accountId, await _db.messagesDao.unreadIn(accountId, conversationId), const MarkRead());

  /// Applies [action] to the messages here at once and queues it (ADR 0008), in one transaction;
  /// [heldUntil] keeps the voci «trattenute» until then (their Annulla is still offered).
  Future<void> queue(String accountId, Iterable<String> messageIds, MailAction action, {DateTime? heldUntil}) =>
      _db.intentsDao.queue(accountId, messageIds, action, heldUntil: heldUntil?.millisecondsSinceEpoch);

  /// Annulla of a «trattenuta» Azione: out of the queue, the messages back as they were. False when none was held.
  Future<bool> cancelHeld(String accountId, Iterable<String> messageIds, MailAction action, DateTime now) =>
      _db.intentsDao.cancelHeld(accountId, messageIds, action, now: now.millisecondsSinceEpoch);

  /// The Account's voci to replay at [now], decoded; the «trattenute» ones wait for their deadline.
  Future<List<QueuedAction>> pendingActions(String accountId, DateTime now) async => [
    for (final r in await _db.intentsDao.pending(accountId, now: now.millisecondsSinceEpoch)) _queuedOf(r),
  ];

  /// The voce of [q] as it is now, about to be sent: null when it left the queue meanwhile (a Conflitto resolved,
  /// an Annulla) or is held again.
  Future<QueuedAction?> currentAction(String accountId, QueuedAction q) async =>
      switch (await _db.intentsDao.voce(accountId, q.messageId, q.action.attribute)) {
        final r? when r.heldUntil == null => _queuedOf(r),
        _ => null,
      };

  static QueuedAction _queuedOf(IntentRow r) => (
    messageId: r.messageId,
    action: actionOf(r.attribute, r.wanted),
    expected: switch (r.expected) {
      final e? => decodeValue(r.attribute, e),
      null => null,
    },
  );

  /// The voce reached the Provider, or its message is gone: it leaves the queue unless changed meanwhile.
  Future<void> actionDone(String accountId, QueuedAction q) =>
      _db.intentsDao.done(accountId, q.messageId, q.action.attribute, encodeValue(q.action.wanted));

  /// The Provider has [provider], changed elsewhere: the voce becomes a Conflitto, the local version stays.
  /// [movedTo]: the id the message has now, when the voce was queued under an older one.
  Future<void> actionConflict(String accountId, QueuedAction q, Object provider, {String? movedTo}) =>
      _db.intentsDao.conflict(
        accountId,
        q.messageId,
        q.action.attribute,
        encodeValue(q.action.wanted),
        encodeValue(provider),
        movedTo: movedTo,
      );

  /// The Provider refused the voce: it leaves the queue and the change is undone here.
  Future<void> actionRejected(String accountId, QueuedAction q) =>
      _db.intentsDao.rejected(accountId, q.messageId, q.action.attribute, encodeValue(q.action.wanted));

  @override
  Stream<List<Conflict>> watchConflicts({String? accountId}) => _db.conflictsDao
      .watch(accountId: accountId)
      .map(
        (rows) => [
          for (final r in rows)
            Conflict(
              accountId: r.accountId,
              messageId: r.messageId,
              local: actionOf(r.attribute, r.local),
              provider: decodeValue(r.attribute, r.provider),
            ),
        ],
      );

  /// Closes [c]: «tieni la mia» ([keepMine]) queues its Azione again, forced; otherwise the message takes the
  /// Provider's value here. False when it was no longer open.
  Future<bool> resolveConflict(Conflict c, {required bool keepMine}) => keepMine
      ? _db.conflictsDao.keepMine(c.accountId, c.messageId, c.local.attribute)
      : _db.conflictsDao.keepProvider(c.accountId, c.messageId, c.local.attribute);

  @override
  Stream<List<DraftConflict>> watchDraftConflicts({String? accountId}) => _db.draftsDao
      .watchConflicts(accountId: accountId)
      .map(
        (rows) => [
          for (final r in rows)
            DraftConflict(
              accountId: r.accountId,
              messageId: r.messageId,
              mine: DraftContent(
                to: lines(r.recipients),
                cc: lines(r.cc),
                bcc: lines(r.bcc),
                subject: r.subject,
                body: r.body,
              ),
              provider: r.conflict!,
            ),
        ],
      );

  /// Closes the Conflitto of a Bozza (#149): «La tua» ([keepMine]) queues it again, over the Provider's version;
  /// otherwise the Bozza takes the Provider's. False when it was no longer open.
  Future<bool> resolveDraftConflict(DraftConflict c, {required bool keepMine}) =>
      _db.draftsDao.resolve(c.accountId, c.messageId, keepMine: keepMine);

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
