import 'dart:async';
import 'dart:typed_data';

import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

Message msg(
  String id, {
  DateTime? date,
  String from = 'ada@example.com',
  String subject = 'Oggetto',
  String snippet = 'Anteprima',
  bool isRead = false,
  bool isStarred = false,
  List<String> labelIds = const [inboxLabelId],
}) => Message(
  id: id,
  messageId: '<$id@example.com>',
  conversationId: 't-$id',
  labelIds: labelIds,
  isRead: isRead,
  isStarred: isStarred,
  from: from,
  to: const ['me@example.com'],
  subject: subject,
  snippet: snippet,
  date: date ?? DateTime.utc(2026, 1, 1),
);

/// In-memory Provider: tests simulate incoming mail, changes elsewhere, offline and AuthFailure.
class FakeMailProvider implements MailProvider {
  final _messages = <String, Message>{};
  final _log = <(int, Message?, String)>[]; // (version, upsert, removedId)
  final _changes = StreamController<void>.broadcast();
  int _version = 0;
  bool _offline = false;
  bool _authBroken = false;
  final sent = <OutgoingMessage>[];
  final drafts = <String, OutgoingMessage>{};

  // --- simulation ---
  void deliver(Message m) {
    _messages[m.id] = m;
    _log.add((++_version, m, ''));
    _changes.add(null);
  }

  void goOffline() => _offline = true;
  void breakAuth() => _authBroken = true;

  Failure? get _failure => _authBroken
      ? const AuthFailure()
      : _offline
      ? const OfflineFailure()
      : null;

  // --- MailProvider ---
  Result<T> _guard<T>(T Function() ok) {
    final f = _failure;
    return f != null ? Err(f) : Ok(ok());
  }

  @override
  Future<Result<void>> refreshAuth() async => _guard(() {});

  @override
  Future<Result<SyncBatch>> initialSync() async => _guard(
    () => SyncBatch(
      cursor: '$_version',
      messages: _messages.values.toList(),
      labels: const [
        Label(id: inboxLabelId, name: 'INBOX', kind: LabelKind.etichetta),
      ],
    ),
  );

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) async => _guard(
    () => SyncBatch(
      cursor: '$_version',
      messages: [
        for (final e in _log)
          if (e.$1 > int.parse(cursor) && e.$2 != null) e.$2!,
      ],
    ),
  );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<String>> fetchBody(String messageId) async {
    final f = _failure;
    if (f != null) return Err(f);
    return _messages.containsKey(messageId)
        ? Ok('Corpo di $messageId')
        : const Err(NotFoundFailure());
  }

  @override
  Future<Result<Uint8List>> fetchAttachment(
    String messageId,
    String attachmentId,
  ) async {
    final f = _failure;
    if (f != null) return Err(f);
    final m = _messages[messageId];
    final known = m?.attachments.any((a) => a.id == attachmentId) ?? false;
    return known
        ? Ok(Uint8List.fromList([1, 2, 3]))
        : const Err(NotFoundFailure());
  }

  @override
  Future<Result<void>> send(OutgoingMessage message) async => _guard(() {
    // Idempotent on Message-ID.
    if (sent.every((s) => s.messageId != message.messageId)) sent.add(message);
  });

  @override
  Future<Result<void>> saveDraft(OutgoingMessage draft) async =>
      _guard(() => drafts[draft.messageId] = draft);

  @override
  Future<Result<void>> deleteDraft(String messageId) async {
    final f = _failure;
    if (f != null) return Err(f);
    return drafts.remove(messageId) != null
        ? const Ok(null)
        : const Err(NotFoundFailure());
  }
}
