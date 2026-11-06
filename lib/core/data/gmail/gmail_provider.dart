import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/action_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../imap/imap_idle.dart';
import '../json_objects.dart';
import '../mime.dart';
import 'gmail_actions.dart';
import 'gmail_http.dart';
import 'gmail_labels.dart';
import 'gmail_message_parser.dart';
import 'google_client.dart';
import 'google_failure.dart';

/// Headers of the last [syncWindow] are synced (ADR 0003).
const syncWindow = Duration(days: 90);

/// Gmail adapter (ADR 0002): one per Account, tokens from the keychain.
class GmailProvider(
  final String _accountId,
  SecureStore keychain,
  http.Client httpClient,
  final Clock _clock, {
  GoogleClient client = const GoogleClient.fromEnvironment(),
  final Future<void> Function(Duration) _sleep = Future<void>.delayed,
  final ImapIdle _idle = imapIdle,
  Duration stall = const Duration(seconds: 30),
}) implements MailProvider {
  this : _gmail = GmailHttp(_accountId, keychain, httpClient, _clock, client: client, sleep: _sleep, stall: stall);

  final GmailHttp _gmail;
  late final _labels = GmailLabels(_gmail);
  late final _actions = GmailActions(_gmail, _labels);

  /// Parallel message GETs, one chunk per [_pace]: at most 40 per second.
  /// Gmail allows 250 units per second per user and a message GET costs 5, so about 50.
  // ponytail: one GET per message; the batch endpoint if large mailboxes sync too slowly.
  static const _chunk = 5;
  static const _pace = Duration(milliseconds: 125);

  /// Messages per page of the initial sync.
  static const _page = 100;

  @override
  Future<Result<void>> refreshAuth() => googleGuard(() async {
    await _gmail.refreshAuth();
    return const Ok(null);
  });

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) => googleGuard(() async {
    // The cursor comes first: what changes while listing is replayed by the next incremental sync.
    final cursor = (await _gmail.get('profile'))['historyId'] as String;
    final labels = await _labels.list();
    final after = _clock.now().subtract(syncWindow).millisecondsSinceEpoch ~/ 1000;
    final ids = await _list({'q': 'after:$after'});
    final inbox = (await _list({'q': 'after:$after', 'labelIds': inboxLabelId})).toSet();
    // Page by page: each one is handed over (and stored) before the next is fetched.
    // ponytail: a retry refetches pages already stored; skip stored ids if big mailboxes keep failing late.
    final fetched = <String, (Message, MessageBody?)?>{};
    for (var i = 0; i < ids.length; i += _page) {
      final page = await _fetchAll(ids.skip(i).take(_page), full: inbox.contains);
      fetched.addAll(page);
      await onPage?.call([for (final (m, _) in page.values.nonNulls) m], _inboxBodies(page));
    }
    return Ok(
      SyncBatch(
        cursor: cursor,
        labels: labels,
        messages: [for (final (m, _) in fetched.values.nonNulls) m],
        bodies: _inboxBodies(fetched),
      ),
    );
  });

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) => googleGuard(() async {
    final changed = <String>{};
    final deleted = <String>{};
    var latest = cursor;
    String? page;
    do {
      final r = await _gmail.get('history', query: {'startHistoryId': cursor, 'pageToken': ?page});
      // In order, so each message ends in its last state.
      for (final h in jsonObjects(r['history'])) {
        for (final kind in ['messagesAdded', 'labelsAdded', 'labelsRemoved']) {
          for (final e in jsonObjects(h[kind])) {
            final id = (e['message'] as Map<String, dynamic>)['id'] as String;
            changed.add(id);
            deleted.remove(id);
          }
        }
        for (final e in jsonObjects(h['messagesDeleted'])) {
          final id = (e['message'] as Map<String, dynamic>)['id'] as String;
          deleted.add(id);
          changed.remove(id);
        }
      }
      latest = r['historyId'] as String? ?? latest;
      page = r['nextPageToken'] as String?;
    } while (page != null);
    // ponytail: every changed message is fetched in full; use the history labelIds to fetch metadata only if archive storms get slow.
    final fetched = await _fetchAll(changed, full: (_) => true);
    // The history does not record label changes: the whole list comes every time.
    // ponytail: one more GET (1 quota unit) per poll; a labels-only refresh every few polls if quota ever matters.
    final labels = await _labels.list();
    return Ok(
      SyncBatch(
        cursor: latest,
        labels: labels,
        messages: [for (final (m, _) in fetched.values.nonNulls) m],
        // Gone by the time it was fetched: removed as well.
        removedMessageIds: [
          ...deleted,
          for (final MapEntry(:key, :value) in fetched.entries)
            if (value == null) key,
        ],
        bodies: _inboxBodies(fetched),
      ),
    );
  });

  /// Gmail Account ids are `gmail:<address>` (AccountsService).
  String get _address => _accountId.substring(_accountId.indexOf(':') + 1);

  @override
  Stream<ChangeSignal> get changes =>
      _idle(host: 'imap.gmail.com', user: _address, accessToken: () async => (await _gmail.validTokens()).access);

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) => googleGuard(() async {
    final j = await _gmail.get('messages/$messageId', query: {'format': 'full'});
    return Ok(
      await _body(messageId, j['payload'] as Map<String, dynamic>? ?? const {}) ??
          const MessageBody('', BodyKind.testo),
    );
  });

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) => googleGuard(() async {
    final j = await _gmail.get('threads/$conversationId', query: {'format': 'metadata', 'metadataHeaders': _headers});
    return Ok([for (final m in j['messages'] as List? ?? const []) parseGmailMessage(m as Map<String, dynamic>)]);
  });

  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) =>
      googleGuard(() async => Ok(await _actions.apply(messageId, action, expected)));

  /// [attachmentId] is the part id ([gmailAttachments]): the message comes first, then the part's data,
  /// inline or (nearly always) by Gmail's own attachmentId, which changes from one fetch to the next.
  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) => googleGuard(() async {
    final j = await _gmail.get('messages/$messageId', query: {'format': 'full'}, cancel: cancel);
    final part = gmailAttachmentParts(j['payload'] as Map<String, dynamic>? ?? const {})
        .where((p) => p['partId'] == attachmentId)
        .firstOrNull;
    if (part == null) throw const GoogleFailed(NotFoundFailure());
    final body = part['body'] as Map;
    // An empty file has neither.
    if (body['data'] == null && body['attachmentId'] == null) {
      return Ok(Uint8List(0));
    }
    final data =
        body['data'] as String? ??
        (await _gmail.get(
              'messages/$messageId/attachments/${body['attachmentId']}',
              // Base64 in JSON: about 4/3 of the file.
              expected: (body['size'] as int? ?? 0) * 4 ~/ 3,
              onProgress: onProgress,
              cancel: cancel,
            ))['data']
            as String;
    onProgress?.call(1);
    return Ok(decodeGmailData(data));
  });

  /// Inviati is searched first: a message already there (a send whose answer was lost) is not sent twice.
  /// The Bozza holding the Message-ID is then deleted, best effort: Gmail does not drop it on its own.
  @override
  Future<Result<String>> send(String messageId, String raw, {String? threadId}) => googleGuard(() async {
    final bare = messageId.replaceAll(RegExp('[<>]'), '');
    String? id;
    if (bare.isNotEmpty) {
      final sent = await _list({'q': 'rfc822msgid:$bare', 'labelIds': sentLabelId});
      id = sent.firstOrNull;
    }
    // Already in Inviati (a lost answer): not sent again, but its Bozza may still be there.
    id ??=
        (await _gmail.send(
              'POST',
              'messages/send',
              body: {
                'raw': base64Url.encode(utf8.encode(raw)),
                // Gmail threads it in the sender's mailbox only with the threadId, besides In-Reply-To/References.
                'threadId': ?threadId,
              },
            ))['id']
            as String;
    if (await deleteDraft(messageId) case Err(:final failure) when failure is! NotFoundFailure) {
      debugPrint('[gmail] draft of sent $messageId not deleted, $failure');
    }
    return Ok(id);
  });

  @override
  Future<Result<Label>> createLabel(String name) => googleGuard(() async => Ok(await _labels.create(name)));

  /// Adds the label [labelId] to message [messageId] (with [add] false, removes it); idempotent.
  /// [NotFoundFailure] when the message is gone.
  Future<Result<void>> setLabel(String messageId, String labelId, {required bool add}) => googleGuard(() async {
    await _labels.set(messageId, labelId, add: add);
    return const Ok(null);
  });

  /// Gmail draft ids by Message-ID.
  // ponytail: cache in memory, after a restart the draft is searched again; so a creation always searches
  // first (one GET more), which keeps it idempotent when a reply was lost (the queue's intent is «this Bozza exists», ADR 0008).
  final _draftIds = <String, String>{};

  @override
  Future<Result<void>> saveDraft(OutgoingMessage draft, {required bool isNew}) => googleGuard(() async {
    final raw = switch (await renderMimeFetching(draft, _clock.now(), fetchAttachment)) {
      Ok(:final value) => value,
      // Never NotFound: the sync engine would drop the Bozza; it stays pending and is retried.
      Err(failure: NotFoundFailure()) => throw const GoogleFailed(UnexpectedFailure('forwarded attachment gone')),
      Err(:final failure) => throw GoogleFailed(failure),
    };
    final message = {
      'raw': base64Url.encode(utf8.encode(raw)),
      // Gmail threads a Bozza by threadId, besides the headers.
      'threadId': ?draft.conversationId,
    };
    Future<void> create() async {
      final r = await _gmail.send('POST', 'drafts', body: {'message': message});
      _draftIds[draft.messageId] = r['id'] as String;
    }

    final String id;
    try {
      id = await _draftId(draft.messageId);
    } on GoogleFailed catch (e) {
      if (!isNew || e.failure is! NotFoundFailure) rethrow;
      await create();
      return const Ok(null);
    }
    await _gmail.send('PUT', 'drafts/$id', body: {'id': id, 'message': message});
    return const Ok(null);
  });

  @override
  Future<Result<void>> deleteDraft(String messageId) => googleGuard(() async {
    await _gmail.send('DELETE', 'drafts/${await _draftId(messageId)}');
    _draftIds.remove(messageId);
    return const Ok(null);
  });

  /// The Gmail draft holding [messageId]: remembered, else searched with `rfc822msgid:`.
  /// The query takes the id without its angle brackets, as the Gmail search box does.
  /// An update or a delete that finds no draft (here or as a 404) throws NotFound.
  Future<String> _draftId(String messageId) async {
    if (_draftIds[messageId] case final id?) return id;
    // An empty `rfc822msgid:` would match any draft.
    if (messageId.isEmpty) throw const GoogleFailed(NotFoundFailure());
    final r = await _gmail.get('drafts', query: {'q': 'rfc822msgid:${messageId.replaceAll(RegExp('[<>]'), '')}'});
    final id = jsonObjects(r['drafts']).firstOrNull?['id'] as String?;
    if (id == null) throw const GoogleFailed(NotFoundFailure());
    return _draftIds[messageId] = id;
  }

  /// Every message id matching [query], following the pages.
  Future<List<String>> _list(Map<String, String> query) async {
    final ids = <String>[];
    String? page;
    do {
      final r = await _gmail.get('messages', query: {...query, 'maxResults': '500', 'pageToken': ?page});
      for (final m in jsonObjects(r['messages'])) {
        ids.add(m['id'] as String);
      }
      page = r['nextPageToken'] as String?;
    } while (page != null);
    return ids;
  }

  /// Fetches [ids], [_chunk] at a time; null for a message gone in the meantime.
  /// [full] says which ones come with their body.
  Future<Map<String, (Message, MessageBody?)?>> _fetchAll(
    Iterable<String> ids, {
    required bool Function(String id) full,
  }) async {
    final out = <String, (Message, MessageBody?)?>{};
    final all = ids.toList();
    for (var i = 0; i < all.length; i += _chunk) {
      if (i > 0) await _sleep(_pace);
      await Future.wait([
        for (final id in all.skip(i).take(_chunk)) _fetch(id, full: full(id)).then((m) => out[id] = m),
      ]);
    }
    return out;
  }

  Future<(Message, MessageBody?)?> _fetch(String id, {required bool full}) async {
    final Map<String, dynamic> j;
    try {
      j = await _gmail.get(
        'messages/$id',
        query: {'format': full ? 'full' : 'metadata', if (!full) 'metadataHeaders': _headers},
      );
    } on GoogleFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
    final message = parseGmailMessage(j);
    if (!full) return (message, null);
    try {
      return (message, await _body(id, j['payload'] as Map<String, dynamic>? ?? const {}));
    } on GoogleFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }

  static const _headers = ['From', 'To', 'Cc', 'Bcc', 'Reply-To', 'References', 'Subject', 'Message-ID'];

  static Map<String, MessageBody> _inboxBodies(Map<String, (Message, MessageBody?)?> fetched) => {
    for (final (m, body) in fetched.values.nonNulls)
      if (body != null && m.labelIds.contains(inboxLabelId)) m.id: body,
  };

  /// The HTML part if there is one, else the plain text one, with the attachments;
  /// null for a message with neither.
  Future<MessageBody?> _body(String messageId, Map<String, dynamic> payload) async {
    final part = gmailTextPart(payload);
    if (part == null) return gmailBody(payload, null, null);
    final body = part['body'] as Map;
    // A big part comes as an attachmentId instead of inline data.
    final data =
        body['data'] as String? ??
        (await _gmail.get('messages/$messageId/attachments/${body['attachmentId']}'))['data'] as String;
    return gmailBody(payload, part, data);
  }
}
