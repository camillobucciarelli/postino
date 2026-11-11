// The Azioni on the responses of test/fixtures/graph: an id that is gone and found again by its Message-ID, and a
// throttled write. No network.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_recorded.dart';

const _wellKnown = {'inbox', 'sentitems', 'drafts', 'deleteditems', 'junkemail', 'outbox'};

/// The mailbox of the fixtures where `msg-f1` is gone and the Message-ID `<f1@example.com>` is [found] as `msg-f9`.
http.Response Function(http.Request, String) _route({
  String? found,
  bool etag = true,
  int copies = 1,
  http.Response Function()? write,
}) =>
    (r, path) => switch (path.split('/')) {
      ['mailFolders', final name] when _wellKnown.contains(name) => graphFixture('folder_$name'),
      ['messages', final id] when r.method == 'GET' && id == messageIdOf('f1') => graphFixture('not_found'),
      ['messages'] => graphJson({
        'value': [
          if (found != null)
            for (var i = 0; i < copies; i++) _placeJson(found, etag: etag),
        ],
      }),
      ['messages', _] when r.method == 'PATCH' => write?.call() ?? graphJson({'id': messageIdOf('f9')}),
      _ => fail('unexpected ${r.method} $path'),
    };

/// A message as Graph answers an Azione's read, in the folder `folder-<folder>`.
Map<String, Object?> _placeJson(String folder, {bool etag = true}) => {
  if (etag) '@odata.etag': 'W/"change-key-1"',
  'id': messageIdOf('f9'),
  'parentFolderId': folderId(folder),
  'isRead': false,
  'flag': {'flagStatus': 'notFlagged'},
};

void main() {
  Future<String?> rfc(String id) async => id == messageIdOf('f1') ? '<f1@example.com>' : null;

  test('the id is gone: the message is found by its Message-ID and the Azione applies there, with its etag', () async {
    final g = RecordedGraph(_route(found: 'inbox'), messageIdOf: rfc);
    expect(
      okValue(await g.provider.applyAction(messageIdOf('f1'), const MarkRead(), expected: false)),
      isA<ActionApplied>(),
    );
    final search = g.requests.singleWhere((r) => r.url.path.endsWith('/me/messages'));
    expect(search.url.queryParameters[r'$filter'], "internetMessageId eq '<f1@example.com>'");
    final patch = g.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, endsWith('/messages/${messageIdOf('f9')}'));
    expect(patch.headers['if-match'], 'W/"change-key-1"');
    expect(patch.body, '{"isRead":true}');
  });

  test('found under another id with another value: the Conflitto is kept under the new id', () async {
    final g = RecordedGraph(_route(found: 'deleteditems'), messageIdOf: rfc);
    expect(
      okValue(await g.provider.applyAction(messageIdOf('f1'), const Archive(), expected: Placement.inbox)),
      isA<ActionConflict>()
          .having((c) => c.providerValue, 'providerValue', Placement.trash)
          .having((c) => c.movedTo, 'movedTo', messageIdOf('f9')),
    );
    expect(g.requests.where((r) => r.method != 'GET' && r.url.host == 'graph.microsoft.com'), isEmpty);
  });

  test('gone, and not found by its Message-ID either: messaggioSparito', () async {
    final g = RecordedGraph(_route(), messageIdOf: rfc);
    expect(
      okValue(await g.provider.applyAction(messageIdOf('f1'), const Delete(), expected: Placement.inbox)),
      isA<ActionMessageGone>(),
    );
  });

  test('gone and the app remembers no Message-ID for it: messaggioSparito, nothing searched', () async {
    final g = RecordedGraph(_route(found: 'inbox'));
    expect(
      okValue(await g.provider.applyAction(messageIdOf('f1'), const MarkRead(), expected: false)),
      isA<ActionMessageGone>(),
    );
    expect(g.requests.where((r) => r.url.path.endsWith('/me/messages')), isEmpty);
  });

  test('a throttled write waits its Retry-After, tries once more, then is a RateLimitFailure', () async {
    final g = RecordedGraph(
      _route(found: 'inbox', write: () => graphFixture('rate_limited')),
      messageIdOf: rfc,
    );
    expect(
      await g.provider.applyAction(messageIdOf('f1'), const MarkRead(), expected: false),
      isErr<RateLimitFailure>(),
    );
    expect(g.sleeps, [const Duration(seconds: 2)]);
    expect(g.requests.where((r) => r.method == 'PATCH'), hasLength(2));
  });

  test('a write that finds the message gone (404) locates it again: here it is, and the Azione applies', () async {
    var writes = 0;
    final g = RecordedGraph(
      _route(
        found: 'inbox',
        write: () => ++writes == 1 ? graphFixture('not_found') : graphJson({'id': messageIdOf('f9')}),
      ),
      messageIdOf: rfc,
    );
    expect(
      okValue(await g.provider.applyAction(messageIdOf('f1'), const MarkRead(), expected: false)),
      isA<ActionApplied>(),
    );
    expect(g.requests.where((r) => r.method == 'PATCH'), hasLength(2));
  });

  test('a read without an etag is never written blind: an error, no PATCH', () async {
    final g = RecordedGraph(_route(found: 'inbox', etag: false), messageIdOf: rfc);
    expect(
      await g.provider.applyAction(messageIdOf('f1'), const MarkRead(), expected: false),
      isErr<UnexpectedFailure>(),
    );
    expect(g.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  test('two messages share the Message-ID: the Azione stays queued (an error), nothing is written', () async {
    final g = RecordedGraph(_route(found: 'inbox', copies: 2), messageIdOf: rfc);
    expect(
      await g.provider.applyAction(messageIdOf('f1'), const Delete(), expected: Placement.inbox),
      isErr<UnexpectedFailure>(),
    );
    expect(g.requests.where((r) => r.method != 'GET' && r.url.host == 'graph.microsoft.com'), isEmpty);
  });
}
