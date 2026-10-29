import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../imap/imap_idle.dart';
import 'gmail_tokens.dart';
import 'google_client.dart';

/// Headers of the last [syncWindow] are synced (ADR 0003).
const syncWindow = Duration(days: 90);

/// Gmail adapter (ADR 0002): one per Account, tokens from the keychain.
// ponytail: send, drafts and attachments stay stubs until the tickets that need them (#32 and following).
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

  static const _todo = Err<Never>(UnexpectedFailure('Gmail: not yet'));

  /// Parallel message GETs; Gmail allows about 50 per second per user.
  // ponytail: one GET per message, 10 at a time; the batch endpoint if large mailboxes sync too slowly.
  static const _chunk = 10;

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
    final fetched = <String, (Message, String?)?>{};
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
  Future<Result<String>> fetchBody(String messageId) => _guard(() async {
    final j = await _get('messages/$messageId', {'format': 'full'});
    return Ok(
      await _body(
            messageId,
            j['payload'] as Map<String, dynamic>? ?? const {},
          ) ??
          '',
    );
  });

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId,
  ) async => _todo;

  @override
  Future<Result<void>> send(OutgoingMessage message) async => _todo;

  @override
  Future<Result<void>> saveDraft(OutgoingMessage draft) async => _todo;

  @override
  Future<Result<void>> deleteDraft(String messageId) async => _todo;

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
  Future<Map<String, (Message, String?)?>> _fetchAll(
    Iterable<String> ids, {
    required bool Function(String id) full,
  }) async {
    final out = <String, (Message, String?)?>{};
    final all = ids.toList();
    for (var i = 0; i < all.length; i += _chunk) {
      await Future.wait([
        for (final id in all.skip(i).take(_chunk))
          _fetch(id, full: full(id)).then((m) => out[id] = m),
      ]);
    }
    return out;
  }

  Future<(Message, String?)?> _fetch(String id, {required bool full}) async {
    final Map<String, dynamic> j;
    try {
      j = await _get('messages/$id', {
        'format': full ? 'full' : 'metadata',
        if (!full) 'metadataHeaders': ['From', 'To', 'Subject', 'Message-ID'],
      });
    } on _Failed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
    final payload = j['payload'] as Map<String, dynamic>? ?? const {};
    final headers = {
      for (final h in payload['headers'] as List? ?? const [])
        (h['name'] as String).toLowerCase(): h['value'] as String,
    };
    final labels = [
      for (final l in j['labelIds'] as List? ?? const []) l as String,
    ];
    final message = Message(
      id: id,
      messageId: headers['message-id'] ?? '',
      conversationId: j['threadId'] as String,
      labelIds: labels,
      isRead: !labels.contains('UNREAD'),
      isStarred: labels.contains('STARRED'),
      from: headers['from'] ?? '',
      // ponytail: naive split; a quoted display name with a comma ("Rossi, Ada") breaks in two.
      to: [
        for (final a in (headers['to'] ?? '').split(','))
          if (a.trim().isNotEmpty) a.trim(),
      ],
      subject: headers['subject'] ?? '',
      snippet: _unescape(j['snippet'] as String? ?? ''),
      date: DateTime.fromMillisecondsSinceEpoch(
        int.parse(j['internalDate'] as String),
        isUtc: true,
      ),
    );
    if (!full) return (message, null);
    try {
      return (message, await _body(id, payload));
    } on _Failed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }

  static Map<String, String> _inboxBodies(
    Map<String, (Message, String?)?> fetched,
  ) => {
    for (final (m, body) in fetched.values.nonNulls)
      if (body != null && m.labelIds.contains(inboxLabelId)) m.id: body,
  };

  /// The HTML part if there is one, else the plain text one.
  Future<String?> _body(String messageId, Map<String, dynamic> payload) async {
    final part = _part(payload, 'text/html') ?? _part(payload, 'text/plain');
    if (part == null) return null;
    final body = part['body'] as Map;
    // A big part comes as an attachmentId instead of inline data.
    final data =
        body['data'] as String? ??
        (await _get(
              'messages/$messageId/attachments/${body['attachmentId']}',
            ))['data']
            as String;
    // ponytail: assumes UTF-8, which Gmail uses for nearly every part; decode by the part's charset if mojibake shows up.
    return utf8.decode(
      base64Url.decode(base64Url.normalize(data)),
      allowMalformed: true,
    );
  }

  /// The first [mime] part carrying its content, inline or by attachmentId.
  static Map<String, dynamic>? _part(Map<String, dynamic> part, String mime) {
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

  /// GET on the Gmail API: refreshes an expired token first and once more on a 401; retries a 429.
  /// Failures are thrown as [_Failed], which [_guard] turns into an [Err].
  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, Object> query = const {},
  ]) async {
    var tokens = await _validTokens();
    final url = _api
        .resolve(path)
        .replace(queryParameters: query.isEmpty ? null : query);
    Future<http.Response> send() => _http
        .get(url, headers: {'authorization': 'Bearer ${tokens.access}'})
        .timeout(const Duration(seconds: 30));

    var r = await send();
    if (r.statusCode == 401) {
      tokens = await _refresh(tokens);
      r = await send();
    }
    // ponytail: three retries 1-2-4 s apart, then RateLimitFailure and the engine retries on its next poll.
    for (var wait = 1; _rateLimited(r) && wait <= 4; wait *= 2) {
      await _sleep(Duration(seconds: wait));
      r = await send();
    }
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw _Failed(switch (r.statusCode) {
      401 => const AuthFailure(),
      // Token without the Gmail scope: only a new consent fixes it.
      403
          when r.body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') ||
              r.body.contains('insufficientPermissions') =>
        const AuthFailure(),
      // An expired history cursor, or a message that no longer exists.
      404 => const NotFoundFailure(),
      _ when _rateLimited(r) => const RateLimitFailure(),
      _ => UnexpectedFailure('Gmail $path: HTTP ${r.statusCode}'),
    });
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
