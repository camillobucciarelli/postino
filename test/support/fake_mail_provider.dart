import 'dart:async';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart' show MimeMessage;
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/draft_content.dart';
import 'package:postino/core/domain/draft_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/mailbox.dart';
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
  String? replyTo,
  List<String> references = const [],
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
  date: date ?? DateTime.utc(2026),
  replyTo: replyTo,
  references: references,
);

/// In-memory Provider: tests simulate incoming mail, changes elsewhere, offline, AuthFailure and a lost change signal.
class FakeMailProvider() implements MailProvider {
  final _messages = <String, Message>{};

  /// Outside the sync window (older than 90 days): only [fetchConversation] and [fetchBody] see them.
  final _old = <String, Message>{};
  final _log = <(int, Message?, String)>[]; // (version, upsert, removedId)
  late final StreamController<ChangeSignal> _changes = StreamController.broadcast(
    onListen: () => _changes.add(_signalUp ? ChangeSignal.up : ChangeSignal.down),
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

  /// While set, [fetchConversation] and a read Azione answer only once it completes: in-flight requests.
  Completer<void>? holdConversation;
  Completer<void>? holdRead;

  /// Every send that reached the Provider and was not already in Inviati: (Message-ID, Provider id).
  final sent = <(String, String)>[];

  /// Every call of [send], also those that fail or find the message already in Inviati.
  int sendCalls = 0;

  /// While set, [send] waits for it before doing anything: a send in flight.
  Completer<void>? holdSend;

  /// While set, [send] refuses with it, as the Provider would for good (too big, Bozza gone).
  Failure? sendFailure;

  /// While set, a [send] that submits reports it (onSubmitted) and then fails with it, as an APPEND that failed after SMTP (#175).
  Failure? failAfterSubmit;

  /// The `submitted` flag of every [send] call, in order.
  final sendSubmitted = <bool>[];

  /// While set, the next [send] stores the message as sent but answers offline, once: a lost response.
  bool loseSendResponse = false;
  int _sentSeq = 0;

  /// While set, a read Azione fails as offline even though the syncs work: a passing replay failure.
  bool failSetRead = false;

  /// Every read Azione that reached the Provider, conflicting ones too: (`[id]`, read).
  final readCalls = <(List<String>, bool)>[];

  /// While set, an Etichetta Azione answers it even though the syncs work: a passing replay failure or a refusal.
  Failure? setLabelFailure;

  /// Every Etichetta Azione that reached the Provider, refused ones too: (message id, label id, add).
  final labelCalls = <(String, String, bool)>[];

  /// Every [applyAction] that reached the Provider: (message id, Azione, expected value).
  final actionCalls = <(String, MailAction, Object?)>[];

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

  /// While set, [fetchBody] answers only once it completes: a body download in flight.
  Completer<void>? holdBody;

  /// The Account's Etichette; same as the recorded Gmail fixture by default.
  final labels = [const Label(id: 'Label_12', name: 'Viaggi', kind: LabelKind.etichetta)];

  /// The Bozze folder, by Message-ID; a saved or delivered Bozza is also a DRAFT message for the syncs.
  final drafts = <String, OutgoingMessage>{};

  /// While set, [saveDraft] fails with it (a forwarded attachment that cannot be fetched).
  Failure? saveDraftFailure;

  /// Every [saveDraft] that reached the Provider: (Message-ID, isNew).
  final draftCalls = <(String, bool)>[];

  /// What the sync engine asked for: initial syncs, and the delta of the last incremental one.
  int initialSyncs = 0;

  /// Every [initialSync] and [incrementalSync] that reached the Provider, also those that fail.
  int syncCalls = 0;

  /// While set, [saveDraft] waits for it before doing anything: a Bozza upload in flight.
  Completer<void>? holdDraft;

  /// The Message-ID of the last [saveDraft] that reached the Provider, set before it waits for [holdDraft].
  String? draftHeld;
  SyncBatch? lastIncremental;

  // --- simulation ---
  /// Gives message [messageId] an attachment [name] holding [bytes]; its id is `att-<name>`.
  Attachment attach(String messageId, String name, List<int> bytes, {String? mimeType}) {
    final a = Attachment(id: 'att-$name', name: name, size: bytes.length, mimeType: mimeType);
    attachmentData[(messageId, a.id)] = Uint8List.fromList(bytes);
    final old = bodies[messageId] ?? _defaultBody(messageId);
    bodies[messageId] = MessageBody(old.content, old.kind, attachments: [...?old.attachments, a]);
    return a;
  }

  MessageBody _defaultBody(String id, [BodyKind kind = BodyKind.testo]) => MessageBody('Corpo di $id', kind);

  /// A new message, or a change to one (read, Stella, Etichette) made elsewhere.
  /// The change signal watches the inbox only ([signal] false: a Bozza change raises none, as on Gmail).
  void deliver(Message m, {bool signal = true}) {
    _messages[m.id] = m;
    _log.add((++_version, m, ''));
    if (signal && _signalUp) _changes.add(ChangeSignal.changed);
  }

  /// A message older than the sync window: the syncs never bring it.
  void deliverOutsideWindow(Message m) => _old[m.id] = m;

  void removeRemotely(String id, {bool signal = true}) {
    _messages.remove(id);
    _log.add((++_version, null, id));
    if (signal && _signalUp) _changes.add(ChangeSignal.changed);
  }

  /// Another client gives message [id] [value] for [attribute] (`MailAction.attribute`), also while offline here.
  void changeElsewhere(String id, String attribute, Object value) =>
      deliver(withValue(_messages[id]!, attribute, value));

  /// A Bozza written by another client: in the Bozze folder, with its HTML body; its Provider id is `d-<n>`.
  void deliverDraft(OutgoingMessage d, {DateTime? date, String? conversationId}) {
    drafts[d.messageId] = d;
    final id = _draftIds[d.messageId] ??= 'd-${++_draftSeq}';
    bodies[id] = MessageBody(d.body, BodyKind.html);
    deliver(
      Message(
        id: id,
        messageId: d.messageId,
        conversationId: conversationId ?? d.messageId,
        labelIds: const ['DRAFT'],
        isRead: true,
        isStarred: false,
        from: d.from,
        to: d.to,
        cc: d.cc,
        bcc: d.bcc,
        subject: d.subject,
        snippet: d.body,
        date: date ?? DateTime.utc(2026),
      ),
      signal: false,
    );
  }

  /// A Bozza deleted (or sent) by another client.
  void removeDraftRemotely(String messageId) {
    drafts.remove(messageId);
    final id = _draftIds.remove(messageId);
    if (id != null) {
      removeRemotely(id, signal: false);
    }
  }

  final _draftIds = <String, String>{};
  int _draftSeq = 0;

  void goOffline() => _offline = true;
  void goOnline() => _offline = false;
  void rateLimit({bool on = true, DateTime? retryAfter}) {
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
      if (m.labelIds.contains(inboxLabelId)) m.id: bodies[m.id] ?? _defaultBody(m.id),
  };

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) async {
    syncCalls++;
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
        labels: [...labels],
        bodies: _inboxBodies(_messages.values),
      );
    });
  }

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) async {
    syncCalls++;
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
        labels: [...labels],
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
    await holdBody?.future;
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
      await Future.any([hold.future, if (cancel != null) cancel.then((_) => cancelled = true)]);
      if (cancelled) return const Err(CancelledFailure());
    }
    onProgress?.call(1);
    return Ok(data);
  }

  /// Idempotent on the Message-ID: a message already in Inviati is not stored twice.
  @override
  Future<Result<String>> send(
    String messageId,
    String raw, {
    String? threadId,
    bool submitted = false,
    Future<void> Function()? onSubmitted,
  }) async {
    sendCalls++;
    await holdSend?.future;
    final f = _failure ?? sendFailure;
    if (f != null) return Err(f);
    sendSubmitted.add(submitted);
    if (!submitted && failAfterSubmit != null) {
      await onSubmitted?.call();
      return Err(failAfterSubmit!);
    }
    final existing = _messages.values
        .where((m) => m.messageId == messageId && m.labelIds.contains(sentLabelId))
        .firstOrNull;
    if (existing != null) return Ok(existing.id);
    final mime = MimeMessage.parseFromText(raw);
    List<String> addresses(String h) => [
      for (final m in parseMailboxes(mime.getHeaderValue(h) ?? '')) formatMailbox(m),
    ];
    final id = 's-${++_sentSeq}';
    final from = parseMailbox(mime.getHeaderValue('from') ?? '');
    bodies[id] = MessageBody(mime.decodeTextHtmlPart() ?? '', BodyKind.html);
    deliver(
      Message(
        id: id,
        messageId: messageId,
        conversationId: threadId ?? id,
        labelIds: const [sentLabelId],
        isRead: true,
        isStarred: false,
        from: from.address,
        fromName: from.name,
        to: addresses('to'),
        cc: addresses('cc'),
        bcc: addresses('bcc'),
        subject: mime.decodeSubject() ?? '',
        snippet: mime.decodeTextPlainPart()?.trim() ?? '',
        date: DateTime.utc(2026),
      ),
      signal: false,
    );
    sent.add((messageId, id));
    // Gmail keeps the Bozza: the adapter deletes it after the send.
    if (drafts.containsKey(messageId)) removeDraftRemotely(messageId);
    if (loseSendResponse) {
      loseSendResponse = false;
      return const Err(OfflineFailure());
    }
    return Ok(id);
  }

  /// Conditional on [expected] as Gmail's (#149): a Bozza changed elsewhere ([deliverDraft]) to neither the
  /// expected nor the wanted version is [DraftDiverged], and nothing is written.
  @override
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected}) async {
    draftHeld = draft.messageId;
    await holdDraft?.future;
    final f = _failure;
    if (f != null) return Err(f);
    if (saveDraftFailure case final failure?) return Err(failure);
    draftCalls.add((draft.messageId, isNew));
    final current = drafts[draft.messageId];
    if (!isNew && current == null) {
      return const Err(NotFoundFailure());
    }
    if (!isNew && expected != null) {
      final now = DraftContent.of(current!);
      if (now.fingerprint != expected && now.fingerprint != DraftContent.of(draft).fingerprint) {
        return Ok(DraftDiverged(now));
      }
    }
    deliverDraft(draft);
    return const Ok(DraftSaved());
  }

  @override
  Future<Result<void>> deleteDraft(String messageId) async {
    final f = _failure;
    if (f != null) return Err(f);
    if (!drafts.containsKey(messageId)) return const Err(NotFoundFailure());
    removeDraftRemotely(messageId);
    return const Ok(null);
  }

  int _labelSeq = 100;

  /// Ids are `Label_<n>`; the name matches case-insensitively, as on Gmail.
  @override
  Future<Result<Label>> createLabel(String name) async => _guard(() {
    if (labels.where((l) => l.name.toLowerCase() == name.toLowerCase()).firstOrNull case final l?) return l;
    final created = Label(id: 'Label_${++_labelSeq}', name: name, kind: LabelKind.etichetta);
    labels.add(created);
    return created;
  });

  /// The conditional write of ADR 0008: applied when the attribute has [expected] or the wanted value already (or
  /// [expected] is null, or the Azione is Elimina), a Conflitto otherwise; the old `setRead`/`setLabel` hooks
  /// ([holdRead], [failSetRead], [readCalls], [setLabelFailure], [labelCalls]) still see the read and Etichette ones.
  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) async {
    final labelId = switch (action) {
      ApplyLabel(:final labelId) || RemoveLabel(:final labelId) => labelId,
      _ => null,
    };
    if (action is MarkRead || action is MarkUnread) {
      await holdRead?.future;
      if (failSetRead) return const Err(OfflineFailure());
    }
    if (_failure case final f?) return Err(f);
    actionCalls.add((messageId, action, expected));
    if (action is MarkRead || action is MarkUnread) readCalls.add(([messageId], action.wanted == true));
    if (labelId != null) {
      labelCalls.add((messageId, labelId, action.wanted == true));
      if (setLabelFailure case final f?) return Err(f);
    }
    final old = _old[messageId];
    final m = _messages[messageId] ?? old;
    if (m == null) return const Ok(ActionMessageGone());
    final current = valueOf(m, action.attribute);
    if (expected != null && action is! Delete && current != expected && current != action.wanted) {
      return Ok(ActionConflict(current));
    }
    final changed = withValue(m, action.attribute, action.wanted);
    if (old != null) {
      _old[messageId] = changed;
    } else {
      deliver(changed);
    }
    return const Ok(ActionApplied());
  }
}

