// The Gmail transport on its own, over a MockClient: no Provider, no fixtures.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_http.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/data/gmail/google_failure.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

const _account = 'gmail:ada@gmail.com';
final _now = DateTime.utc(2026, 10, 28, 12);

http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

({GmailHttp gmail, List<http.Request> requests, List<Duration> sleeps}) _gmail(
  Future<http.Response> Function(http.Request) handler, {
  Future<http.StreamedResponse> Function(http.BaseRequest)? streaming,
  Duration stall = const Duration(seconds: 30),
}) {
  final keychain = FakeSecureStore();
  // FakeSecureStore writes synchronously.
  unawaited(
    OAuthTokens(
      access: 'ya29.initial',
      refresh: '1//refresh',
      expiresAt: _now.add(const Duration(hours: 1)),
    ).write(keychain, _account),
  );
  final requests = <http.Request>[];
  final sleeps = <Duration>[];
  final gmail = GmailHttp(
    _account,
    keychain,
    streaming != null
        ? MockClient.streaming((r, _) => streaming(r))
        : MockClient((r) {
            requests.add(r);
            return handler(r);
          }),
    FakeClock(_now),
    client: const GoogleClient('test-client.apps.googleusercontent.com'),
    sleep: (d) async => sleeps.add(d),
    stall: stall,
  );
  return (gmail: gmail, requests: requests, sleeps: sleeps);
}

void main() {
  test('a 429 is retried after its Retry-After, capped at 32 s', () async {
    var calls = 0;
    final t = _gmail((r) async {
      return ++calls == 1 ? http.Response('{}', 429, headers: {'retry-after': '120'}) : _json({'ok': true});
    });
    expect(await t.gmail.get('profile'), {'ok': true});
    expect(t.sleeps, [const Duration(seconds: 32)]);
    expect(t.requests, hasLength(2));
  });

  test('a 401 refreshes the token once, then the call succeeds', () async {
    var api = 0;
    final t = _gmail((r) async {
      if (r.url.host == 'oauth2.googleapis.com') {
        return _json({'access_token': 'ya29.fresh', 'expires_in': 3600});
      }
      return ++api == 1 ? _json({}, 401) : _json({'ok': true});
    });
    expect(await t.gmail.get('profile'), {'ok': true});
    expect(t.requests.map((r) => r.url.host), [
      'gmail.googleapis.com',
      'oauth2.googleapis.com',
      'gmail.googleapis.com',
    ]);
    expect(t.requests.last.headers['authorization'], 'Bearer ya29.fresh');
  });

  test('a 401 after the refresh is an AuthFailure, not a loop', () async {
    final t = _gmail((r) async {
      if (r.url.host == 'oauth2.googleapis.com') {
        return _json({'access_token': 'ya29.fresh', 'expires_in': 3600});
      }
      return _json({}, 401);
    });
    final r = await googleGuard(() async => Ok(await t.gmail.get('profile')));
    expect(r, isA<Err<Map<String, dynamic>>>());
    expect((r as Err).failure, isA<AuthFailure>());
    expect(t.requests, hasLength(3));
  });

  test('googleGuard maps a 404 to NotFoundFailure', () async {
    final t = _gmail((r) async => _json({}, 404));
    final r = await googleGuard(() async => Ok(await t.gmail.get('messages/x')));
    expect((r as Err).failure, isA<NotFoundFailure>());
  });

  test('without a content length the progress is out of expected', () async {
    final body = utf8.encode(jsonEncode({'data': 'abcd'}));
    final t = _gmail(
      (r) async => throw StateError('unused'),
      streaming: (r) async => http.StreamedResponse(Stream.value(body), 200), // no contentLength
    );
    final progress = <double>[];
    await t.gmail.get('messages/x', expected: 1000, onProgress: progress.add);
    expect(progress.last, closeTo(body.length / 1000, 1e-9));
  });

  test('a stalled body times out, aborts the request, is offline', () async {
    final never = StreamController<List<int>>();
    addTearDown(never.close);
    late http.BaseRequest sent;
    final t = _gmail(
      (r) async => throw StateError('unused'),
      streaming: (r) async {
        sent = r;
        return http.StreamedResponse(never.stream, 200);
      },
      stall: const Duration(milliseconds: 50),
    );
    final r = await googleGuard(() async => Ok(await t.gmail.get('profile')));
    expect((r as Err).failure, isA<OfflineFailure>());
    await (sent as http.AbortableRequest).abortTrigger!.timeout(const Duration(seconds: 1));
  });

  test('a permanent 429 is retried 5 times, then a RateLimitFailure', () async {
    final t = _gmail((r) async => http.Response('{}', 429));
    final r = await googleGuard(() async => Ok(await t.gmail.get('profile')));
    expect((r as Err).failure, isA<RateLimitFailure>());
    expect(t.sleeps, hasLength(5));
    expect(t.requests, hasLength(6));
  });

  test('a 403 rateLimitExceeded is retried like a 429', () async {
    var calls = 0;
    final t = _gmail((r) async {
      return ++calls == 1
          ? http.Response('{"error":{"errors":[{"reason":"rateLimitExceeded"}]}}', 403)
          : _json({'ok': true});
    });
    expect(await t.gmail.get('profile'), {'ok': true});
    expect(t.sleeps, hasLength(1));
  });
}
