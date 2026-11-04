import 'package:drift/drift.dart' show BooleanExpressionOperators, Value, Variable;
import 'package:injectable/injectable.dart';

import '../domain/html_text.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import '../domain/outbox_repository.dart';
import 'postino_database.dart';
import 'row_mappers.dart';

/// The offline queue on the local database: Bozze (#35) and outbox (#36) rows.
@lazySingleton
class OutboxStore(final PostinoDatabase _db) implements OutboxRepository {
  // --- Bozze (#35) ---
  @override
  Future<void> saveDraft(String accountId, OutgoingMessage draft, {required int updatedAt}) =>
      _db.draftsDao.save(accountId, draft, updatedAt: updatedAt);

  @override
  Future<void> adoptDraft(String accountId, OutgoingMessage draft, {required int updatedAt}) =>
      _db.draftsDao.adopt(accountId, draft, updatedAt: updatedAt);

  @override
  Future<LocalDraft?> localDraft(String accountId, String messageId) async {
    final r = await _db.draftsDao.byId(accountId, messageId);
    if (r == null) return null;
    return (draft: _draft(r, await addressOf(_db, accountId)), pending: r.pending, updatedAt: r.updatedAt);
  }

  @override
  Future<ConversationMessage?> remoteDraft(String accountId, String messageId) async {
    final r = await _db.draftsDao.remote(accountId, messageId);
    if (r == null) return null;
    final (m, b) = r;
    return (message: messageOf(m, const [draftLabelId]), body: b == null ? null : bodyOf(b));
  }

  @override
  Future<bool> hasSiblings(String accountId, String messageId) => _db.draftsDao.hasSiblings(accountId, messageId);

  @override
  Future<List<PendingDraft>> pendingDrafts(String accountId) async {
    final from = await addressOf(_db, accountId);
    return [
      for (final r in await _db.draftsDao.pending(accountId))
        (draft: _draft(r, from), isNew: !r.synced, updatedAt: r.updatedAt),
    ];
  }

  @override
  Future<bool> isQueued(String accountId, String messageId) async =>
      await _db.outboxDao.byId(accountId, messageId) != null;

  @override
  Future<void> draftSynced(String accountId, String messageId, int updatedAt) =>
      _db.draftsDao.synced(accountId, messageId, updatedAt);

  @override
  Future<void> forgetRemoteDraft(String accountId, String messageId) =>
      _db.draftsDao.forgetRemote(accountId, messageId);

  @override
  Future<void> removeDraft(String accountId, String messageId) => _db.draftsDao.remove(accountId, messageId);

  @override
  Future<bool> rekeyDraft(String accountId, String from, String to) => _db.draftsDao.rekey(accountId, from, to);

  // --- Outbox (#36) ---
  @override
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

  @override
  Future<OutboxItem?> outgoing(String accountId, String messageId) async {
    final r = await _db.outboxDao.byId(accountId, messageId);
    return r == null ? null : _item(r);
  }

  @override
  Future<bool> outgoingReady(
    String accountId,
    String messageId, {
    required int version,
    required String raw,
    required int sendAfter,
  }) => _db.outboxDao.ready(accountId, messageId, version, raw, sendAfter);

  @override
  Future<void> dropOutgoing(String accountId, String messageId, int version) =>
      _db.outboxDao.drop(accountId, messageId, version);

  @override
  Future<bool> cancelOutgoing(String accountId, String messageId, int nowMs) =>
      _db.outboxDao.cancel(accountId, messageId, nowMs);

  @override
  Future<List<OutboxItem>> dueOutgoing(String accountId, int nowMs) async => [
    for (final r in await _db.outboxDao.due(accountId, nowMs)) _item(r),
  ];

  @override
  Future<bool> hasOutgoing(String accountId) => _db.outboxDao.any(accountId);

  @override
  Future<bool> claimOutgoing(
    String accountId,
    String messageId, {
    required int sendAfter,
    required int untilMs,
    required int nowMs,
  }) => _db.outboxDao.claim(accountId, messageId, sendAfter, untilMs, nowMs);

  @override
  Future<void> unclaimOutgoing(String accountId, String messageId) => _db.outboxDao.unclaim(accountId, messageId);

  @override
  Future<void> outgoingFailed(String accountId, String messageId, {int? version}) =>
      _db.outboxDao.markFailed(accountId, messageId, version: version);

  /// Its Conversazione is the one it replies to (#37), else the message itself, until the sync says otherwise.
  // ponytail: a full snapshot sync may drop it until the Provider lists it (a brief blink); fine for now.
  @override
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
    await (_db.delete(_db.messageLabels)..where((l) => l.accountId.equals(accountId) & l.messageId.isIn(ids))).go();
    await (_db.delete(_db.messages)..where((m) => m.accountId.equals(accountId) & m.id.isIn(ids))).go();
    // A sync may have cached the sent message already (a foreground sync beside the worker's send): that copy is
    // the Provider's, labels included, and the local one must not replace it.
    if (await _db.messagesDao.exists(accountId, providerId)) return;
    // Stored as a page: the cursor stays as it is.
    await _db.messagesDao.applySync(
      accountId,
      SyncBatch(
        cursor: '',
        messages: [
          Message(
            id: providerId,
            messageId: messageId,
            conversationId: r.conversationId ?? providerId,
            labelIds: const [sentLabelId],
            isRead: true,
            isStarred: false,
            from: await addressOf(_db, accountId),
            to: lines(r.recipients),
            cc: lines(r.cc),
            bcc: lines(r.bcc),
            subject: r.subject,
            snippet: listSnippet(r.body),
            date: DateTime.fromMillisecondsSinceEpoch(date, isUtc: true),
          ),
        ],
      ),
      saveCursor: false,
    );
  });

  static OutboxItem _item(OutboxRow r) => (
    messageId: r.messageId,
    version: r.version,
    raw: r.raw,
    conversationId: r.conversationId,
    sendAfter: r.sendAfter,
    attempted: r.attempted,
    failed: r.failed,
  );

  static OutgoingMessage _draft(DraftRow r, String from) => OutgoingMessage(
    messageId: r.messageId,
    from: from,
    to: lines(r.recipients),
    cc: lines(r.cc),
    bcc: lines(r.bcc),
    subject: r.subject,
    body: r.body,
    inReplyTo: r.inReplyTo,
    references: lines(r.references ?? ''),
    conversationId: r.conversationId,
    attachments: r.attachments ?? const [],
  );
}
