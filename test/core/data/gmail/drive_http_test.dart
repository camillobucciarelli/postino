// The Drive transport on its own (#124), over a MockClient: tokens, retries, timeout and errors.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/drive_http.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/data/gmail/google_failure.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

const _account = 'gmail:ada@gmail.com';
final _now = DateTime.utc(2026, 11, 5, 12);
final _files = Uri.parse('https://www.googleapis.com/drive/v3/files');

/// A DriveHttp on [handler], with tokens valid for [validFor].
({DriveHttp drive, List<http.Request> requests}) _drive(
  Future<http.Response> Function(http.Request) handler, {
  Duration validFor = const Duration(hours: 1),
  Duration timeout = const Duration(seconds: 30),
}) {
  final keychain = FakeSecureStore();
  // FakeSecureStore writes synchronously.
  unawaited(OAuthTokens(access: 'ya29.a', refresh: '1//r', expiresAt: _now.add(validFor)).write(keychain, _account));
  final requests = <http.Request>[];
  final drive = DriveHttp(
    _account,
    keychain,
    MockClient((r) {
      requests.add(r);
      return handler(r);
    }),
    FakeClock(_now),
    client: const GoogleClient('test'),
    timeout: timeout,
  );
  return (drive: drive, requests: requests);
}

Future<Result<String>> _get(DriveHttp drive) => googleGuard(() async => Ok((await drive.send('GET', _files)).body));

Matcher _failure<F>() => isA<Err<String>>().having((e) => e.failure, 'failure', isA<F>());

void main() {
  test('a 401 refreshes the token once, then the call succeeds with the new one', () async {
    var api = 0;
    final t = _drive((r) async {
      if (r.url.host == 'oauth2.googleapis.com') {
        return http.Response(jsonEncode({'access_token': 'ya29.b', 'expires_in': 3600}), 200);
      }
      return ++api == 1 ? http.Response('{}', 401) : http.Response('ok', 200);
    });
    expect(await _get(t.drive), isA<Ok<String>>().having((r) => r.value, 'value', 'ok'));
    expect(
      [for (final r in t.requests) r.headers['authorization'] ?? r.url.host],
      ['Bearer ya29.a', 'oauth2.googleapis.com', 'Bearer ya29.b'],
    );
  });

  test('a 403 for the missing drive.appdata scope is its own failure, not an AuthFailure', () async {
    final body = jsonEncode({
      'error': {
        'code': 403,
        'errors': [
          {'reason': 'insufficientPermissions'},
        ],
        'details': [
          {'reason': 'ACCESS_TOKEN_SCOPE_INSUFFICIENT'},
        ],
      },
    });
    expect(await _get(_drive((_) async => http.Response(body, 403)).drive), _failure<DriveScopeFailure>());
  });

  test('any other 403 is unexpected: no consent would fix it', () async {
    const body = '{"error":{"errors":[{"reason":"forbidden"}]}}';
    expect(await _get(_drive((_) async => http.Response(body, 403)).drive), _failure<UnexpectedFailure>());
  });

  test('a quota hit is a RateLimitFailure, a 404 NotFound, no network an OfflineFailure', () async {
    final quota = _drive((_) async => http.Response('{"reason":"userRateLimitExceeded"}', 403));
    expect(await _get(quota.drive), _failure<RateLimitFailure>());
    expect(await _get(_drive((_) async => http.Response('', 429)).drive), _failure<RateLimitFailure>());
    expect(await _get(_drive((_) async => http.Response('', 404)).drive), _failure<NotFoundFailure>());
    expect(await _get(_drive((_) => throw http.ClientException('offline')).drive), _failure<OfflineFailure>());
  });

  test('a token refresh that never answers times out as offline instead of hanging', () async {
    final t = _drive(
      (r) => r.url.host == 'oauth2.googleapis.com' ? Completer<http.Response>().future : throw StateError('$r'),
      validFor: Duration.zero,
      timeout: const Duration(milliseconds: 50),
    );
    expect(await _get(t.drive), _failure<OfflineFailure>());
    expect(t.requests.single.url.host, 'oauth2.googleapis.com');
  });
}
