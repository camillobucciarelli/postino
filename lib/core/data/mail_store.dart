import 'package:drift/drift.dart'
    show BooleanExpressionOperators, Value, Variable;
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/html_text.dart';
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
  }) async {
    await _db.messagesDao.applySync(
      accountId,
      batch,
      fullSnapshot: fullSnapshot,
    );
    // ponytail: only here, a page of Conversazione says nothing about the Bozze. A window remains if the Gmail
    // history does not list the new DRAFT yet: the acknowledged row goes, and comes back with the next sync.
    await _db.draftsDao.reconcile(accountId);
  }

  /// A page of the initial sync: stored right away, without touching the cursor.
  Future<void> applyPage(
    String accountId,
    List<Message> messages,
    Map<String, MessageBody> bodies,
  ) async {
    await _db.messagesDao.applySync(
      accountId,
      SyncBatch(cursor: '', messages: messages, bodies: bodies),
      saveCursor: false,
    );
  }

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
          for (final (m, b, labelIds) in rows)
            (
              message: _message(m, labelIds),
              body: b == null
                  ? null
                  : MessageBody(b.body, b.kind, attachments: b.attachments),
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

  // --- Bozze (#35) ---
  Future<void> saveDraft(
    String accountId,
    OutgoingMessage draft, {
    required int updatedAt,
  }) => _db.draftsDao.save(accountId, draft, updatedAt: updatedAt);

  /// A Bozza as the Provider has it (another client's, or edited elsewhere), kept here as already synced.
  Future<void> adoptDraft(
    String accountId,
    OutgoingMessage draft, {
    required int updatedAt,
  }) => _db.draftsDao.adopt(accountId, draft, updatedAt: updatedAt);

  /// The local Bozza, whether it has edits not on the Provider yet, and its version.
  Future<({OutgoingMessage draft, bool pending, int updatedAt})?> localDraft(
    String accountId,
    String messageId,
  ) async {
    final r = await _db.draftsDao.byId(accountId, messageId);
    if (r == null) return null;
    return (
      draft: _draft(r, await _address(accountId)),
      pending: r.pending,
      updatedAt: r.updatedAt,
    );
  }

  /// The Provider's DRAFT message with this Message-ID, as stored, with its body if downloaded.
  Future<ConversationMessage?> remoteDraft(
    String accountId,
    String messageId,
  ) async {
    final r = await _db.draftsDao.remote(accountId, messageId);
    if (r == null) return null;
    final (m, b) = r;
    return (
      message: _message(m, const [draftLabelId]),
      body: b == null
          ? null
          : MessageBody(b.body, b.kind, attachments: b.attachments),
    );
  }

  /// Whether another message shares the Conversazione of this one.
  Future<bool> hasSiblings(String accountId, String messageId) =>
      _db.draftsDao.hasSiblings(accountId, messageId);

  /// The Bozze whose content is not on the Provider yet; [isNew] when it never was.
  Future<List<({OutgoingMessage draft, bool isNew, int updatedAt})>>
  pendingDrafts(String accountId) async {
    final from = await _address(accountId);
    return [
      for (final r in await _db.draftsDao.pending(accountId))
        (draft: _draft(r, from), isNew: !r.synced, updatedAt: r.updatedAt),
    ];
  }

  /// True while [messageId] waits in the outbox: a Bozza PUT then would only delay its send in the Account's queue.
  Future<bool> isQueued(String accountId, String messageId) async =>
      await _db.outboxDao.byId(accountId, messageId) != null;

  /// The content of [updatedAt] reached the Provider.
  Future<void> draftSynced(String accountId, String messageId, int updatedAt) =>
      _db.draftsDao.synced(accountId, messageId, updatedAt);

  /// The remote copy was deleted: the local Bozza is new again.
  Future<void> forgetRemoteDraft(String accountId, String messageId) =>
      _db.draftsDao.forgetRemote(accountId, messageId);

  Future<void> removeDraft(String accountId, String messageId) =>
      _db.draftsDao.remove(accountId, messageId);

  @override
  Stream<List<Message>> watchDrafts(String accountId) => _db.draftsDao
      .watchAll(accountId)
      .map(
        (rows) => [
          for (final (r, local) in rows)
            _message(r, const [
              draftLabelId,
            ], local ? listSnippet(r.snippet) : null),
        ],
      );

  // --- Outbox (#36) ---
  /// Queues [message] with its rendered MIME [raw]; it goes once [sendAfter] (ms since epoch, UTC) has passed.
  Future<void> enqueueOutgoing(
    String accountId,
    OutgoingMessage message, {
    required int version,
    required String raw,
    required int sendAfter,
  }) => _db.outboxDao.enqueue(
    OutboxCompanion.insert(
      accountId: accountId,
      messageId: message.messageId,
      version: version,
      raw: raw,
      recipients: message.to.join('\n'),
      cc: message.cc.join('\n'),
      bcc: message.bcc.join('\n'),
      subject: message.subject,
      body: message.body,
      conversationId: Value(message.conversationId),
      sendAfter: sendAfter,
    ),
  );

  /// The row of [messageId], if queued (or still being prepared).
  Future<OutboxRow?> outgoing(String accountId, String messageId) =>
      _db.outboxDao.byId(accountId, messageId);

  /// The row has its MIME and deadline; false when it was cancelled (or replaced) while preparing.
  Future<bool> outgoingReady(
    String accountId,
    String messageId, {
    required int version,
    required String raw,
    required int sendAfter,
  }) => _db.outboxDao.ready(accountId, messageId, version, raw, sendAfter);

  /// Drops the row of a preparation that failed.
  Future<void> dropOutgoing(String accountId, String messageId, int version) =>
      _db.outboxDao.drop(accountId, messageId, version);

  /// Annulla invio: true when the row was still there and no sender (another isolate) is sending it now.
  Future<bool> cancelOutgoing(String accountId, String messageId, int nowMs) =>
      _db.outboxDao.cancel(accountId, messageId, nowMs);

  /// Re-keys the local Bozza [from] as [to], as new; false when there is none.
  Future<bool> rekeyDraft(String accountId, String from, String to) =>
      _db.draftsDao.rekey(accountId, from, to);

  /// The outbox rows whose window ended by [nowMs].
  Future<List<OutboxRow>> dueOutgoing(String accountId, int nowMs) =>
      _db.outboxDao.due(accountId, nowMs);

  /// True while the Account has anything queued to send (a failed row waits for the user, not the platform).
  Future<bool> hasOutgoing(String accountId) => _db.outboxDao.any(accountId);

  /// Takes the row version read at [sendAfter] for this sender until [untilMs] (#36); false when another isolate
  /// holds it or it was cancelled and queued again meanwhile.
  Future<bool> claimOutgoing(
    String accountId,
    String messageId, {
    required int sendAfter,
    required int untilMs,
    required int nowMs,
  }) => _db.outboxDao.claim(accountId, messageId, sendAfter, untilMs, nowMs);

  /// A send failed and may be retried: the row is free again, for the next replay of either isolate.
  Future<void> unclaimOutgoing(String accountId, String messageId) =>
      _db.outboxDao.unclaim(accountId, messageId);

  /// The Provider refused the message for good: it stays, shown as failed, and is not retried.
  /// With [version], only that preparation's row.
  Future<void> outgoingFailed(
    String accountId,
    String messageId, {
    int? version,
  }) => _db.outboxDao.markFailed(accountId, messageId, version: version);

  /// Another isolate (the WorkManager sender) may have written the file: the streams read it again.
  void refreshAfterExternalWrites() => _db.markTablesUpdated(_db.allTables);

  /// The Provider has the message as [providerId]: the outbox row and the local Bozza go, and the message is
  /// stored at once under Inviati, so the folder shows it before the next sync upserts the same id.
  /// Its Conversazione is the one it replies to (#37), else the message itself, until the sync says otherwise.
  // ponytail: a full snapshot sync may drop it until the Provider lists it (a brief blink); fine for now.
  Future<void> outgoingSent(
    String accountId,
    String messageId, {
    required String providerId,
    required int date,
    required int sendAfter,
  }) => _db.transaction(() async {
    final r = await _db.outboxDao.byId(accountId, messageId);
    // Not the version that was sent (cancelled and queued again meanwhile): it stays.
    if (r == null || r.sendAfter != sendAfter) return;
    await _db.outboxDao.remove(accountId, messageId);
    await _db.draftsDao.remove(accountId, messageId);
    // The cached remote DRAFT copy goes too, or Bozze shows it again until the next sync.
    // Ids first: the label rows are what identifies the DRAFT copy.
    final ids = await _db
        .customSelect(
          'SELECT m.id FROM messages m WHERE m.account_id = ?1 AND m.message_id = ?2 '
          "AND EXISTS (SELECT 1 FROM message_labels l WHERE l.account_id = m.account_id AND l.message_id = m.id AND l.label_id = '$draftLabelId')",
          variables: [Variable(accountId), Variable(messageId)],
          readsFrom: {_db.messages, _db.messageLabels},
        )
        .map((row) => row.read<String>('id'))
        .get();
    await (_db.delete(_db.messageLabels)
          ..where((l) => l.accountId.equals(accountId) & l.messageId.isIn(ids)))
        .go();
    await (_db.delete(
      _db.messages,
    )..where((m) => m.accountId.equals(accountId) & m.id.isIn(ids))).go();
    await applyPage(accountId, [
      Message(
        id: providerId,
        messageId: messageId,
        conversationId: r.conversationId ?? providerId,
        labelIds: const [sentLabelId],
        isRead: true,
        isStarred: false,
        from: await _address(accountId),
        to: _lines(r.recipients),
        cc: _lines(r.cc),
        bcc: _lines(r.bcc),
        subject: r.subject,
        snippet: listSnippet(r.body),
        date: DateTime.fromMillisecondsSinceEpoch(date, isUtc: true),
      ),
    ], const {});
  });

  @override
  Stream<List<OutgoingEntry>> watchOutbox(String accountId) =>
      Stream.fromFuture(_address(accountId)).asyncExpand(
        (from) => _db.outboxDao
            .watch(accountId)
            .map(
              (rows) => [
                for (final r in rows)
                  OutgoingEntry(
                    message: OutgoingMessage(
                      messageId: r.messageId,
                      from: from,
                      to: _lines(r.recipients),
                      cc: _lines(r.cc),
                      bcc: _lines(r.bcc),
                      subject: r.subject,
                      body: r.body,
                    ),
                    sendAfter: r.sendAfter,
                    failed: r.failed,
                  ),
              ],
            ),
      );

  Future<String> _address(String accountId) async =>
      (await _db.accountsDao.byPosition())
          .firstWhere((a) => a.id == accountId)
          .address;

  static OutgoingMessage _draft(DraftRow r, String from) => OutgoingMessage(
    messageId: r.messageId,
    from: from,
    to: _lines(r.recipients),
    cc: _lines(r.cc),
    bcc: _lines(r.bcc),
    subject: r.subject,
    body: r.body,
    inReplyTo: r.inReplyTo,
    references: _lines(r.references ?? ''),
    conversationId: r.conversationId,
    attachments: r.attachments ?? const [],
  );

  @override
  Stream<Set<(String, String)>> watchUnreadFolders() =>
      _db.messagesDao.watchUnreadFolders();

  @override
  Stream<List<Label>> watchLabels(String accountId) => _db.messagesDao
      .watchLabels(accountId)
      .map(
        (rows) => [
          for (final r in rows) Label(id: r.id, name: r.name, kind: r.kind),
        ],
      );

  static List<String> _lines(String s) => [
    for (final l in s.split('\n'))
      if (l.isNotEmpty) l,
  ];

  static Account _account(AccountRow r) => Account(
    id: r.id,
    address: r.address,
    provider: r.provider,
    color: r.color,
    position: r.position,
    status: r.status,
  );

  /// [labelIds]: only where they are read (an open Conversazione); lists pass the inbox.
  static Message _message(
    MessageRow r, [
    List<String> labelIds = const [inboxLabelId],
    String? snippet,
  ]) => Message(
    id: r.id,
    messageId: r.messageId,
    conversationId: r.conversationId,
    labelIds: labelIds,
    isRead: r.isRead,
    isStarred: r.isStarred,
    from: r.sender,
    fromName: r.senderName,
    to: _lines(r.recipients),
    cc: _lines(r.cc),
    bcc: _lines(r.bcc),
    subject: r.subject,
    snippet: snippet ?? r.snippet,
    date: DateTime.fromMillisecondsSinceEpoch(r.date, isUtc: true),
    replyTo: r.replyTo,
    references: _lines(r.references ?? ''),
  );
}

@module
abstract class MailStoreModule {
  /// The UI sees the store only through [InboxRepository].
  @lazySingleton
  InboxRepository inboxRepository(MailStore store) => store;
}
