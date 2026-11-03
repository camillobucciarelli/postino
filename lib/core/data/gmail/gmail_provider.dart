import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/mail_provider.dart';
import '../../domain/mailbox.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../imap/imap_idle.dart';
import '../mime.dart';
import 'gmail_tokens.dart';
import 'google_client.dart';

/// Headers of the last [syncWindow] are synced (ADR 0003).
const syncWindow = Duration(days: 90);

/// Gmail adapter (ADR 0002): one per Account, tokens from the keychain.
class GmailProvider implements MailProvider {
  GmailProvider(
    this._accountId,
    this._keychain,
    this._http,
    this._clock, {
    this._client = const GoogleClient.fromEnvironment(),
    this._sleep = Future<void>.delayed,
    this._idle = imapIdle,
  });

  final String _accountId;
  final SecureStore _keychain;
  final http.Client _http;
  final Clock _clock;
  final GoogleClient _client;
  final Future<void> Function(Duration) _sleep;
  final ImapIdle _idle;

  static final _tokenEndpoint = Uri.parse(
    'https://oauth2.googleapis.com/token',
  );
  static final _api = Uri.parse(
    'https://gmail.googleapis.com/gmail/v1/users/me/',
  );

  /// Parallel message GETs, one chunk per [_pace]: at most 40 per second.
  /// Gmail allows 250 units per second per user and a message GET costs 5, so about 50.
  // ponytail: one GET per message; the batch endpoint if large mailboxes sync too slowly.
  static const _chunk = 5;
  static const _pace = Duration(milliseconds: 125);

  /// Retries per request on a quota hit: 1, 2, 4, 8, 16 s (plus jitter), or the server's Retry-After.
  static const _retries = 5;
  static const _maxWait = 32;
  static final _random = Random();

  /// Messages per page of the initial sync.
  static const _page = 100;

