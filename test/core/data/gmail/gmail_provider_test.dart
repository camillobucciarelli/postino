// Gmail adapter on recorded HTTP responses (test/fixtures/gmail): no network.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' show MimeMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_provider.dart';
import 'package:postino/core/data/gmail/gmail_tokens.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/mailbox.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show withRead;
import '../../../support/fake_platform.dart';
import '../../domain/mail_provider_contract.dart';

const _account = 'gmail:ada@gmail.com';
final _now = DateTime.utc(2026, 10, 28, 12);
const _testClient = GoogleClient('test-client.apps.googleusercontent.com');
const _api = '/gmail/v1/users/me/';

http.Response _fixture(String name) {
  final j = jsonDecode(
    File('test/fixtures/gmail/$name.json').readAsStringSync(),
  );
  final status = j['status'] as int;
  // A 204 (batchModify) has no body.
  return j['body'] == null
      ? http.Response('', status)
      : _json(j['body'], status);
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

FakeSecureStore _keychain({
  String access = 'ya29.initial',
  Duration validFor = const Duration(hours: 1),
}) {
  final keychain = FakeSecureStore();
  // FakeSecureStore writes synchronously.
  GmailTokens(
    access: access,
    refresh: '1//refresh',
    expiresAt: _now.add(validFor),
  ).write(keychain, _account);
  return keychain;
}

/// Google as seen over HTTP: the token endpoint and a simulated Gmail API mailbox,
/// shaped like the recorded responses.
class GmailHarness implements ContractHarness {
  GmailHarness({
    String access = 'ya29.initial',
    Duration validFor = const Duration(hours: 1),
  }) : keychain = _keychain(access: access, validFor: validFor);

  final FakeSecureStore keychain;
  final requests = <http.Request>[];

  /// Gmail Bozze by draft id (`r-<n>`): the Message-ID and the id of the message it currently holds.
  final _drafts = <String, ({String messageId, String id})>{};
  final _draftBodies = <String, String>{};
  var _draftSeq = 0;

  /// What Gmail does with a `raw` MIME: the Bozza is a DRAFT message whose id changes on every update.
  Map<String, Object> _putDraft(String? draftId, OutgoingMessage d) {
    final id = draftId ?? 'r-${++_draftSeq}';
    if (_drafts[id] case final old?) removeRemotely(old.id);
    final messageId = 'm-${++_draftSeq}';
    _drafts[id] = (messageId: d.messageId, id: messageId);
    _draftBodies[messageId] = d.body;
    deliver(
      Message(
        id: messageId,
        messageId: d.messageId,
        conversationId: 'th-$id',
        labelIds: const ['DRAFT'],
        isRead: true,
        isStarred: false,
        from: d.from,
        to: d.to,
        cc: d.cc,
        subject: d.subject,
        snippet: '',
        date: _now,
      ),
    );
    return {
      'id': id,
      'message': {
        'id': messageId,
        'threadId': 'th-$id',
        'labelIds': ['DRAFT'],
      },
    };
  }

  http.Response _deleteDraft(String id) {
    final d = _drafts.remove(id);
    if (d == null) return _fixture('not_found');
    removeRemotely(d.id);
    return http.Response('', 204);
  }

  http.Response _draftRaw(String? draftId, Map<String, dynamic> body) {
    if (draftId != null && !_drafts.containsKey(draftId)) {
      return _fixture('not_found');
    }
    final mime = MimeMessage.parseFromText(
      utf8.decode(
        base64Url.decode(base64Url.normalize(body['message']['raw'] as String)),
      ),
    );
    List<String> addresses(String h) => [
      for (final m in parseMailboxes(mime.getHeaderValue(h) ?? ''))
        formatMailbox(m),
    ];
    return _json(
      _putDraft(
        draftId,
        OutgoingMessage(
          messageId: mime.getHeaderValue('message-id')!,
          from: parseMailbox(mime.getHeaderValue('from')!).address,
          to: addresses('to'),
          cc: addresses('cc'),
          subject: mime.decodeSubject() ?? '',
          body: mime.decodeTextHtmlPart() ?? '',
        ),
      ),
    );
  }

  @override
  void deliverDraft(OutgoingMessage d) => _putDraft(
    [
      for (final e in _drafts.entries)
        if (e.value.messageId == d.messageId) e.key,
    ].firstOrNull,
    d,
  );
  final _accepted = {'ya29.initial', 'ya29.refreshed'};
  bool _authBroken = false, _offline = false;

  final _mailbox = <String, Message>{};

  /// By message id: (name, bytes) of each attachment.
  final _attached = <String, List<(String, List<int>)>>{};

  /// Gmail hands out a new attachmentId on every fetch of the message: the old ones keep working.
  var _fetches = 0;
  final _history = <(int, String, String)>[]; // (historyId, kind, message id)
  var _historyId = 4000;
  var _oldest = 0;

  /// Gmail may return fewer results than maxResults: tiny pages exercise pagination.
  static const _page = 2;

  @override
  late final MailProvider provider = GmailProvider(
    _account,
    keychain,
    MockClient(_handle),
    FakeClock(_now),
    client: _testClient,
    sleep: (_) async {},
  );

  Future<GmailTokens?> get tokens => GmailTokens.read(keychain, _account);

  Future<http.Response> _handle(http.Request r) async {
    requests.add(r);
    if (_offline) throw http.ClientException('Failed host lookup');
    if (r.url.host == 'oauth2.googleapis.com') {
      return _fixture(_authBroken ? 'token_invalid_grant' : 'token_refresh');
    }
    final bearer = r.headers['authorization']?.substring('Bearer '.length);
    if (!_accepted.contains(bearer)) return _fixture('unauthorized');
    final q = r.url.queryParameters;
    // ponytail: the 90-day `after:` window is not simulated; the recorded-response test checks the query.
    return switch (r.url.path.substring(_api.length).split('/')) {
      ['profile'] => _json({
        'emailAddress': 'ada@gmail.com',
        'historyId': '$_historyId',
      }),
      ['labels'] => _fixture('labels'),
      ['messages'] => _paged('messages', [
        for (final m in _mailbox.values)
          if (q['labelIds'] == null || _labels(m).contains(q['labelIds']))
            {'id': m.id, 'threadId': m.conversationId},
      ], q),
      ['drafts'] when r.method == 'GET' => _json({
        'drafts': [
          for (final MapEntry(:key, :value) in _drafts.entries)
            if ('rfc822msgid:${value.messageId.replaceAll(RegExp('[<>]'), '')}' ==
                q['q'])
              {
                'id': key,
                'message': {'id': value.id},
              },
        ],
        'resultSizeEstimate': _drafts.length,
      }),
      ['drafts'] => _draftRaw(null, jsonDecode(r.body)),
      ['drafts', final id] when r.method == 'PUT' => _draftRaw(
        id,
        jsonDecode(r.body),
      ),
      ['drafts', final id] when r.method == 'DELETE' => _deleteDraft(id),
      ['messages', 'batchModify'] => _modify(
        jsonDecode(r.body) as Map<String, dynamic>,
      ),
      ['threads', final id] => switch ([
        for (final m in _mailbox.values)
          if (m.conversationId == id) _resource(m, full: false),
      ]) {
        [] => _fixture('not_found'),
        final messages => _json({'id': id, 'messages': messages}),
      },
      ['messages', final id, 'attachments', final aid] => switch (_attached[id]
          ?.elementAtOrNull(int.parse(aid.substring(aid.indexOf('_') + 1)))) {
        null => _fixture('not_found'),
        (_, final bytes) => _json({
          'size': bytes.length,
          'data': base64Url.encode(bytes),
        }),
      },
      ['messages', final id] => switch (_mailbox[id]) {
        null => _fixture('not_found'),
        final m => _json(_resource(m, full: q['format'] == 'full')),
      },
      ['history'] when int.parse(q['startHistoryId']!) < _oldest => _fixture(
        'not_found',
      ),
      ['history'] => _paged(
        'history',
        [
          for (final (hid, kind, id) in _history)
            if (hid > int.parse(q['startHistoryId']!))
              {
                'id': '$hid',
                kind: [
                  {
                    'message': {'id': id},
                  },
                ],
              },
        ],
        q,
        {'historyId': '$_historyId'},
      ),
      _ => _fixture('not_found'),
    };
  }

  http.Response _paged(
    String key,
    List<Object> all,
    Map<String, String> q, [
    Map<String, Object> extra = const {},
  ]) {
    final from = int.parse(q['pageToken'] ?? '0');
    final page = all.skip(from).take(_page).toList();
    return _json({
      ...extra,
      if (page.isNotEmpty) key: page,
      if (from + _page < all.length) 'nextPageToken': '${from + _page}',
      if (key == 'messages') 'resultSizeEstimate': all.length,
    });
  }

  /// batchModify of the UNREAD label only, as the adapter uses it.
  http.Response _modify(Map<String, dynamic> body) {
    final read = (body['removeLabelIds'] as List?)?.contains('UNREAD') ?? false;
    for (final id in body['ids'] as List) {
      if (_mailbox[id] case final m?) {
        _mailbox[id as String] = withRead(m, read);
        _history.add((++_historyId, 'labelsRemoved', id));
      }
    }
    return http.Response('', 204);
  }

  static List<String> _labels(Message m) => [
    ...m.labelIds,
    if (!m.isRead) 'UNREAD',
    if (m.isStarred) 'STARRED',
  ];

  String _html(Message m) => _draftBodies[m.id] ?? '<p>Corpo di ${m.id}</p>';

  Map<String, Object> _resource(Message m, {required bool full}) => {
    'id': m.id,
    'threadId': m.conversationId,
    'labelIds': _labels(m),
    'snippet': m.snippet,
    'internalDate': '${m.date.millisecondsSinceEpoch}',
    'payload': {
      'mimeType': 'text/html',
      'headers': [
        {
          'name': 'From',
          'value': m.fromName == null ? m.from : '"${m.fromName}" <${m.from}>',
        },
        {'name': 'To', 'value': m.to.join(', ')},
        if (m.cc.isNotEmpty) {'name': 'Cc', 'value': m.cc.join(', ')},
        {'name': 'Subject', 'value': m.subject},
        {'name': 'Message-Id', 'value': m.messageId},
      ],
      if (full && _attached[m.id] == null)
        'body': {'data': base64Url.encode(utf8.encode(_html(m)))},
      if (_attached[m.id] case final attached? when full)
        'parts': [
          {
            'partId': '0',
            'mimeType': 'text/html',
            'filename': '',
            'body': {
              'data': base64Url.encode(utf8.encode('<p>Corpo di ${m.id}</p>')),
            },
          },
          for (final (i, (name, bytes)) in attached.indexed)
            {
              'partId': '${i + 1}',
              'mimeType': 'application/octet-stream',
              'filename': name,
              'headers': [
                {
                  'name': 'Content-Disposition',
                  'value': 'attachment; filename="$name"',
                },
              ],
              'body': {
                'attachmentId': 'ANG${++_fetches}_$i',
                'size': bytes.length,
              },
            },
        ],
    },
  };

  @override
  void attach(String messageId, String name, List<int> bytes) =>
      (_attached[messageId] ??= []).add((name, bytes));

  @override
  void deliver(Message m) {
    final kind = _mailbox.containsKey(m.id) ? 'labelsAdded' : 'messagesAdded';
    _mailbox[m.id] = m;
    _history.add((++_historyId, kind, m.id));
  }

  @override
  void removeRemotely(String id) {
    _drafts.removeWhere((_, d) => d.id == id);
    _mailbox.remove(id);
    _history.add((++_historyId, 'messagesDeleted', id));
  }

  @override
  void expireCursors() => _oldest = _historyId + 1;

  @override
  void goOffline() => _offline = true;

  @override
  void breakAuth() {
    _authBroken = true;
    _accepted.clear();
  }
}

Matcher _err<F>() => isA<Err>().having((e) => e.failure, 'failure', isA<F>());

Map<String, (String, BodyKind)> _contents(Map<String, MessageBody> bodies) => {
  for (final MapEntry(:key, :value) in bodies.entries)
    key: (value.content, value.kind),
};

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

const _f1 = '18f3a2b4c5d6e7f1',
    _f2 = '18f3a2b4c5d6e7f2',
    _f3 = '18f3a2b4c5d6e7f3',
    _f4 = '18f3a2b4c5d6e7f4';

/// Gmail answering each request with the recorded response [route] names.
class _Recorded {
  _Recorded(String Function(http.Request r, String path) route) {
    provider = GmailProvider(
      _account,
      _keychain(),
      MockClient((r) async {
        requests.add(r);
        return _fixture(route(r, r.url.path.substring(_api.length)));
      }),
      FakeClock(_now),
      client: _testClient,
      sleep: (d) async => sleeps.add(d),
    );
  }

  late final GmailProvider provider;
  final requests = <http.Request>[];
  final sleeps = <Duration>[];

  Iterable<Uri> get urls => requests.map((r) => r.url);
}

void main() {
  mailProviderAuthContract('GmailProvider', GmailHarness.new);
  mailProviderSyncContract('GmailProvider', GmailHarness.new);
  mailProviderAttachmentContract('GmailProvider', GmailHarness.new);
  mailProviderDraftContract('GmailProvider', GmailHarness.new);

  test('refreshAuth swaps the access token in the keychain, keeping the refresh token', () async {
    final h = GmailHarness();
    expect(await h.provider.refreshAuth(), isA<Ok>());

    final r = h.requests.single;
    expect(r.url, Uri.parse('https://oauth2.googleapis.com/token'));
    expect(r.bodyFields, {
      'grant_type': 'refresh_token',
      'refresh_token': '1//refresh',
      'client_id': 'test-client.apps.googleusercontent.com',
    });
    final t = (await h.tokens)!;
    expect(t.access, 'ya29.refreshed');
    expect(t.refresh, '1//refresh');
    expect(t.expiresAt, _now.add(const Duration(seconds: 3599)));
  });

  test('an expired access token is refreshed before calling Gmail', () async {
    final h = GmailHarness(validFor: Duration.zero);
    expect(await h.provider.initialSync(), isA<Ok>());
    expect(
      [for (final r in h.requests.take(2)) r.url.path],
      ['/token', '/gmail/v1/users/me/profile'],
    );
    expect(h.requests[1].headers['authorization'], 'Bearer ya29.refreshed');
  });

  test('a 401 from Gmail refreshes the token once and retries', () async {
    final h = GmailHarness(access: 'ya29.stale');
    expect(await h.provider.initialSync(), isA<Ok>());
    expect(
      [
        for (final r in h.requests.take(3))
          r.headers['authorization'] ?? r.url.path,
      ],
      ['Bearer ya29.stale', '/token', 'Bearer ya29.refreshed'],
    );
  });

  test('a 403 for insufficient scope is an AuthFailure, so the Account is Da ricollegare', () async {
    final p = GmailProvider(
      _account,
      _keychain(),
      MockClient((_) async => _fixture('insufficient_scope')),
      FakeClock(_now),
      client: _testClient,
    );
    expect(await p.initialSync(), _err<AuthFailure>());
  });

  test('no tokens in the keychain is an AuthFailure', () async {
    final h = GmailHarness()..keychain.values.clear();
    expect(await h.provider.refreshAuth(), _err<AuthFailure>());
    expect(await h.provider.initialSync(), _err<AuthFailure>());
    expect(h.requests, isEmpty);
  });

  group('recorded responses', () {
    String initialRoute(http.Request r, String path) => switch (path) {
      'profile' => 'profile',
      'labels' => 'labels',
      'messages' when r.url.queryParameters['labelIds'] == inboxLabelId =>
        'messages_inbox',
      'messages' when r.url.queryParameters['pageToken'] == null =>
        'messages_page1',
      'messages' => 'messages_page2',
      'messages/$_f1' => 'message_f1',
      'messages/$_f2' => 'message_f2',
      'messages/$_f3' => 'message_f3',
      _ => fail('unexpected $path'),
    };

    test('initial sync: 90 days of headers over every page, with Etichette, Conversazioni and the inbox bodies', () async {
      final g = _Recorded(initialRoute);
      final batch = _ok(await g.provider.initialSync());

      expect(batch.cursor, '4242');
      expect(
        batch.labels.map((l) => (l.id, l.name)),
        [('Label_12', 'Viaggi')],
        reason: 'user labels only: INBOX and the other system ones are not Etichette',
      );
      final after = _now.subtract(syncWindow).millisecondsSinceEpoch ~/ 1000;
      final lists = g.urls.where((u) => u.path.endsWith('/messages'));
      expect(lists.map((u) => u.queryParameters['q']).toSet(), {
        'after:$after',
      });
      expect(lists.map((u) => u.queryParameters['pageToken']), [
        null,
        '08765432109876543210',
        null,
      ], reason: 'second page, then the inbox list');

      final byId = {for (final m in batch.messages) m.id: m};
      expect(byId.keys, unorderedEquals([_f1, _f2, _f3]));
      final f1 = byId[_f1]!;
      expect((f1.from, f1.fromName), ('bruno@example.com', 'Bruno Verdi'));
      expect(f1.to, ['ada@gmail.com', 'carla@example.org']);
      expect(f1.cc, [
        'Rossi, Carla <carla.rossi@example.org>',
        'Nicolò Neri <nicolo@example.com>',
      ], reason: 'a quoted name keeps its comma; an RFC 2047 one is decoded');
      expect(f1.labelIds, contains('IMPORTANT'));
      expect(f1.subject, 'Cena di venerdì');
      expect(f1.messageId, '<CAF1x7Yk2b@mail.example.com>');
      expect(f1.conversationId, _f1);
      expect(f1.snippet, endsWith('Porto io il vino & il dolce.'));
      expect(f1.date, DateTime.utc(2026, 10, 26, 8, 15, 2));
      expect((f1.isRead, f1.isStarred), (false, false));
      final f2 = byId[_f2]!;
      expect(f2.conversationId, _f1, reason: 'same Conversazione');
      expect((f2.isRead, f2.isStarred), (true, true));
      expect(f2.labelIds, contains('Label_12'));
      expect(f2.snippet, contains("c'è"));
      expect((f2.from, f2.fromName), ('ada@gmail.com', 'Ada Rossi – Studio'));
      expect(byId[_f3]!.labelIds, ['SENT']);

      expect(_contents(batch.bodies), {
        _f1: (
          '<div dir="ltr">Ciao Ada,<br>ci vediamo alle 20 da Mario?</div>\r\n',
          BodyKind.html,
        ),
        _f2: (
          "Perfetto, a venerdì!\r\nIl 31 c'è anche Carla.\r\n",
          BodyKind.testo,
        ),
      });
      String format(String id) => g.urls
          .singleWhere((u) => u.path.endsWith(id))
          .queryParameters['format']!;
      expect(
        [format(_f1), format(_f2), format(_f3)],
        ['full', 'full', 'metadata'],
      );
    });

    test(
      'initial sync of an empty mailbox: no messages, still a cursor',
      () async {
        final g = _Recorded(
          (r, path) => switch (path) {
            'messages' => 'messages_empty',
            _ => initialRoute(r, path),
          },
        );
        final batch = _ok(await g.provider.initialSync());
        expect(batch.messages, isEmpty);
        expect(batch.bodies, isEmpty);
        expect(batch.cursor, '4242');
      },
    );

    test(
      'incremental sync from historyId: new, read and starred, deleted',
      () async {
        final g = _Recorded(
          (r, path) => switch (path) {
            'history' => 'history',
            'messages/$_f1' => 'message_f1_read',
            'messages/$_f4' => 'message_f4',
            _ => fail('unexpected $path'),
          },
        );
        final batch = _ok(await g.provider.incrementalSync('4242'));

        expect(g.urls.first.queryParameters['startHistoryId'], '4242');
        expect(batch.cursor, '4301');
        final byId = {for (final m in batch.messages) m.id: m};
        expect(byId.keys, unorderedEquals([_f1, _f4]));
        expect((byId[_f1]!.isRead, byId[_f1]!.isStarred), (true, true));
        expect(byId[_f4]!.subject, 'Il tuo biglietto per Bologna');
        expect(batch.removedMessageIds, [_f3]);
        expect(batch.bodies.keys, unorderedEquals([_f1, _f4]));
      },
    );

    test('incremental sync with nothing new keeps the cursor moving', () async {
      final g = _Recorded((r, path) => 'history_empty');
      final batch = _ok(await g.provider.incrementalSync('4200'));
      expect(batch.messages, isEmpty);
      expect(batch.removedMessageIds, isEmpty);
      expect(batch.cursor, '4242');
    });

    test('a 404 on history (expired historyId) is NotFound', () async {
      final g = _Recorded((r, path) => 'not_found');
      expect(await g.provider.incrementalSync('1'), _err<NotFoundFailure>());
    });

    test(
      'a message gone before it could be fetched counts as removed',
      () async {
        final g = _Recorded(
          (r, path) => switch (path) {
            'history' => 'history',
            _ => 'not_found',
          },
        );
        final batch = _ok(await g.provider.incrementalSync('4242'));
        expect(batch.messages, isEmpty);
        expect(batch.removedMessageIds, unorderedEquals([_f1, _f3, _f4]));
      },
    );

    group('a text part referenced by attachmentId', () {
      const f5 = '18f3a2b4c5d6e7f5';
      const text =
          'Ciao Bruno,\r\nti scrivo il resoconto lungo della riunione di giovedì: il budget è approvato.\r\n';
      String route(http.Request r, String path) => switch (path) {
        'profile' => 'profile',
        'labels' => 'labels',
        'messages' => 'messages_f5',
        'messages/$f5' => 'message_f5_attachment_body',
        'messages/$f5/attachments/ANGjdJ9kX2mQ7vL4pR1sT8wYzB3nC6' =>
          'attachment_f5_body',
        _ => fail('unexpected $path'),
      };

      test('is fetched when syncing the inbox', () async {
        final batch = _ok(await _Recorded(route).provider.initialSync());
        expect(_contents(batch.bodies), {f5: (text, BodyKind.testo)});
      });

      test('is fetched by fetchBody', () async {
        final g = _Recorded(route);
        final body = _ok(await g.provider.fetchBody(f5));
        expect((body.content, body.kind), (text, BodyKind.testo));
      });
    });

    group('an HTML attachment next to a plain text body', () {
      const f6 = '18f3a2b4c5d6e7f6';
      const text =
          'Ciao Bruno,\r\nil verbale della riunione è in allegato.\r\n';
      String route(http.Request r, String path) => switch (path) {
        'profile' => 'profile',
        'labels' => 'labels',
        'messages' => 'messages_f6',
        'messages/$f6' => 'message_f6_html_attachment',
        _ => fail('unexpected $path'),
      };

      test('is not the body when syncing the inbox', () async {
        final batch = _ok(await _Recorded(route).provider.initialSync());
        expect(_contents(batch.bodies), {f6: (text, BodyKind.testo)});
      });

      test('is not the body from fetchBody', () async {
        expect(
          _ok(await _Recorded(route).provider.fetchBody(f6)).content,
          text,
        );
      });
    });

    group('a PDF attachment beside an inline logo', () {
      const f7 = '18f3a2b4c5d6e7f7';
      const pdf = '%PDF-1.4\n% preventivo sintetico per i test\n%%EOF\n';
      String route(http.Request r, String path) => switch (path) {
        'messages/$f7' => 'message_f7_attachments',
        'messages/$f7/attachments/ANGjdJ9kX2mQ7vL4pR1sT8wYzB3nP7' =>
          'attachment_f7_pdf',
        _ => fail('unexpected $path'),
      };

      test('fetchBody lists the PDF and the nameless part, not the logo the HTML shows by cid:', () async {
        final body = _ok(await _Recorded(route).provider.fetchBody(f7));
        expect(body.content, startsWith('Ciao Bruno,'));
        expect(
          body.attachments!.map((a) => (a.id, a.name, a.size, a.mimeType)),
          [
            ('1', 'Preventivo 2027.pdf', 49, 'application/pdf'),
            // `Content-Disposition: attachment` without a filename: listed, nameless, with its type.
            ('2', '', 3, 'text/plain'),
            // An empty file: listed all the same.
            ('3', 'vuoto.txt', 0, 'text/plain'),
          ],
        );
      });

      test('fetchAttachment finds the part, then downloads its data', () async {
        final g = _Recorded(route);
        final progress = <double>[];
        final bytes = _ok(
          await g.provider.fetchAttachment(f7, '1', onProgress: progress.add),
        );
        expect(utf8.decode(bytes), pdf);
        expect(g.urls.map((u) => u.path), [
          '${_api}messages/$f7',
          '${_api}messages/$f7/attachments/ANGjdJ9kX2mQ7vL4pR1sT8wYzB3nP7',
        ]);
        expect(g.urls.first.queryParameters['format'], 'full');
        expect(progress.last, 1);
      });

      test('Annulla aborts the download in flight', () async {
        final started = Completer<void>();
        final cancel = Completer<void>();
        final provider = GmailProvider(
          _account,
          _keychain(),
          _Hanging(
            (path) => path.contains('/attachments/')
                ? null
                : _fixture('message_f7_attachments'),
            started,
          ),
          FakeClock(_now),
          client: _testClient,
        );
        final r = provider.fetchAttachment(f7, '1', cancel: cancel.future);
        await started.future;
        cancel.complete();
        expect(await r, _err<CancelledFailure>());
      });

      test('a nameless attachment with inline data downloads without a second request', () async {
        final g = _Recorded(route);
        expect(
          utf8.decode(_ok(await g.provider.fetchAttachment(f7, '2'))),
          'abc',
        );
        expect(g.urls, hasLength(1));
      });

      test(
        'an empty file downloads as no bytes, without a second request',
        () async {
          final g = _Recorded(route);
          expect(_ok(await g.provider.fetchAttachment(f7, '3')), isEmpty);
          expect(g.urls, hasLength(1));
        },
      );

      test('the inline logo is not an attachment to download', () async {
        expect(
          await _Recorded(route).provider.fetchAttachment(f7, '0.1'),
          _err<NotFoundFailure>(),
        );
      });
    });

    test('fetchBody: the HTML part, saying it is HTML', () async {
      final g = _Recorded((r, path) => 'message_f1');
      final body = _ok(await g.provider.fetchBody(_f1));
      expect(body.kind, BodyKind.html);
      expect(body.content, startsWith('<div dir="ltr">Ciao Ada,'));
      expect(g.urls.single.path, '${_api}messages/$_f1');
      expect(g.urls.single.queryParameters['format'], 'full');
    });

    test('threads.get: the whole Conversazione, with the Sent message older than 90 days', () async {
      final g = _Recorded((r, path) => 'thread_f1');
      final messages = _ok(await g.provider.fetchConversation(_f1));

      final url = g.urls.single;
      expect(url.path, '${_api}threads/$_f1');
      expect(url.queryParameters['format'], 'metadata');
      expect(url.queryParametersAll['metadataHeaders'], [
        'From',
        'To',
        'Cc',
        'Subject',
        'Message-ID',
      ]);
      expect(messages.map((m) => m.id), ['18f3a2b4c5d6e7f0', _f1, _f2]);
      expect(messages.map((m) => m.conversationId).toSet(), {_f1});
      final sent = messages.first;
      expect(sent.labelIds, ['SENT']);
      expect((sent.from, sent.fromName), ('ada@gmail.com', 'Ada Rossi'));
      expect(sent.subject, 'Cena di venerdì');
      expect(sent.date.isBefore(_now.subtract(syncWindow)), isTrue);
      expect(messages[1].isRead, isFalse);
    });

    test('a 404 on threads.get is NotFound', () async {
      final g = _Recorded((r, path) => 'not_found');
      expect(await g.provider.fetchConversation(_f1), _err<NotFoundFailure>());
    });

    test('marking read is one batchModify removing UNREAD', () async {
      final g = _Recorded((r, path) => 'batch_modify');
      _ok(await g.provider.setRead([_f1, _f2], read: true));

      final r = g.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '${_api}messages/batchModify');
      expect(r.headers['content-type'], startsWith('application/json'));
      expect(r.headers['authorization'], 'Bearer ya29.initial');
      expect(jsonDecode(r.body), {
        'ids': [_f1, _f2],
        'removeLabelIds': ['UNREAD'],
      });
    });

    test('marking unread adds UNREAD back', () async {
      final g = _Recorded((r, path) => 'batch_modify');
      _ok(await g.provider.setRead([_f1], read: false));
      expect(jsonDecode(g.requests.single.body), {
        'ids': [_f1],
        'addLabelIds': ['UNREAD'],
      });
    });

    group('Bozze', () {
      const draftId = 'r-4410200000000000001';
      final draft = OutgoingMessage(
        messageId: '<c1d2e3f4@postino.example.com>',
        from: 'Ada Lovelace <ada@gmail.com>',
        to: const ['Bruno <bruno@example.com>'],
        cc: const ['carla@example.com'],
        bcc: const ['dario@example.com'],
        subject: 'Caffè è più buono',
        body: '<p>Ciao <b>Bruno</b>, è tutto più semplice.</p>',
      );

      String route(http.Request r, String path) => switch ((r.method, path)) {
        ('POST', 'drafts') => 'draft_create',
        ('GET', 'drafts') =>
          r.url.queryParameters['q']!.contains('nope')
              ? 'drafts_empty'
              : 'drafts_list',
        ('PUT', 'drafts/$draftId') => 'draft_update',
        ('DELETE', 'drafts/$draftId') => 'draft_delete',
        _ => 'not_found',
      };

      String raw(http.Request r) => utf8.decode(
        base64Url.decode(
          base64Url.normalize(
            (jsonDecode(r.body) as Map)['message']['raw'] as String,
          ),
        ),
      );

      test('a new Bozza is one POST of the raw MIME: Message-ID as given, headers, text and HTML parts', () async {
        final g = _Recorded(route);
        _ok(await g.provider.saveDraft(draft, isNew: true));

        final r = g.requests.single;
        expect([r.method, r.url.path], ['POST', '${_api}drafts']);
        expect((jsonDecode(r.body) as Map).keys, ['message']);
        final mime = raw(r);
        final unfolded = mime.replaceAll(RegExp(r'\r?\n[ \t]'), ' ');
        expect(mime, contains('Message-Id: <c1d2e3f4@postino.example.com>'));
        expect(unfolded, contains('ada@gmail.com'));
        expect(unfolded, contains('bruno@example.com'));
        expect(unfolded, contains('carla@example.com'));
        expect(unfolded, contains('dario@example.com'));
        expect(mime, contains('Date: '));
        final parsed = MimeMessage.parseFromText(mime);
        expect(parsed.decodeSubject(), 'Caffè è più buono');
        expect(parsed.getHeaderValue('bcc'), contains('dario@example.com'));
        expect(
          parsed.decodeTextPlainPart(),
          contains('Ciao Bruno, è tutto più semplice.'),
        );
        expect(parsed.decodeTextPlainPart(), isNot(contains('<b>')));
        expect(parsed.decodeTextHtmlPart()?.trim(), draft.body);
      });

      test('updating after the create reuses the remembered id: one PUT, no search', () async {
        final g = _Recorded(route);
        _ok(await g.provider.saveDraft(draft, isNew: true));
        _ok(await g.provider.saveDraft(draft, isNew: false));

        expect(
          [for (final r in g.requests) '${r.method} ${r.url.path}'],
          ['POST ${_api}drafts', 'PUT ${_api}drafts/$draftId'],
        );
        final put = jsonDecode(g.requests.last.body) as Map;
        expect(put['id'], draftId);
        expect((put['message'] as Map)['raw'], isA<String>());
      });

      test('updating with nothing remembered searches by Message-ID without angle brackets, then PUTs', () async {
        final g = _Recorded(route);
        _ok(await g.provider.saveDraft(draft, isNew: false));

        expect(
          [for (final r in g.requests) '${r.method} ${r.url.path}'],
          ['GET ${_api}drafts', 'PUT ${_api}drafts/$draftId'],
        );
        expect(
          g.requests.first.url.queryParameters['q'],
          'rfc822msgid:c1d2e3f4@postino.example.com',
        );
      });

      test(
        'no draft found by the search is NotFound, nothing is written',
        () async {
          final g = _Recorded(route);
          final d = OutgoingMessage(
            messageId: '<nope@example.com>',
            from: 'ada@gmail.com',
            to: const ['bruno@example.com'],
            subject: 's',
            body: '<p>x</p>',
          );
          expect(
            await g.provider.saveDraft(d, isNew: false),
            _err<NotFoundFailure>(),
          );
          expect(g.requests.map((r) => r.method), ['GET']);
        },
      );

      test('a 404 on the PUT is NotFound', () async {
        final g = _Recorded(
          (r, path) => r.method == 'PUT' ? 'not_found' : route(r, path),
        );
        expect(
          await g.provider.saveDraft(draft, isNew: false),
          _err<NotFoundFailure>(),
        );
      });

      test('deleting searches the draft, then DELETEs it', () async {
        final g = _Recorded(route);
        _ok(await g.provider.deleteDraft(draft.messageId));

        expect(
          [for (final r in g.requests) '${r.method} ${r.url.path}'],
          ['GET ${_api}drafts', 'DELETE ${_api}drafts/$draftId'],
        );
      });

      test('deleting an unknown draft is NotFound', () async {
        final g = _Recorded(route);
        expect(
          await g.provider.deleteDraft('<nope@example.com>'),
          _err<NotFoundFailure>(),
        );
      });

      test('offline is an OfflineFailure', () async {
        final h = GmailHarness()..goOffline();
        expect(
          await h.provider.saveDraft(draft, isNew: true),
          _err<OfflineFailure>(),
        );
        expect(
          await h.provider.deleteDraft(draft.messageId),
          _err<OfflineFailure>(),
        );
      });
    });

    test('a 404 on a body is NotFound', () async {
      final g = _Recorded((r, path) => 'not_found');
      expect(await g.provider.fetchBody(_f1), _err<NotFoundFailure>());
    });

    test(
      'a 429 is retried with backoff and jitter, then is a RateLimitFailure',
      () async {
        final g = _Recorded((r, path) => 'rate_limited');
        expect(await g.provider.initialSync(), _err<RateLimitFailure>());
        expect(g.requests, hasLength(6));
        for (var n = 0; n < 5; n++) {
          final ms = g.sleeps[n].inMilliseconds;
          expect(ms, inInclusiveRange((1 << n) * 1000, (1 << n) * 1250));
        }
      },
    );

    test('the temporary block end is parsed from the body, else the header', () async {
      final g = _Recorded((r, path) => 'rate_limited');
      expect(
        await g.provider.initialSync(),
        isA<Err<SyncBatch>>().having(
          (e) => e.failure,
          'failure',
          isA<RateLimitFailure>().having(
            (f) => f.retryAfter,
            'retryAfter',
            DateTime.utc(2026, 10, 28, 12, 0, 5),
          ),
        ),
      );
      final h = GmailProvider(
        _account,
        _keychain(),
        MockClient(
          (r) async => http.Response('{}', 429, headers: {'retry-after': '90'}),
        ),
        FakeClock(_now),
        client: _testClient,
        sleep: (d) async {},
      );
      expect(
        (await h.initialSync() as Err).failure.toString(),
        'RateLimitFailure(retryAfter: ${_now.add(const Duration(seconds: 90))})',
      );
    });

    test('Retry-After is honoured, capped at 32 s', () async {
      for (final (header, expected) in [('7', 7), ('120', 32)]) {
        var limited = true;
        final sleeps = <Duration>[];
        final p = GmailProvider(
          _account,
          _keychain(),
          MockClient((r) async {
            if (limited) {
              limited = false;
              return http.Response('{}', 429, headers: {'retry-after': header});
            }
            return _fixture('history_empty');
          }),
          FakeClock(_now),
          client: _testClient,
          sleep: (d) async => sleeps.add(d),
        );
        expect(_ok(await p.incrementalSync('4200')).cursor, '4242');
        expect(sleeps, [Duration(seconds: expected)]);
      }
    });

    test(
      'a 429 on one message mid-page is retried and the sync completes',
      () async {
        final ids = [for (var i = 0; i < 12; i++) 'm$i'];
        var failedOnce = false;
        final sleeps = <Duration>[];
        final stored = <int>[];
        final p = GmailProvider(
          _account,
          _keychain(),
          MockClient((r) async {
            final path = r.url.path.substring(_api.length);
            if (path == 'messages/m7' && !failedOnce) {
              failedOnce = true;
              return _fixture('rate_limited');
            }
            if (path == 'messages') {
              return _json({
                'messages': [
                  for (final id in ids) {'id': id, 'threadId': 't$id'},
                ],
              });
            }
            if (path.startsWith('messages/')) {
              return _json({
                'id': path.substring(9),
                'threadId': 't',
                'labelIds': <String>[],
                'snippet': '',
                'internalDate': '1000',
                'payload': {'headers': []},
              });
            }
            return path == 'profile'
                ? _json({'historyId': '1'})
                : _json({'labels': []});
          }),
          FakeClock(_now),
          client: _testClient,
          sleep: (d) async => sleeps.add(d),
        );
        final batch = _ok(
          await p.initialSync(onPage: (m, _) async => stored.add(m.length)),
        );
        expect(batch.messages, hasLength(12));
        expect(stored, [12]);
        expect(
          sleeps.where((d) => d >= const Duration(seconds: 1)),
          hasLength(1),
        );
        expect(
          sleeps.where((d) => d == const Duration(milliseconds: 125)),
          hasLength(2),
        );
      },
    );

    test(
      'persistent 429s on page two still fail, with page one stored',
      () async {
        final stored = <int>[];
        final p = GmailProvider(
          _account,
          _keychain(),
          MockClient((r) async {
            final path = r.url.path.substring(_api.length);
            return switch (path) {
              'messages/m120' => _fixture('rate_limited'),
              'messages' => _json({
                'messages': [
                  for (var i = 0; i < 150; i++) {'id': 'm$i', 'threadId': 't'},
                ],
              }),
              'profile' => _json({'historyId': '1'}),
              'labels' => _json({'labels': []}),
              _ => _json({
                'id': path.substring(9),
                'threadId': 't',
                'labelIds': <String>[],
                'internalDate': '1000',
                'payload': {'headers': []},
              }),
            };
          }),
          FakeClock(_now),
          client: _testClient,
          sleep: (_) async {},
        );
        expect(
          await p.initialSync(onPage: (m, _) async => stored.add(m.length)),
          _err<RateLimitFailure>(),
        );
        expect(stored, [100]);
      },
    );

    test('a 429 that clears on retry is not a failure', () async {
      var limited = true;
      final g = _Recorded((r, path) {
        if (path == 'history' && limited) {
          limited = false;
          return 'rate_limited';
        }
        return 'history_empty';
      });
      expect(_ok(await g.provider.incrementalSync('4200')).cursor, '4242');
      expect(g.sleeps.single.inMilliseconds, inInclusiveRange(1000, 1250));
    });
  });

  test('the change signal is IMAP IDLE on Gmail, as the Account, with a valid token', () async {
    late (String, String) seen;
    late Future<String> Function() token;
    final p = GmailProvider(
      _account,
      _keychain(),
      MockClient((_) async => fail('no HTTP')),
      FakeClock(_now),
      client: _testClient,
      idle:
          ({required String host, required String user, required accessToken}) {
            seen = (host, user);
            token = accessToken;
            return Stream.value(ChangeSignal.changed);
          },
    );
    expect(await p.changes.toList(), [ChangeSignal.changed]);
    expect(seen, ('imap.gmail.com', 'ada@gmail.com'));
    expect(await token(), 'ya29.initial');
  });
}

/// Answers with [answer], or (null) hangs until the request is aborted, as a stalled download would.
class _Hanging extends http.BaseClient {
  _Hanging(this.answer, this.started);
  final http.Response? Function(String path) answer;
  final Completer<void> started;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (answer(request.url.path) case final r?) {
      return http.StreamedResponse(
        Stream.value(r.bodyBytes),
        r.statusCode,
        contentLength: r.bodyBytes.length,
      );
    }
    started.complete();
    await (request as http.Abortable).abortTrigger;
    throw http.RequestAbortedException(request.url);
  }
}