/// The value of [attribute] on [m], as the Provider sees it.
Object valueOf(Message m, String attribute) => switch (attribute) {
  readAttribute => m.isRead,
  starredAttribute => m.isStarred,
  placementAttribute =>
    m.labelIds.contains(trashLabelId)
        ? Placement.trash
        : m.labelIds.contains(inboxLabelId)
        ? Placement.inbox
        : Placement.archive,
  _ => m.labelIds.contains(labelIdOf(attribute)),
};

/// [m] with [value] for [attribute]: what an Azione, here or elsewhere, does to it.
Message withValue(Message m, String attribute, Object value) {
  List<String> label(String id, {required bool on}) => [...m.labelIds.where((l) => l != id), if (on) id];
  return switch (attribute) {
    readAttribute => copyOf(m, isRead: value == true),
    starredAttribute => copyOf(
      m,
      isStarred: value == true,
      labelIds: label(starredLabelId, on: value == true),
    ),
    placementAttribute => copyOf(
      m,
      labelIds: [
        ...m.labelIds.where((l) => l != inboxLabelId && l != trashLabelId),
        if (value == Placement.inbox) inboxLabelId,
        if (value == Placement.trash) trashLabelId,
      ],
    ),
    _ => copyOf(m, labelIds: label(labelIdOf(attribute)!, on: value == true)),
  };
}

/// [m] changed elsewhere: its Etichette, read state or Stella; every other field kept.
Message copyOf(Message m, {List<String>? labelIds, bool? isRead, bool? isStarred}) => Message(
  id: m.id,
  messageId: m.messageId,
  conversationId: m.conversationId,
  labelIds: labelIds ?? m.labelIds,
  isRead: isRead ?? m.isRead,
  isStarred: isStarred ?? m.isStarred,
  from: m.from,
  fromName: m.fromName,
  to: m.to,
  cc: m.cc,
  bcc: m.bcc,
  subject: m.subject,
  snippet: m.snippet,
  date: m.date,
  replyTo: m.replyTo,
  references: m.references,
);