  @override
  Future<Result<void>> refreshAuth() => _guard(() async {
    await _refresh(await _tokens());
    return const Ok(null);
  });

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) => _guard(() async {
    // The cursor comes first: what changes while listing is replayed by the next incremental sync.
    final cursor = (await _get('profile'))['historyId'] as String;
    final labels = [
      for (final l in (await _get('labels'))['labels'] as List? ?? const [])
        // System labels (INBOX, STARRED, UNREAD...) are inbox, Stella and read state, not Etichette.
        if (l['type'] == 'user')
          Label(
            id: l['id'] as String,
            name: l['name'] as String,
            kind: LabelKind.etichetta,
          ),
    ];
    final after =
        _clock.now().subtract(syncWindow).millisecondsSinceEpoch ~/ 1000;
    final ids = await _list({'q': 'after:$after'});
    final inbox = (await _list({'q': 'after:$after', 'labelIds': inboxLabelId}))
        .toSet();
    // Page by page: each one is handed over (and stored) before the next is fetched.
    // ponytail: a retry refetches pages already stored; skip stored ids if big mailboxes keep failing late.
    final fetched = <String, (Message, MessageBody?)?>{};
    for (var i = 0; i < ids.length; i += _page) {
      final page = await _fetchAll(
        ids.skip(i).take(_page),
        full: inbox.contains,
      );
      fetched.addAll(page);
      await onPage?.call([
        for (final (m, _) in page.values.nonNulls) m,
      ], _inboxBodies(page));
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
  Future<Result<SyncBatch>> incrementalSync(String cursor) => _guard(() async {
    final changed = <String>{}, deleted = <String>{};
    var latest = cursor;
    String? page;
    do {
      final r = await _get('history', {
        'startHistoryId': cursor,
        'pageToken': ?page,
      });
      // In order, so each message ends in its last state.
      for (final h in r['history'] as List? ?? const []) {
        for (final kind in ['messagesAdded', 'labelsAdded', 'labelsRemoved']) {
          for (final e in h[kind] as List? ?? const []) {
            final id = e['message']['id'] as String;
            changed.add(id);
            deleted.remove(id);
          }
        }
        for (final e in h['messagesDeleted'] as List? ?? const []) {
          final id = e['message']['id'] as String;
          deleted.add(id);
          changed.remove(id);
        }
      }
      latest = r['historyId'] as String? ?? latest;
      page = r['nextPageToken'] as String?;
    } while (page != null);
    // ponytail: every changed message is fetched in full; use the history labelIds to fetch metadata only if archive storms get slow.
    // ponytail: labels are refreshed by the initial sync only; a label created elsewhere shows up after the next one.
    final fetched = await _fetchAll(changed, full: (_) => true);
    return Ok(
      SyncBatch(
        cursor: latest,
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
  Stream<ChangeSignal> get changes => _idle(
    host: 'imap.gmail.com',
    user: _address,
    accessToken: () async => (await _validTokens()).access,
  );

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) => _guard(() async {
    final j = await _get('messages/$messageId', {'format': 'full'});
    return Ok(
      await _body(
            messageId,
            j['payload'] as Map<String, dynamic>? ?? const {},
          ) ??
          const MessageBody('', BodyKind.testo),
    );
  });

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) =>
      _guard(() async {
        final j = await _get('threads/$conversationId', {
          'format': 'metadata',
          'metadataHeaders': _headers,
        });
        return Ok([
          for (final m in j['messages'] as List? ?? const [])
            _parse(m as Map<String, dynamic>),
        ]);
      });

  /// One batchModify call per 1000 ids, Gmail's cap.
  @override
  Future<Result<void>> setRead(List<String> messageIds, {required bool read}) =>
      _guard(() async {
        for (var i = 0; i < messageIds.length; i += 1000) {
          await _request(
            'POST',
            'messages/batchModify',
            body: {
              'ids': messageIds.skip(i).take(1000).toList(),
              read ? 'removeLabelIds' : 'addLabelIds': ['UNREAD'],
            },
          );
        }
        return const Ok(null);
      });

  /// [attachmentId] is the part id ([_attachments]): the message comes first, then the part's data,
  /// inline or (nearly always) by Gmail's own attachmentId, which changes from one fetch to the next.
  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) => _guard(() async {
    final j = await _request(
      'GET',
      'messages/$messageId',
      query: {'format': 'full'},
      cancel: cancel,
    );
    final part = _attachmentParts(
      j['payload'] as Map<String, dynamic>? ?? const {},
    ).where((p) => p['partId'] == attachmentId).firstOrNull;
    if (part == null) throw const _Failed(NotFoundFailure());
    final body = part['body'] as Map;
    // An empty file has neither.
    if (body['data'] == null && body['attachmentId'] == null) {
      return Ok(Uint8List(0));
    }
    final data =
        body['data'] as String? ??
        (await _request(
              'GET',
              'messages/$messageId/attachments/${body['attachmentId']}',
              // Base64 in JSON: about 4/3 of the file.
              expected: (body['size'] as int? ?? 0) * 4 ~/ 3,
              onProgress: onProgress,
              cancel: cancel,
            ))['data']
            as String;
    onProgress?.call(1);
    return Ok(base64Url.decode(base64Url.normalize(data)));
  });

  /// Inviati is searched first: a message already there (a send whose answer was lost) is not sent twice.
  /// The Bozza holding the Message-ID is then deleted, best effort: Gmail does not drop it on its own.
  @override
  Future<Result<String>> send(
    String messageId,
    String raw, {
    String? threadId,
  }) => _guard(() async {
    final bare = messageId.replaceAll(RegExp('[<>]'), '');
    if (bare.isNotEmpty) {
      final sent = await _list({
        'q': 'rfc822msgid:$bare',
        'labelIds': sentLabelId,
      });
      if (sent.firstOrNull case final id?) return Ok(id);
    }
    final r = await _request(
      'POST',
      'messages/send',
      body: {
        'raw': base64Url.encode(utf8.encode(raw)),
        // Gmail threads it in the sender's mailbox only with the threadId, besides In-Reply-To/References.
        'threadId': ?threadId,
      },
    );
    if (await deleteDraft(messageId) case Err(:final failure)
        when failure is! NotFoundFailure) {
      debugPrint('[gmail] draft of sent $messageId not deleted, $failure');
    }
    return Ok(r['id'] as String);
  });

  /// Gmail draft ids by Message-ID.
  // ponytail: cache in memory, after a restart the draft is searched again; so a creation always searches
  // first (one GET more), which keeps it idempotent when a reply was lost (the queue's intent is «this Bozza exists», ADR 0008).
  final _draftIds = <String, String>{};

  @override
  Future<Result<void>> saveDraft(
    OutgoingMessage draft, {
    required bool isNew,
  }) => _guard(() async {
    final raw = switch (await renderMimeFetching(
      draft,
      _clock.now(),
      fetchAttachment,
    )) {
      Ok(:final value) => value,
      // Never NotFound: the sync engine would drop the Bozza; it stays pending and is retried.
      Err(failure: NotFoundFailure()) => throw const _Failed(
        UnexpectedFailure('forwarded attachment gone'),
      ),
      Err(:final failure) => throw _Failed(failure),
    };
    final message = {
      'raw': base64Url.encode(utf8.encode(raw)),
      // Gmail threads a Bozza by threadId, besides the headers.
      'threadId': ?draft.conversationId,
    };
    Future<void> create() async {
      final r = await _request('POST', 'drafts', body: {'message': message});
      _draftIds[draft.messageId] = r['id'] as String;
    }

    final String id;
    try {
      id = await _draftId(draft.messageId);
    } on _Failed catch (e) {
      if (!isNew || e.failure is! NotFoundFailure) rethrow;
      await create();
      return const Ok(null);
    }
    await _request('PUT', 'drafts/$id', body: {'id': id, 'message': message});
    return const Ok(null);
  });

  @override
  Future<Result<void>> deleteDraft(String messageId) => _guard(() async {
    await _request('DELETE', 'drafts/${await _draftId(messageId)}');
    _draftIds.remove(messageId);
    return const Ok(null);
  });

  /// The Gmail draft holding [messageId]: remembered, else searched with `rfc822msgid:`.
  /// The query takes the id without its angle brackets, as the Gmail search box does.
  /// An update or a delete that finds no draft (here or as a 404) throws NotFound.
  Future<String> _draftId(String messageId) async {
    if (_draftIds[messageId] case final id?) return id;
    // An empty `rfc822msgid:` would match any draft.
    if (messageId.isEmpty) throw const _Failed(NotFoundFailure());
    final r = await _get('drafts', {
      'q': 'rfc822msgid:${messageId.replaceAll(RegExp('[<>]'), '')}',
    });
    final id = (r['drafts'] as List?)?.firstOrNull?['id'] as String?;
    if (id == null) throw const _Failed(NotFoundFailure());
    return _draftIds[messageId] = id;
  }

  /// Every message id matching [query], following the pages.
  Future<List<String>> _list(Map<String, String> query) async {
    final ids = <String>[];
    String? page;
    do {
      final r = await _get('messages', {
        ...query,
        'maxResults': '500',
        'pageToken': ?page,
      });
      for (final m in r['messages'] as List? ?? const []) {
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
        for (final id in all.skip(i).take(_chunk))
          _fetch(id, full: full(id)).then((m) => out[id] = m),
      ]);
    }
    return out;
  }

  Future<(Message, MessageBody?)?> _fetch(
    String id, {
    required bool full,
  }) async {
    final Map<String, dynamic> j;
    try {
      j = await _get('messages/$id', {
        'format': full ? 'full' : 'metadata',
        if (!full) 'metadataHeaders': _headers,
      });
    } on _Failed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
    final message = _parse(j);
    if (!full) return (message, null);
    try {
      return (
        message,
        await _body(id, j['payload'] as Map<String, dynamic>? ?? const {}),
      );
    } on _Failed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }

  static const _headers = [
    'From',
    'To',
    'Cc',
    'Bcc',
    'Reply-To',
    'References',
    'Subject',
    'Message-ID',
  ];

  /// A Gmail message resource (`full` or `metadata`) as a [Message].
  static Message _parse(Map<String, dynamic> j) {
    final payload = j['payload'] as Map<String, dynamic>? ?? const {};
    final headers = {
      for (final h in payload['headers'] as List? ?? const [])
        (h['name'] as String).toLowerCase(): h['value'] as String,
    };
    final labels = [
      for (final l in j['labelIds'] as List? ?? const []) l as String,
    ];
    final from = parseMailbox(headers['from'] ?? '');
    return Message(
      id: j['id'] as String,
      messageId: headers['message-id'] ?? '',
      conversationId: j['threadId'] as String,
      labelIds: labels,
      isRead: !labels.contains('UNREAD'),
      isStarred: labels.contains('STARRED'),
      from: from.address,
      fromName: from.name,
      to: [
        for (final m in parseMailboxes(headers['to'] ?? '')) formatMailbox(m),
      ],
      cc: [
        for (final m in parseMailboxes(headers['cc'] ?? '')) formatMailbox(m),
      ],
      bcc: [
        for (final m in parseMailboxes(headers['bcc'] ?? '')) formatMailbox(m),
      ],
      subject: decodeWords(headers['subject'] ?? ''),
      snippet: _unescape(j['snippet'] as String? ?? ''),
      replyTo: switch (parseMailboxes(headers['reply-to'] ?? '')) {
        [final m, ...] => formatMailbox(m),
        _ => null,
      },
      references: (headers['references'] ?? '').trim().split(RegExp(r'\s+'))
        ..removeWhere((r) => r.isEmpty),
      date: DateTime.fromMillisecondsSinceEpoch(
        int.parse(j['internalDate'] as String),
        isUtc: true,
      ),
    );
  }

  static Map<String, MessageBody> _inboxBodies(
    Map<String, (Message, MessageBody?)?> fetched,
  ) => {
    for (final (m, body) in fetched.values.nonNulls)
      if (body != null && m.labelIds.contains(inboxLabelId)) m.id: body,
  };

  /// The HTML part if there is one, else the plain text one, with the attachments;
  /// null for a message with neither.
  Future<MessageBody?> _body(
    String messageId,
    Map<String, dynamic> payload,
  ) async {
    final html = _part(payload, 'text/html');
    final part = html ?? _part(payload, 'text/plain');
    final attachments = _attachments(payload);
    if (part == null) {
      return attachments.isEmpty
          ? null
          : MessageBody('', BodyKind.testo, attachments: attachments);
    }
    final body = part['body'] as Map;
    // A big part comes as an attachmentId instead of inline data.
    final data =
        body['data'] as String? ??
        (await _get(
              'messages/$messageId/attachments/${body['attachmentId']}',
            ))['data']
            as String;
    // ponytail: assumes UTF-8, which Gmail uses for nearly every part; decode by the part's charset if mojibake shows up.
    return MessageBody(
      utf8.decode(
        base64Url.decode(base64Url.normalize(data)),
        allowMalformed: true,
      ),
      html != null ? BodyKind.html : BodyKind.testo,
      attachments: attachments,
    );
  }

  static List<Attachment> _attachments(Map<String, dynamic> payload) => [
    for (final p in _attachmentParts(payload))
      Attachment(
        id: p['partId'] as String,
        name: p['filename'] as String? ?? '',
        size: (p['body'] as Map?)?['size'] as int? ?? 0,
        mimeType: p['mimeType'] as String?,
      ),
  ];

  /// The parts the user sees as attachments, depth first; a part without a filename has an empty name. An image the HTML shows through `cid:`
  /// (a Content-ID, not marked `attachment`) is part of the body, not an attachment.
  static Iterable<Map<String, dynamic>> _attachmentParts(
    Map<String, dynamic> part,
  ) sync* {
    final headers = _partHeaders(part);
    final body = part['body'] as Map?;
    // A filename (an empty file too), or `Content-Disposition: attachment` with content even without one
    // (its name is then empty).
    if (_isAttachment(part) &&
        ((part['filename'] as String? ?? '').isNotEmpty ||
            body?['attachmentId'] != null ||
            body?['data'] != null) &&
        (headers['content-id'] == null ||
            (headers['content-disposition'] ?? '').startsWith('attachment'))) {
      yield part;
    }
    for (final p in part['parts'] as List? ?? const []) {
      yield* _attachmentParts(p as Map<String, dynamic>);
    }
  }

  /// A part's headers by lowercase name, values lowercased.
  static Map<String, String> _partHeaders(Map<String, dynamic> part) => {
    for (final h in part['headers'] as List? ?? const [])
      (h['name'] as String).toLowerCase(): (h['value'] as String).toLowerCase(),
  };

  /// The first [mime] part carrying its content, inline or by attachmentId; attachments are skipped.
  static Map<String, dynamic>? _part(Map<String, dynamic> part, String mime) {
    if (_isAttachment(part)) return null;
    final body = part['body'] as Map?;
    if (part['mimeType'] == mime &&
        (body?['data'] != null || body?['attachmentId'] != null)) {
      return part;
    }
    for (final p in part['parts'] as List? ?? const []) {
      if (_part(p as Map<String, dynamic>, mime) case final found?) {
        return found;
      }
    }
    return null;
  }

  static bool _isAttachment(Map<String, dynamic> part) =>
      (part['filename'] as String? ?? '').isNotEmpty ||
      (_partHeaders(part)['content-disposition'] ?? '').startsWith(
        'attachment',
      );

  /// Gmail HTML-escapes snippets.
  static String _unescape(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  Future<GmailTokens?> _tokens() => GmailTokens.read(_keychain, _accountId);

  /// Tokens with an access token still valid for at least a minute.
  Future<GmailTokens> _validTokens() async {
    final tokens = await _tokens();
    if (tokens != null &&
        _clock.now().isBefore(
          tokens.expiresAt.subtract(const Duration(minutes: 1)),
        )) {
      return tokens;
    }
    return _refresh(tokens);
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, Object> query = const {},
  ]) => _request('GET', path, query: query);

  /// A call to the Gmail API: refreshes an expired token first and once more on a 401; retries a quota hit with backoff.
  /// [body] goes as JSON. Failures are thrown as [_Failed], which [_guard] turns into an [Err].
  /// [onProgress] gets the share of the response read, out of its length or else [expected] bytes;
  /// completing [cancel] aborts it.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object> query = const {},
    Object? body,
    int expected = 0,
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    var tokens = await _validTokens();
    final url = _api
        .resolve(path)
        .replace(queryParameters: query.isEmpty ? null : query);
    // 30 s for the answer to start, then 30 s at most between two chunks: a long download is fine, a stalled one is not.
    const stall = Duration(seconds: 30);
    Future<http.Response> send() async {
      final request = cancel == null
          ? http.Request(method, url)
          : http.AbortableRequest(method, url, abortTrigger: cancel);
      request.headers['authorization'] = 'Bearer ${tokens.access}';
      if (body != null) {
        request
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(body);
      }
      final r = await _http.send(request).timeout(stall);
      final total = r.contentLength ?? expected;
      var read = 0;
      final bytes = await http.ByteStream(
        r.stream.timeout(stall).map((chunk) {
          read += chunk.length;
          if (total > 0) onProgress?.call(min(1, read / total));
          return chunk;
        }),
      ).toBytes();
      return http.Response.bytes(
        bytes,
        r.statusCode,
        headers: r.headers,
        request: r.request,
      );
    }

    var r = await send();
    if (r.statusCode == 401) {
      tokens = await _refresh(tokens);
      r = await send();
    }
    // Per request, so a quota hit never aborts the page; after the last retry it is a RateLimitFailure.
    for (var n = 0; _rateLimited(r) && n < _retries; n++) {
      final after = int.tryParse(r.headers['retry-after'] ?? '');
      final wait = after != null
          ? Duration(seconds: min(after, _maxWait))
          : Duration(
              milliseconds:
                  (min(1 << n, _maxWait) *
                          1000 *
                          (1 + _random.nextDouble() / 4))
                      .round(),
            );
      await _sleep(wait);
      r = await send();
    }
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    // batchModify answers with an empty body.
    if (r.statusCode == 204) return const {};
    if (_rateLimited(r)) {
      // Never the Authorization header or the query: only method, path, status and the start of the body.
      debugPrint(
        '[gmail] rate limited: $method $path ${r.statusCode} '
        '${r.body.length > 300 ? r.body.substring(0, 300) : r.body}',
      );
    }
    throw _Failed(switch (r.statusCode) {
      401 => const AuthFailure(),
      // Token without the Gmail scope: only a new consent fixes it.
      403
          when r.body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') ||
              r.body.contains('insufficientPermissions') =>
        const AuthFailure(),
      // An expired history cursor, or a message that no longer exists.
      404 => const NotFoundFailure(),
      // A message over the 35 MB cap of messages.send.
      413 => const SizeLimitFailure(gmailSendLimitBytes),
      400
          when RegExp(
            'too large|size limit',
            caseSensitive: false,
          ).hasMatch(r.body) =>
        const SizeLimitFailure(gmailSendLimitBytes),
      _ when _rateLimited(r) => RateLimitFailure(retryAfter: _retryAfter(r)),
      _ => UnexpectedFailure('Gmail $path: HTTP ${r.statusCode}'),
    });
  }

  /// The end of a temporary block: "Retry after" plus an ISO timestamp in the body, else the Retry-After header in seconds.
  DateTime? _retryAfter(http.Response r) {
    final at = RegExp(r'Retry after (\S+?Z)').firstMatch(r.body)?.group(1);
    if (at != null) return DateTime.tryParse(at);
    final secs = int.tryParse(r.headers['retry-after'] ?? '');
    return secs == null ? null : _clock.now().add(Duration(seconds: secs));
  }

  /// Gmail answers a quota hit with 429, or with 403 and a rate-limit reason.
  static bool _rateLimited(http.Response r) =>
      r.statusCode == 429 ||
      (r.statusCode == 403 && r.body.contains('ateLimitExceeded'));

  /// A revoked or expired refresh token is the Provider's definitive refusal: [AuthFailure].
  Future<GmailTokens> _refresh(GmailTokens? old) async {
    if (old == null) throw const _Failed(AuthFailure());
    final r = await _http.post(
      _tokenEndpoint,
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': old.refresh,
        ..._client.fields,
      },
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200) {
      final fresh = GmailTokens(
        access: body['access_token'] as String,
        // Google may rotate it.
        refresh: body['refresh_token'] as String? ?? old.refresh,
        expiresAt: _clock.now().add(
          Duration(seconds: body['expires_in'] as int),
        ),
      );
      await fresh.write(_keychain, _accountId);
      return fresh;
    }
    if (r.statusCode == 401 || body['error'] == 'invalid_grant') {
      throw const _Failed(AuthFailure());
    }
    throw _Failed(UnexpectedFailure('token refresh: HTTP ${r.statusCode}'));
  }

  /// Adapters never throw: no network is [OfflineFailure], anything else [UnexpectedFailure].
  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on _Failed catch (e) {
      return Err(e.failure);
    } on http.RequestAbortedException {
      return const Err(CancelledFailure());
    } on http.ClientException {
      return const Err(OfflineFailure());
    } on TimeoutException {
      return const Err(OfflineFailure());
    } catch (e, s) {
      return Err(UnexpectedFailure(e, s));
    }
  }
}

/// A failed Gmail call, unwound to [GmailProvider._guard].
final class _Failed implements Exception {
  const _Failed(this.failure);
  final Failure failure;
}
