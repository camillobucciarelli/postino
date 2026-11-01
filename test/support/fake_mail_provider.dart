import 'dart:async';
import 'dart:typed_data';

import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

Message msg(
  String id, {
  DateTime? date,
  String from = 'ada@example.com',
  String? fromName,
  List<String> to = const ['me@example.com'],
  List<String> cc = const [],
  String subject = 'Oggetto',
  String snippet = 'Anteprima',
  bool isRead = false,
  bool isStarred = false,
  List<String> labelIds = const [inboxLabelId],
  String? conversationId,
}) => Message(
  id: id,
  messageId: '<$id@example.com>',
  conversationId: conversationId ?? 't-$id',
  labelIds: labelIds,
  isRead: isRead,
  isStarred: isStarred,
  from: from,
  fromName: fromName,
  to: to,
  cc: cc,
  subject: subject,
  snippet: snippet,
  date: date ?? DateTime.utc(2026, 1, 1),
);

/// In-memory Provider: tests simulate incoming mail, changes elsewhere, offline, AuthFailure and a lost change signal.
class FakeMailProvider implements MailProvider {
  final _messages = <String, Message>{};

  /// Outside the sync window (older than 90 days): only [fetchConversation] and [fetchBody] see them.
  final _old = <String, Message>{};
  final _log = <(int, Message?, String)>[]; // (version, upsert, removedId)
  late final StreamController<ChangeSignal> _changes =
      StreamController.broadcast(
        onListen: () =>
            _changes.add(_signalUp ? ChangeSignal.up : ChangeSignal.down),
      );
  int _version = 0;

  /// Cursors older than this have expired.
  int _oldest = 0;
  bool _offline = false;
  bool _authBroken = false;
  bool _signalUp = true;
  bool _rateLimited = false;
  DateTime? _retryAfter;

  /// Messages per page of the initial sync, and, when set, the number of pages after which it fails.
  int pageSize = 1000;
  int? failAfterPages;

  /// While set, syncs wait for it to complete: a slow Provider.
  Completer<void>? hold;

  /// While set, [fetchConversation] and [setRead] answer only once it completes: in-flight requests.
  Completer<void>? holdConversation, holdRead;
  final sent = <OutgoingMessage>[];

  /// While set, [setRead] fails as offline even though the syncs work: a passing replay failure.
  bool failSetRead = false;

  /// Every [setRead] that reached the Provider: (ids, read).
  final readCalls = <(List<String>, bool)>[];

  /// Body kind of [fetchBody]; the sync bodies are plain text.
  BodyKind bodyKind = BodyKind.testo;

  /// Bodies by message id, for the syncs and [fetchBody]; the others are «Corpo di `id`».
  final bodies = <String, MessageBody>{};

  /// Attachment contents by (message id, attachment id); [attach] lists them in the message's body too.
  final attachmentData = <(String, String), Uint8List>{};

  /// Every [fetchAttachment] that reached the Provider: (message id, attachment id).
  final attachmentCalls = <(String, String)>[];

  /// While set, [fetchAttachment] reports half done and answers once it completes, or the download is cancelled.
  Completer<void>? holdAttachment;

  /// The Account's Etichette; same as the recorded Gmail fixture by default.
  final labels = [
    const Label(id: 'Label_12', name: 'Viaggi', kind: LabelKind.etichetta),
  ];

  /// The Bozze folder, by Message-ID; a saved or delivered Bozza is also a DRAFT message for the syncs.
  final drafts = <String, OutgoingMessage>{};

  /// Every [saveDraft] that reached the Provider: (Message-ID, isNew).
  final draftCalls = <(String, bool)>[];

  /// What the sync engine asked for: initial syncs, and the delta of the last incremental one.
  int initialSyncs = 0;
  SyncBatch? lastIncremental;

