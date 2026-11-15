// The Graph transport on recorded responses: tokens, Prefer, links, errors, throttling, concurrency. No network.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/microsoft/graph_http.dart';
import 'package:postino/core/data/oauth/oauth_guard.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_recorded.dart';

({GraphHttp graph, List<http.Request> requests, List<Duration> sleeps}) _graph(
  http.Response Function(http.Request r) answer, {
  String access = 'EwB.initial',
}) {
  final requests = <http.Request>[];
  final sleeps = <Duration>[];
  final graph = GraphHttp(
    graphAccount,
    graphKeychain(access: access),
    MockClient((r) async {
      requests.add(r);
      return r.url.host == tokenHost ? graphFixture('token_refresh') : answer(r);
    }),
    FakeClock(graphNow),
    client: graphTestClient,
    sleep: (d) async => sleeps.add(d),
  );
  return (graph: graph, requests: requests, sleeps: sleeps);
}

Future<Result<Map<String, dynamic>>> _get(GraphHttp graph, [String path = 'mailFolders/inbox']) =>
    oauthGuard(() async => Ok(await graph.get(path)));

void main() {
  test('every request asks for immutable ids, with the token', () async {
    final t = _graph((_) => graphFixture('folder_inbox'));
    expect(okValue(await _get(t.graph))['id'], folderId('inbox'));
    final r = t.requests.single;
    expect(r.url.toString(), 'https://graph.microsoft.com/v1.0/me/mailFolders/inbox');
    expect(r.headers['prefer'], contains('IdType="ImmutableId"'));
    expect(r.headers['authorization'], 'Bearer EwB.initial');
  });

  test('a 401 refreshes the token once and retries with the new one', () async {
    final t = _graph(
      (r) => r.headers['authorization'] == 'Bearer EwB.stale'
          ? graphFixture('unauthorized')
          : graphFixture('folder_inbox'),
      access: 'EwB.stale',
    );
    expect(await _get(t.graph), isA<Ok<Object?>>());
    expect(
      [for (final r in t.requests) r.headers['authorization'] ?? r.url.path],
      ['Bearer EwB.stale', '/common/oauth2/v2.0/token', 'Bearer EwB.refreshed'],
    );
  });

  test('a 401 after the refresh is an AuthFailure', () async {
    final t = _graph((_) => graphFixture('unauthorized'));
    expect(await _get(t.graph), isErr<AuthFailure>());
    expect(t.requests.where((r) => r.url.host == tokenHost), hasLength(1));
  });

  test('ErrorItemNotFound (404) and an expired delta (410) are NotFoundFailure', () async {
    expect(await _get(_graph((_) => graphFixture('not_found')).graph), isErr<NotFoundFailure>());
    expect(await _get(_graph((_) => graphFixture('delta_expired')).graph), isErr<NotFoundFailure>());
  });

  test('a 429 waits its Retry-After, tries once more, then is a RateLimitFailure', () async {
    final t = _graph((_) => graphFixture('rate_limited'));
    final r = await _get(t.graph);
    expect(r, isErr<RateLimitFailure>());
    expect(((r as Err).failure as RateLimitFailure).retryAfter, graphNow.add(const Duration(seconds: 2)));
    expect(t.sleeps, [const Duration(seconds: 2)]);
    expect(t.requests, hasLength(2));
  });

  test('a 429 followed by a success is a success', () async {
    var calls = 0;
    final t = _graph((_) => calls++ == 0 ? graphFixture('rate_limited') : graphFixture('folder_inbox'));
    expect(await _get(t.graph), isA<Ok<Object?>>());
  });

  test('a 503 without Retry-After waits 5 s; a Retry-After over a minute waits a minute', () async {
    final busy = _graph((_) => graphJson({}, 503));
    expect(await _get(busy.graph), isErr<RateLimitFailure>());
    expect(busy.sleeps, [const Duration(seconds: 5)]);
    final long = _graph((_) => graphJson({}, 429, {'retry-after': '300'}));
    expect(await _get(long.graph), isErr<RateLimitFailure>());
    expect(long.sleeps, [const Duration(seconds: 60)]);
  });

  test('a 401 on the retry after a 429 refreshes the token once more', () async {
    var calls = 0;
    final t = _graph(
      (r) => switch (calls++) {
        0 => graphFixture('rate_limited'),
        1 => graphFixture('unauthorized'),
        _ => graphFixture('folder_inbox'),
      },
    );
    expect(await _get(t.graph), isA<Ok<Object?>>());
    expect(t.requests.where((r) => r.url.host == tokenHost), hasLength(1));
  });

  test('a sync state Graph no longer knows is NotFoundFailure, whatever the status', () async {
    final t = _graph(
      (_) => graphJson({
        'error': {'code': 'syncStateInvalid', 'message': 'Invalid sync state.'},
      }, 400),
    );
    expect(await _get(t.graph), isErr<NotFoundFailure>());
  });

  test('an empty answer (a 204) is an empty object', () async {
    final t = _graph((_) => http.Response('', 204));
    expect(okValue(await oauthGuard(() async => Ok(await t.graph.send('DELETE', 'mailFolders/x')))), isEmpty);
  });

  test('a request that stalls is OfflineFailure and its connection is aborted', () async {
    final aborted = Completer<void>();
    final graph = GraphHttp(
      graphAccount,
      graphKeychain(),
      MockClient.streaming((r, _) async {
        unawaited((r as http.Abortable).abortTrigger!.then((_) => aborted.complete()));
        return Completer<http.StreamedResponse>().future;
      }),
      FakeClock(graphNow),
      client: graphTestClient,
      timeout: const Duration(milliseconds: 10),
    );
    expect(await _get(graph), isErr<OfflineFailure>());
    await aborted.future;
  });

  test('no network is an OfflineFailure', () async {
    final t = _graph((_) => throw http.ClientException('Failed host lookup'));
    expect(await _get(t.graph), isErr<OfflineFailure>());
  });

  test('a link to another host is never followed: the token stays with Graph', () async {
    final t = _graph((_) => graphFixture('folder_inbox'));
    final r = await oauthGuard(() async => Ok(await t.graph.follow('https://evil.example.com/v1.0/me/messages')));
    expect(r, isErr<NotFoundFailure>());
    expect(t.requests, isEmpty);
  });

  test('a collection follows @odata.nextLink', () async {
    final t = _graph(
      (r) => r.url.queryParameters.containsKey(r'$skiptoken')
          ? graphFixture('messages_page2')
          : graphFixture('messages_page1'),
    );
    final items = await t.graph.list('mailFolders/${folderId('inbox')}/messages/delta');
    expect(items.map((m) => m['id']), [messageIdOf('f1'), messageIdOf('f2'), messageIdOf('f3')]);
  });

  test('at most 4 requests at a time, the others wait their turn', () async {
    final held = <Completer<void>>[];
    var running = 0;
    var most = 0;
    final graph = GraphHttp(
      graphAccount,
      graphKeychain(),
      MockClient((r) async {
        most = (++running) > most ? running : most;
        final done = Completer<void>();
        held.add(done);
        await done.future;
        running--;
        return graphFixture('folder_inbox');
      }),
      FakeClock(graphNow),
      client: graphTestClient,
    );
    final all = Future.wait([for (var i = 0; i < 6; i++) graph.get('mailFolders/inbox')]);
    await pumpEventQueue();
    expect(held, hasLength(GraphHttp.maxConcurrent));
    while (held.any((c) => !c.isCompleted)) {
      for (final c in [...held]) {
        if (!c.isCompleted) c.complete();
      }
      await pumpEventQueue();
    }
    expect(await all, hasLength(6));
    expect(most, GraphHttp.maxConcurrent);
  });
}
