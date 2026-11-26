// A message that does not download must not lose the whole sync (#252): what arrived is saved, the cursor moves on,
// and the missing message is retried by a later sync.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_cursor.dart';
import 'package:postino/core/data/gmail/gmail_provider.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart';

/// Gmail with [ids] added since history 100 (now at 200), every message answering but those [broken] says.
class _Mailbox(final List<String> ids) {
  final clock = FakeClock(gmailNow);
  final fetched = <String>[];

  /// Per id: 'stall' never answers, a number is that HTTP status; absent, the message comes.
  final broken = <String, String>{};
  var history = 'ok';

  /// How long each message download takes on [clock].
  var tick = Duration.zero;

  /// History records touching these ids again (a label changed elsewhere).
  final touched = <String>[];

  /// The messages stored here, their bodies too.
  final stored = <String, Message>{};

  late final provider = GmailProvider(
    gmailAccount,
    gmailKeychain(),
    MockClient.streaming((r, _) async {
      final path = r.url.path.substring(gmailApi.length);
      if (path.startsWith('messages/')) {
        final id = path.substring('messages/'.length);
        fetched.add(id);
        clock.advance(tick);
        switch (broken[id]) {
          case 'offline':
            throw http.ClientException('Failed host lookup');
          case 'stall':
            return Completer<http.StreamedResponse>().future;
          case final status?:
            return _stream(http.Response('{}', int.parse(status)));
        }
        return _stream(
          gmailJson({
            'id': id,
            'threadId': 't$id',
            'labelIds': ['INBOX'],
            'snippet': '',
            'internalDate': '1000',
            'payload': {'headers': <Object?>[]},
          }),
        );
      }
      return _stream(switch (path) {
        'history' when history == 'gone' => gmailFixture('not_found'),
        'history' => gmailJson({
          'historyId': '200',
          'history': [
            for (final id in [...ids, ...touched])
              {
                'id': '150',
                'messagesAdded': [
                  {
                    'message': {'id': id, 'threadId': 't$id'},
                  },
                ],
              },
          ],
        }),
        'profile' => gmailJson({'historyId': '300'}),
        'messages' => gmailJson({
          'messages': [
            for (final id in ids) {'id': id, 'threadId': 't$id'},
          ],
        }),
        _ => gmailJson({'labels': <Object?>[]}),
      });
    }),
    clock,
    client: gmailTestClient,
    sleep: (_) async {},
    stall: const Duration(milliseconds: 20),
    storedMessage: (id, {withBody = false}) async => stored[id],
  );

  static http.StreamedResponse _stream(http.Response r) =>
      http.StreamedResponse(http.ByteStream.fromBytes(r.bodyBytes), r.statusCode, headers: r.headers);
}

List<String> _ids(SyncBatch b) => [for (final m in b.messages) m.id]..sort();

