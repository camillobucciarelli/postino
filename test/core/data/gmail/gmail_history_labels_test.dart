// Label and read changes in the Gmail history are applied to the stored message, without downloading it again (#322).
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart';

/// A Gmail whose history is [records] (each a kind, a message id and the label ids it touches), with [stored] as the
/// local copy.
class _Mailbox(
  final List<(String, String, List<String>)> records,
  final Map<String, Message> stored, [
  final Set<String> bodies = const {},
]) {
  final fetched = <String>[];

  late final provider = GmailProvider(
    gmailAccount,
    gmailKeychain(),
    MockClient.streaming((r, _) async {
      final path = r.url.path.substring(gmailApi.length);
      final http.Response res;
      if (path.startsWith('messages/')) {
        final id = path.substring('messages/'.length);
        fetched.add(id);
        res = gmailJson({
          'id': id,
          'threadId': 't$id',
          'labelIds': ['INBOX'],
          'snippet': '',
          'internalDate': '1000',
          'payload': {'headers': <Object?>[]},
        });
      } else if (path == 'history') {
        res = gmailJson({
          'historyId': '200',
          'history': [
            for (final (i, (kind, id, labels)) in records.indexed)
              {
                'id': '${150 + i}',
                kind: [
                  {
                    'message': {'id': id, 'threadId': 't$id'},
                    if (kind.startsWith('labels')) 'labelIds': labels,
                  },
                ],
              },
          ],
        });
      } else {
        res = gmailJson({'labels': <Object?>[]});
      }
      return http.StreamedResponse(http.ByteStream.fromBytes(res.bodyBytes), res.statusCode, headers: res.headers);
    }),
    FakeClock(gmailNow),
    client: gmailTestClient,
    sleep: (_) async {},
    storedMessage: (id, {withBody = false}) async => withBody && !bodies.contains(id) ? null : stored[id],
  );
}

void main() {
  final stored = msg('a', labelIds: ['INBOX', 'UNREAD'], subject: 'Ciao');

  test('read and star changes apply to the stored message, in history order, without a download', () async {
    final g = _Mailbox(
      [
        ('labelsRemoved', 'a', ['UNREAD']),
        ('labelsAdded', 'a', ['STARRED', 'Label_1']),
        ('labelsRemoved', 'a', ['STARRED']),
      ],
      {'a': stored},
    );
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(g.fetched, isEmpty);
    expect(batch.messages, [
      msg('a', labelIds: ['INBOX', 'Label_1'], subject: 'Ciao', isRead: true),
    ]);
    expect(batch.cursor, '200');
  });

  test('a label change on a message not stored is downloaded', () async {
    final g = _Mailbox([
      ('labelsAdded', 'b', ['STARRED']),
    ], {});
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(g.fetched, ['b']);
    expect(batch.messages.single.id, 'b');
  });

  test('a message added and then labelled is downloaded once, for its final state', () async {
    final g = _Mailbox(
      [
        ('messagesAdded', 'a', []),
        ('labelsRemoved', 'a', ['UNREAD']),
      ],
      {'a': stored},
    );
    okValue(await g.provider.incrementalSync('100'));
    expect(g.fetched, ['a']);
  });

  test('a message added and then deleted is not downloaded', () async {
    final g = _Mailbox([('messagesAdded', 'a', []), ('messagesDeleted', 'a', [])], {});
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(g.fetched, isEmpty);
    expect(batch.removedMessageIds, ['a']);
  });

  test('a message labelled and then deleted is only removed', () async {
    final g = _Mailbox(
      [
        ('labelsAdded', 'a', ['STARRED']),
        ('messagesDeleted', 'a', []),
      ],
      {'a': stored},
    );
    final batch = okValue(await g.provider.incrementalSync('100'));
    expect(batch.messages, isEmpty);
    expect(batch.removedMessageIds, ['a']);
  });

  group('a message entering the inbox keeps its body in cache (ADR 0003)', () {
    final archived = msg('a', labelIds: ['Label_1']);
    final history = [
      ('labelsAdded', 'a', ['INBOX']),
    ];

    test('no body stored: downloaded', () async {
      final g = _Mailbox(history, {'a': archived});
      okValue(await g.provider.incrementalSync('100'));
      expect(g.fetched, ['a']);
    });

    test('body stored: applied from the history', () async {
      final g = _Mailbox(history, {'a': archived}, {'a'});
      final batch = okValue(await g.provider.incrementalSync('100'));
      expect(g.fetched, isEmpty);
      expect(batch.messages.single.labelIds, ['Label_1', 'INBOX']);
    });

    test('a label that is not the inbox needs no body', () async {
      final g = _Mailbox(
        [
          ('labelsAdded', 'a', ['STARRED']),
        ],
        {'a': archived},
      );
      okValue(await g.provider.incrementalSync('100'));
      expect(g.fetched, isEmpty);
    });
  });
}