  // --- simulation ---
  /// Gives message [messageId] an attachment [name] holding [bytes]; its id is `att-<name>`.
  Attachment attach(
    String messageId,
    String name,
    List<int> bytes, {
    String? mimeType,
  }) {
    final a = Attachment(
      id: 'att-$name',
      name: name,
      size: bytes.length,
      mimeType: mimeType,
    );
    attachmentData[(messageId, a.id)] = Uint8List.fromList(bytes);
    final old = bodies[messageId] ?? _defaultBody(messageId);
    bodies[messageId] = MessageBody(
      old.content,
      old.kind,
      attachments: [...?old.attachments, a],
    );
    return a;
  }

  MessageBody _defaultBody(String id, [BodyKind kind = BodyKind.testo]) =>
      MessageBody('Corpo di $id', kind);

  /// A new message, or a change to one (read, Stella, Etichette) made elsewhere.
  void deliver(Message m) {
    _messages[m.id] = m;
    _log.add((++_version, m, ''));
    if (_signalUp) _changes.add(ChangeSignal.changed);
  }

  /// A message older than the sync window: the syncs never bring it.
  void deliverOutsideWindow(Message m) => _old[m.id] = m;

  void removeRemotely(String id) {
    _messages.remove(id);
    _log.add((++_version, null, id));
    if (_signalUp) _changes.add(ChangeSignal.changed);
  }

