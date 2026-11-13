// A message that does not download must not lose the whole sync (#252): what arrived is saved, the cursor moves on,
// and the missing message is retried by a later sync.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_provider.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart';

/// Gmail with [ids] added since history 100 (now at 200), every message answering but those [broken] says.
class _Mailbox(final List<String> ids) {
  final clock = FakeClock(gmailNow);
  final fetched = <String>[];

  /// Per id: 'stall' never answers, a number is that HTTP status; absent, the message comes.
  final broken = <String, String>{};
  var history = 'ok';

  late final provider = GmailProvider(
    gmailAccount,
    gmailKeychain(),
    MockClient.streaming((r, _) async {
      final path = r.url.path.substring(gmailApi.length);
      if (path.startsWith('messages/')) {
        final id = path.substring('messages/'.length);
        fetched.add(id);
        switch (broken[id]) {
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
            for (final id in ids)
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
    okValue(await g.provider.incrementalSync(again.cursor));
    expect(g.fetched, isEmpty, reason: 'the second wait is twice the first');

    g.broken.clear();
    g.clock.advance(const Duration(minutes: 1));
    final done = okValue(await g.provider.incrementalSync(again.cursor));
    expect(_ids(done), ['b']);
    expect(done.deferred, isNull);
    expect(done.cursor, '200', reason: 'nothing left to retry: the bare historyId');
  });

  test('a 5xx on one message defers it too, saying why', () async {
    final g = _Mailbox(['a', '18f3a2b4c5d6e7f9'])..broken['18f3a2b4c5d6e7f9'] = '503';
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(_ids(batch), ['a']);
    expect(batch.deferred, isA<UnexpectedFailure>());
    expect('${batch.deferred}', allOf(contains('messages/*'), contains('503'), isNot(contains('18f3a2b4c5d6e7f9'))));
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

  test('a rate limit on one message still stops the sync, which the engine pauses', () async {
    final g = _Mailbox(['a', 'b'])..broken['b'] = '429';
    expect(await g.provider.incrementalSync('100'), isErr<RateLimitFailure>());
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
    g
      ..ids.clear()
      ..broken.clear()
      ..fetched.clear()
      ..clock.advance(const Duration(minutes: 1));
    final next = okValue(await g.provider.incrementalSync(batch.cursor));
    expect(g.fetched, ['b']);
    expect(_ids(next), ['b']);
  });
}
