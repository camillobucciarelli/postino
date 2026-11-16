import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/action_outcome.dart';
import '../../domain/draft_content.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/provider_search_page.dart';
import '../../domain/result.dart';
import '../../domain/search_query.dart';
import '../imap/imap_idle.dart';
import '../json_objects.dart';
import '../mime.dart';
import '../oauth/oauth_failed.dart';
import '../oauth/oauth_guard.dart';
import 'gmail_actions.dart';
import 'gmail_cursor.dart';
import 'gmail_http.dart';
import 'gmail_label_edits.dart';
import 'gmail_labels.dart';
import 'gmail_message_parser.dart';
import 'gmail_search.dart';
import 'google_client.dart';

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
  // The stored copy of a message, if the history may change it without a download (#322).
  // [withBody]: null unless its body is stored too.
  final Future<Message?> Function(String id, {bool withBody})? storedMessage,
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
  Future<Result<void>> refreshAuth() => oauthGuard(() async {
    await _gmail.refreshAuth();
    return const Ok(null);
  });

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) => oauthGuard(() async {
    // The cursor comes first: what changes while listing is replayed by the next incremental sync.
    final historyId = (await _gmail.get('profile'))['historyId'] as String;
    final labels = await _labels.list();
    final after = _clock.now().subtract(syncWindow).millisecondsSinceEpoch ~/ 1000;
    final ids = await _list({'q': 'after:$after'});
    final inbox = (await _list({'q': 'after:$after', 'labelIds': inboxLabelId})).toSet();
    // Page by page: each one is handed over (and stored) before the next is fetched.
    // ponytail: a retry refetches pages already stored; skip stored ids if big mailboxes keep failing late.
    final fetched = <String, (Message, MessageBody?)?>{};
    final failed = <String, Failure>{};
    for (var i = 0; i < ids.length; i += _page) {
      final page = await _fetchAll(ids.skip(i).take(_page), full: inbox.contains);
      fetched.addAll(page.fetched);
      failed.addAll(page.failed);
      await onPage?.call([for (final (m, _) in page.fetched.values.nonNulls) m], _inboxBodies(page.fetched));
    }
    // ponytail: a message left behind by the very first sync (none stored yet) comes with an incremental one, which may
    // notify it although it is old (#39); mark those retries as quiet if that is ever seen.
    final cursor = GmailCursor(historyId).after(historyId, settled: const [], failed: failed.keys, now: _clock.now());
    return Ok(
      SyncBatch(
        cursor: cursor.encode(),
        labels: labels,
        messages: [for (final (m, _) in fetched.values.nonNulls) m],
        bodies: _inboxBodies(fetched),
        deferredMessageIds: failed.keys.toList(),
        deferred: failed.values.firstOrNull,
      ),
    );
  });

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) => oauthGuard(() async {
    final was = GmailCursor.decode(cursor);
    final changed = <String>{};
    final deleted = <String>{};
    final edits = GmailLabelEdits();
    var latest = was.historyId;
    String? page;
    do {
      final r = await _gmail.get('history', query: {'startHistoryId': was.historyId, 'pageToken': ?page});
      // In order, so each message ends in its last state.
      for (final h in jsonObjects(r['history'])) {
        for (final kind in ['messagesAdded', 'labelsAdded', 'labelsRemoved']) {
          for (final e in jsonObjects(h[kind])) {
            final id = (e['message'] as Map<String, dynamic>)['id'] as String;
            deleted.remove(id);
            if (kind == 'messagesAdded') {
              changed.add(id);
              edits.forget(id);
            } else if (!changed.contains(id)) {
              edits.add(
                id,
                added: kind == 'labelsAdded',
                labels: [for (final l in e['labelIds'] as List? ?? const []) l as String],
              );
            }
          }
        }
        for (final e in jsonObjects(h['messagesDeleted'])) {
          final id = (e['message'] as Map<String, dynamic>)['id'] as String;
          deleted.add(id);
          changed.remove(id);
          edits.forget(id);
        }
      }
      latest = r['historyId'] as String? ?? latest;
      page = r['nextPageToken'] as String?;
    } while (page != null);
    // A label change needs no download for a message stored here, unless it is waiting for a retry (#322) or enters
    // the inbox without its body, which the inbox keeps (ADR 0003).
    final edited = <Message>[];
    for (final id in edits.ids) {
      final stored = was.retries.containsKey(id) ? null : await storedMessage?.call(id);
      final next = stored == null ? null : edits.applyTo(stored);
      final entersInbox =
          next != null && next.labelIds.contains(inboxLabelId) && !stored!.labelIds.contains(inboxLabelId);
      if (next == null || entersInbox && await storedMessage!(id, withBody: true) == null) {
        changed.add(id);
      } else {
        edited.add(next);
      }
    }
    // The messages an earlier sync left behind once their wait is over (#252); one the history touches again is
    // retried now, in `changed` already (#322).
    changed.addAll(was.due(_clock.now()));
    // ponytail: every added message is fetched in full; metadata only if archive storms get slow.
    final (:fetched, :failed) = await _fetchAll(changed, full: (_) => true);
    // The history does not record label changes: the whole list comes every time.
    // ponytail: one more GET (1 quota unit) per poll; a labels-only refresh every few polls if quota ever matters.
    final labels = await _labels.list();
    // From the end of the downloads: a long batch does not leave its retries already due.
    final next = was.after(latest, settled: {...fetched.keys, ...deleted}, failed: failed.keys, now: _clock.now());
    return Ok(
      SyncBatch(
        cursor: next.encode(),
        labels: labels,
        messages: [...edited, for (final (m, _) in fetched.values.nonNulls) m],
        // Gone by the time it was fetched: removed as well.
        removedMessageIds: [
          ...deleted,
          for (final MapEntry(:key, :value) in fetched.entries)
            if (value == null) key,
        ],
        bodies: _inboxBodies(fetched),
        deferredMessageIds: failed.keys.toList(),
        deferred: [
          for (final MapEntry(:key, :value) in failed.entries)
            if (!was.retries.containsKey(key)) value,
        ].firstOrNull,
      ),
    );
  });

  /// Gmail Account ids are `gmail:<address>` (AccountsService).
  String get _address => _accountId.substring(_accountId.indexOf(':') + 1);

  @override
  Stream<ChangeSignal> get changes =>
      _idle(host: 'imap.gmail.com', user: _address, accessToken: () async => (await _gmail.validTokens()).access);

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) => oauthGuard(() async {
    final j = await _gmail.get('messages/$messageId', query: {'format': 'full'});
    return Ok(
      await _body(messageId, j['payload'] as Map<String, dynamic>? ?? const {}) ??
          const MessageBody('', BodyKind.testo),
    );
  });

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) => oauthGuard(() async {
    final j = await _gmail.get('threads/$conversationId', query: {'format': 'metadata', 'metadataHeaders': _headers});
    return Ok([for (final m in j['messages'] as List? ?? const []) parseGmailMessage(m as Map<String, dynamic>)]);
  });

  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) =>
      oauthGuard(() async => Ok(await _actions.apply(messageId, action, expected)));

  /// [attachmentId] is the part id ([gmailAttachments]): the message comes first, then the part's data,
  /// inline or (nearly always) by Gmail's own attachmentId, which changes from one fetch to the next.
  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) => oauthGuard(() async {
    final j = await _gmail.get('messages/$messageId', query: {'format': 'full'}, cancel: cancel);
    final part = gmailAttachmentParts(j['payload'] as Map<String, dynamic>? ?? const {})
        .where((p) => p['partId'] == attachmentId)
        .firstOrNull;
    if (part == null) throw const OAuthFailed(NotFoundFailure());
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
  Future<Result<String>> send(
    String messageId,
    String raw, {
    String? threadId,
    bool submitted = false,
    Future<void> Function()? onSubmitted,
  }) => oauthGuard(() async {
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
  Future<Result<Label>> createLabel(String name) => oauthGuard(() async => Ok(await _labels.create(name)));

  @override
  Future<Result<ProviderSearchPage>> search(SearchQuery query, {String? pageToken, Set<String> stored = const {}}) =>
      oauthGuard(() async {
        final page = await gmailSearch(
          _gmail,
          query,
          pageToken: pageToken,
          stored: stored,
          fetch: (ids) async {
            final (:fetched, :failed) = await _fetchAll(ids, full: (_) => false);
            // A search page is whole or fails: no cursor would retry what it left out.
            if (failed.values.firstOrNull case final f?) throw OAuthFailed(f);
            return [for (final (m, _) in fetched.values.nonNulls) m];
          },
        );
        return Ok(page);
      });

  /// Adds the label [labelId] to message [messageId] (with [add] false, removes it); idempotent.
  /// [NotFoundFailure] when the message is gone.
  Future<Result<void>> setLabel(String messageId, String labelId, {required bool add}) => oauthGuard(() async {
    await _labels.set(messageId, labelId, add: add);
    return const Ok(null);
  });

  /// Gmail draft ids by Message-ID.
  // ponytail: cache in memory, after a restart the draft is searched again; so a creation always searches
  // first (one GET more), which keeps it idempotent when a reply was lost (the queue's intent is «this Bozza exists», ADR 0008).
  final _draftIds = <String, String>{};

  /// With [expected], the Bozza on Gmail is read first (`drafts.get`, `format=full`) and compared by impronta: Gmail
  /// has no conditional write (#149). One gone (a 404: deleted, or sent, elsewhere) is [NotFoundFailure].
  @override
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected}) =>
      oauthGuard(() async {
        final raw = switch (await renderMimeFetching(draft, _clock.now(), fetchAttachment)) {
          Ok(:final value) => value,
          // Never NotFound: the sync engine would drop the Bozza; it stays pending and is retried.
          Err(failure: NotFoundFailure()) => throw const OAuthFailed(UnexpectedFailure('forwarded attachment gone')),
          Err(:final failure) => throw OAuthFailed(failure),
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
        } on OAuthFailed catch (e) {
          if (!isNew || e.failure is! NotFoundFailure) rethrow;
          await create();
          return const Ok(DraftSaved());
        }
        if (!isNew && expected != null) {
          final current = await _remoteDraft(id);
          final fingerprint = current.fingerprint;
          if (fingerprint != expected && fingerprint != DraftContent.of(draft).fingerprint) {
            return Ok(DraftDiverged(current));
          }
        }
        await _gmail.send('PUT', 'drafts/$id', body: {'id': id, 'message': message});
        return const Ok(DraftSaved());
      });

  /// The Bozza [id] as Gmail has it now.
  Future<DraftContent> _remoteDraft(String id) async {
    final j = await _gmail.get('drafts/$id', query: {'format': 'full'});
    final m = j['message'] as Map<String, dynamic>;
    return gmailDraftContent(m, await _body(m['id'] as String, m['payload'] as Map<String, dynamic>? ?? const {}));
  }

  @override
  Future<Result<void>> deleteDraft(String messageId) => oauthGuard(() async {
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
    if (messageId.isEmpty) throw const OAuthFailed(NotFoundFailure());
    final r = await _gmail.get('drafts', query: {'q': 'rfc822msgid:${messageId.replaceAll(RegExp('[<>]'), '')}'});
    final id = jsonObjects(r['drafts']).firstOrNull?['id'] as String?;
    if (id == null) throw const OAuthFailed(NotFoundFailure());
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

  /// Fetches [ids], [_chunk] at a time: null for a message gone in the meantime, in `failed` one that did not come
  /// (a stall, a 5xx, an answer it cannot read: #252). A refused login, a rate limit or no network stops them all:
  /// only a request stuck on its own is left behind, never a whole mailbox the network dropped.
  /// [full] says which ones come with their body.
  Future<({Map<String, (Message, MessageBody?)?> fetched, Map<String, Failure> failed})> _fetchAll(
    Iterable<String> ids, {
    required bool Function(String id) full,
  }) async {
    final fetched = <String, (Message, MessageBody?)?>{};
    final failed = <String, Failure>{};
    final all = ids.toList();
    for (var i = 0; i < all.length; i += _chunk) {
      if (i > 0) await _sleep(_pace);
      await Future.wait([
        for (final id in all.skip(i).take(_chunk))
          oauthGuard(() async => Ok(await _fetch(id, full: full(id)))).then(
            (r) => switch (r) {
              Ok(:final value) => fetched[id] = value,
              Err(failure: final f && (AuthFailure() || RateLimitFailure() || OfflineFailure(stalled: false))) =>
                throw OAuthFailed(f),
              Err(failure: final f) => failed[id] = f,
            },
          ),
      ]);
    }
    return (fetched: fetched, failed: failed);
  }

  Future<(Message, MessageBody?)?> _fetch(String id, {required bool full}) async {
    final Map<String, dynamic> j;
    try {
      j = await _gmail.get(
        'messages/$id',
        query: {'format': full ? 'full' : 'metadata', if (!full) 'metadataHeaders': _headers},
      );
    } on OAuthFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
    final message = parseGmailMessage(j);
    if (!full) return (message, null);
    try {
      return (message, await _body(id, j['payload'] as Map<String, dynamic>? ?? const {}));
    } on OAuthFailed catch (e) {
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