  /// A Bozza written by another client: in the Bozze folder, with its HTML body; its Provider id is `d-<n>`.
  void deliverDraft(OutgoingMessage d) {
    drafts[d.messageId] = d;
    final id = _draftIds[d.messageId] ??= 'd-${++_draftSeq}';
    bodies[id] = MessageBody(d.body, BodyKind.html);
    deliver(
      Message(
        id: id,
        messageId: d.messageId,
        conversationId: d.messageId,
        labelIds: const ['DRAFT'],
        isRead: true,
        isStarred: false,
        from: d.from,
        to: d.to,
        cc: d.cc,
        subject: d.subject,
        snippet: d.body,
        date: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  /// A Bozza deleted (or sent) by another client.
  void removeDraftRemotely(String messageId) {
    drafts.remove(messageId);
    if (_draftIds.remove(messageId) case final id?) removeRemotely(id);
  }

  final _draftIds = <String, String>{};
  int _draftSeq = 0;

  void goOffline() => _offline = true;
  void goOnline() => _offline = false;
  void rateLimit([bool on = true, DateTime? retryAfter]) {
    _rateLimited = on;
    _retryAfter = retryAfter;
  }

  void breakAuth() => _authBroken = true;
  void restoreAuth() => _authBroken = false;

  /// The Provider forgets the history: every cursor handed out so far has expired.
  void expireCursors() => _oldest = _version + 1;

  /// IDLE drops: no more change signals until [restoreSignal].
  void dropSignal() => _signal(ChangeSignal.down);
  void restoreSignal() => _signal(ChangeSignal.up);

  void _signal(ChangeSignal s) {
    _signalUp = s == ChangeSignal.up;
    _changes.add(s);
  }

  Failure? get _failure => _authBroken
      ? const AuthFailure()
      : _offline
      ? const OfflineFailure()
      : _rateLimited
      ? RateLimitFailure(retryAfter: _retryAfter)
      : null;

  // --- MailProvider ---
  Result<T> _guard<T>(T Function() ok) {
    final f = _failure;
    return f != null ? Err(f) : Ok(ok());
  }

  @override
  Future<Result<void>> refreshAuth() async => _guard(() {});

  Map<String, MessageBody> _inboxBodies(Iterable<Message> ms) => {
    for (final m in ms)
      if (m.labelIds.contains(inboxLabelId))
        m.id: bodies[m.id] ?? _defaultBody(m.id),
  };

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) async {
    await hold?.future;
    if (_failure == null && onPage != null) {
      final all = _messages.values.toList();
      for (var i = 0; i < all.length; i += pageSize) {
        if (failAfterPages == i ~/ pageSize) {
          return const Err(UnexpectedFailure('boom'));
        }
        final page = all.skip(i).take(pageSize).toList();
        await onPage(page, _inboxBodies(page));
      }
    }
    return _guard(() {
      initialSyncs++;
      return SyncBatch(
        cursor: '$_version',
        messages: _messages.values.toList(),
        labels: labels,
        bodies: _inboxBodies(_messages.values),
      );
    });
  }

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) async {
    if (_failure == null && int.parse(cursor) < _oldest) {
      await hold?.future;
      return const Err(NotFoundFailure());
    }
    // Answered now, delivered after [hold]: an in-flight response.
    final result = _guard(() {
      // Only the latest operation per id counts (a Provider delta is final state).
      final latest = <String, (int, Message?, String)>{};
      for (final e in _log) {
        if (e.$1 > int.parse(cursor)) latest[e.$2?.id ?? e.$3] = e;
      }
      final messages = [
        for (final e in latest.values)
          if (e.$2 != null) e.$2!,
      ];
      return lastIncremental = SyncBatch(
        cursor: '$_version',
        messages: messages,
        removedMessageIds: [
          for (final e in latest.values)
            if (e.$2 == null) e.$3,
        ],
        bodies: _inboxBodies(messages),
      );
    });
    await hold?.future;
    return result;
  }

  @override
  Stream<ChangeSignal> get changes => _changes.stream;

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) async {
    final f = _failure;
    if (f != null) return Err(f);
    return _messages.containsKey(messageId) || _old.containsKey(messageId)
        ? Ok(bodies[messageId] ?? _defaultBody(messageId, bodyKind))
        : const Err(NotFoundFailure());
  }

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) async {
    // Answered now, delivered after [holdConversation]: an in-flight snapshot.
    final result = _guard(
      () => [
        for (final m in [..._old.values, ..._messages.values])
          if (m.conversationId == conversationId) m,
      ],
    );
    await holdConversation?.future;
    return result;
  }

  @override
  Future<Result<void>> setRead(
    List<String> messageIds, {
    required bool read,
  }) async {
    await holdRead?.future;
    return failSetRead
        ? const Err(OfflineFailure())
        : _guard(() {
            readCalls.add((messageIds, read));
            for (final id in messageIds) {
              if (_old[id] case final m?) _old[id] = withRead(m, read);
              if (_messages[id] case final m?) deliver(withRead(m, read));
            }
          });
  }

  @override
  Future<Result<Uint8List>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final f = _failure;
    if (f != null) return Err(f);
    attachmentCalls.add((messageId, attachmentId));
    final data = attachmentData[(messageId, attachmentId)];
    if (data == null) return const Err(NotFoundFailure());
    if (holdAttachment case final hold?) {
      onProgress?.call(0.5);
      var cancelled = false;
      await Future.any([
        hold.future,
        if (cancel != null) cancel.then((_) => cancelled = true),
      ]);
      if (cancelled) return const Err(CancelledFailure());
    }
    onProgress?.call(1);
    return Ok(data);
  }

  @override
  Future<Result<void>> send(OutgoingMessage message) async => _guard(() {
    // Idempotent on Message-ID.
    if (sent.every((s) => s.messageId != message.messageId)) sent.add(message);
  });

  @override
  Future<Result<void>> saveDraft(
    OutgoingMessage draft, {
    required bool isNew,
  }) async {
    final f = _failure;
    if (f != null) return Err(f);
    draftCalls.add((draft.messageId, isNew));
    if (!isNew && !drafts.containsKey(draft.messageId)) {
      return const Err(NotFoundFailure());
    }
    deliverDraft(draft);
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteDraft(String messageId) async {
    final f = _failure;
    if (f != null) return Err(f);
    if (!drafts.containsKey(messageId)) return const Err(NotFoundFailure());
    removeDraftRemotely(messageId);
    return const Ok(null);
  }
}

/// [m] read (or unread) elsewhere.
Message withRead(Message m, bool read) => Message(
  id: m.id,
  messageId: m.messageId,
  conversationId: m.conversationId,
  labelIds: m.labelIds,
  isRead: read,
  isStarred: m.isStarred,
  from: m.from,
  fromName: m.fromName,
  to: m.to,
  cc: m.cc,
  subject: m.subject,
  snippet: m.snippet,
  date: m.date,
);