void main() {
  test('a message that stalls: the others are synced and the cursor moves on', () async {
    final g = _Mailbox(['a', 'b', 'c'])..broken['b'] = 'stall';
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(_ids(batch), ['a', 'c']);
    expect(batch.removedMessageIds, isEmpty, reason: 'not downloaded is not gone');
    expect(batch.cursor, isNot('100'));
  });
  test('the message left behind is retried once its wait is over, then leaves the cursor', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = 'stall';
    final first = okValue(await g.provider.incrementalSync('100'));
    g
      ..ids.clear()
      ..fetched.clear();

    final early = okValue(await g.provider.incrementalSync(first.cursor));
    expect(g.fetched, isEmpty, reason: 'not at every poll: it waits');
    expect(early.cursor, first.cursor);

    g.clock.advance(const Duration(minutes: 1));
    final again = okValue(await g.provider.incrementalSync(early.cursor));
    expect(g.fetched, ['b']);
    expect(_ids(again), isEmpty, reason: 'still stalling');
    g.fetched.clear();
    g.clock.advance(const Duration(minutes: 1));
    final waiting = okValue(await g.provider.incrementalSync(again.cursor));
    expect(g.fetched, isEmpty, reason: 'the second wait is twice the first');

    g.broken.clear();
    g.clock.advance(const Duration(minutes: 1));
    final done = okValue(await g.provider.incrementalSync(waiting.cursor));
    expect(_ids(done), ['b']);
    expect(done.deferred, isNull);
    expect(done.cursor, '200', reason: 'nothing left to retry: the bare historyId');
  });

  test('a 5xx on one message defers it too, saying why', () async {
    final g = _Mailbox(['a', '18f3a2b4c5d6e7f9'])..broken['18f3a2b4c5d6e7f9'] = '503';
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(_ids(batch), ['a']);
    expect(batch.deferred, isA<UnexpectedFailure>());
    expect('${batch.deferred}', 'UnexpectedFailure(Gmail GET messages/*: HTTP 503)', reason: 'never a message id');
  });

  test('a message left behind and gone meanwhile is removed and leaves the cursor', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = 'stall';
    final first = okValue(await g.provider.incrementalSync('100'));
    g
      ..ids.clear()
      ..broken['b'] = '404'
      ..clock.advance(const Duration(minutes: 1));
    final batch = okValue(await g.provider.incrementalSync(first.cursor));
    expect(batch.removedMessageIds, ['b']);
    expect(batch.cursor, '200');
  });

  test('a rate limit on one message defers it: the batch is saved and says it was limited (#394)', () async {
    final g = _Mailbox([for (var i = 0; i < 10; i++) 'm$i'])..broken['m9'] = '429';
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(batch.messages, hasLength(9));
    expect(batch.deferredMessageIds, ['m9']);
    expect(batch.rateLimited, isA<RateLimitFailure>());
    final cursor = GmailCursor.decode(batch.cursor);
    expect(cursor.historyId, '200');
    expect(cursor.retries.keys, ['m9']);
  });

  test('a rate limit stops the chunks left: they are deferred, not requested (#394)', () async {
    final g = _Mailbox([for (var i = 0; i < 10; i++) 'm$i'])..broken['m3'] = '429';
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(g.fetched.where((id) => id.compareTo('m5') >= 0), isEmpty);
    expect(_ids(batch), ['m0', 'm1', 'm2', 'm4']);
    expect(batch.deferredMessageIds..sort(), ['m3', 'm5', 'm6', 'm7', 'm8', 'm9']);
  });

  test('initial sync: a rate limit defers the message, and a new initial sync skips those stored (#394)', () async {
    final g = _Mailbox([for (var i = 0; i < 10; i++) 'm$i'])..broken['m7'] = '429';
    final first = okValue(
      await g.provider.initialSync(
        onPage: (m, _) async {
          for (final x in m) {
            g.stored[x.id] = x;
          }
        },
      ),
    );
    expect(first.messages, hasLength(9));
    expect(first.deferredMessageIds, ['m7']);
    expect(first.rateLimited, isA<RateLimitFailure>());
    g
      ..broken.clear()
      ..fetched.clear();
    final again = okValue(await g.provider.initialSync(resume: true));
    expect(g.fetched, ['m7'], reason: 'the stored ones are not downloaded again');
    expect(again.messages, hasLength(10), reason: 'the stored ones stay in the snapshot');
    expect(again.rateLimited, isNull);
  });

  test('an initial sync not resumed (an expired cursor) downloads the stored ones again (#394)', () async {
    final g = _Mailbox(['a', 'b']);
    g.stored['a'] = okValue(await g.provider.initialSync()).messages.first;
    g.fetched.clear();
    okValue(await g.provider.initialSync());
    expect(g.fetched..sort(), ['a', 'b'], reason: 'its labels may have changed while the history was lost');
  });

  test('an expired historyId is still NotFound, retries or not', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = 'stall';
    final first = okValue(await g.provider.incrementalSync('100'));
    g.history = 'gone';
    expect(await g.provider.incrementalSync(first.cursor), isErr<NotFoundFailure>());
  });

  test('initial sync: a message that stalls does not lose the others, and the next sync retries it', () async {
    final g = _Mailbox(['a', 'b', 'c'])..broken['b'] = 'stall';
    final stored = <String>[];
    final batch = okValue(
      await g.provider.initialSync(onPage: (m, _) async => stored.addAll([for (final x in m) x.id])),
    );
    expect(_ids(batch), ['a', 'c']);
    expect(stored..sort(), ['a', 'c']);
    expect(batch.deferred, isA<OfflineFailure>());
    expect('${batch.deferred}', 'OfflineFailure(GET messages/*: no answer)', reason: 'which request, never its id');
    expect(batch.deferredMessageIds, ['b'], reason: 'the stored copy stays out of the snapshot removal');
    g
      ..ids.clear()
      ..broken.clear()
      ..fetched.clear()
      ..clock.advance(const Duration(minutes: 1));
    final next = okValue(await g.provider.incrementalSync(batch.cursor));
    expect(g.fetched, ['b']);
    expect(_ids(next), ['b']);
  });

  test('no network mid-batch is not a stall: the sync stops, nothing is deferred', () async {
    final g = _Mailbox(['a', 'b', 'c'])..broken['b'] = 'offline';
    expect(await g.provider.incrementalSync('100'), isErr<OfflineFailure>());
  });

  test('a message waiting for its retry is retried at once when the history touches it again (#322)', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = 'stall';
    final first = okValue(await g.provider.incrementalSync('100'));
    g
      ..ids.clear()
      ..touched.add('b')
      ..fetched.clear()
      ..broken.clear();
    final next = okValue(await g.provider.incrementalSync(first.cursor));
    expect(g.fetched, ['b'], reason: 'its backoff does not hold');
    expect(_ids(next), ['b']);
    expect(next.cursor, '200');
  });

  test('a message failing again says why only the first time: the log is not filled every hour', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = 'stall';
    final first = okValue(await g.provider.incrementalSync('100'));
    expect(first.deferred, isNotNull);
    g
      ..ids.clear()
      ..clock.advance(const Duration(minutes: 1));
    final again = okValue(await g.provider.incrementalSync(first.cursor));
    expect(g.fetched.where((id) => id == 'b'), hasLength(2));
    expect(again.deferred, isNull);
  });

  test('the wait starts when the batch ends, not before its downloads', () async {
    final g = _Mailbox([for (var i = 0; i < 6; i++) 'm$i'])
      ..broken['m0'] = 'stall'
      // Each download takes 30 s: the batch ends minutes after it started.
      ..tick = const Duration(seconds: 30);
    final first = okValue(await g.provider.incrementalSync('100'));
    g
      ..tick = Duration.zero
      ..ids.clear()
      ..fetched.clear()
      ..clock.advance(const Duration(seconds: 59));
    okValue(await g.provider.incrementalSync(first.cursor));
    expect(g.fetched, isEmpty, reason: 'a minute after the batch ended, not after it started');
  });

  test('a search with a message that does not come fails whole', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = '503';
    expect(await g.provider.search(const SearchQuery(terms: ['x'])), isErr<UnexpectedFailure>());
  });
}
