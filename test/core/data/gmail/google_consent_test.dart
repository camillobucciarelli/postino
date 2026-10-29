// Real consent on recorded HTTP responses; the browser step is faked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/data/gmail/google_consent.dart';
import 'package:postino/core/domain/google_consent.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

const _client = GoogleClient('123-abc.apps.googleusercontent.com');
final _now = DateTime.utc(2026, 10, 28, 12);

http.Response _fixture(String name) {
  final j = jsonDecode(
    File('test/fixtures/gmail/$name.json').readAsStringSync(),
  );
  return http.Response(jsonEncode(j['body']), j['status'] as int);
}

void main() {
  late List<http.Request> requests;
  late Uri opened;
  late String scheme;

  String token = 'token_exchange';

  GoogleWebConsent consent({
    GoogleClient client = _client,
    bool loopback = false,
    String Function(Uri url)? browser,
  }) => GoogleWebConsent(
    MockClient((r) async {
      requests.add(r);
      return _fixture(token);
    }),
    FakeClock(_now),
    client,
    ({required url, required callbackUrlScheme}) async {
      opened = Uri.parse(url);
      scheme = callbackUrlScheme;
      return browser?.call(opened) ??
          '${opened.queryParameters['redirect_uri']}?state=${opened.queryParameters['state']}&code=4/0Ab';
    },
    loopback,
  );

  setUp(() {
    requests = [];
    token = 'token_exchange';
  });

  test('consent with PKCE, then the code is exchanged for the tokens and the address', () async {
    final r = await consent().run(loginHint: 'ada@gmail.com');

    final grant = (r as Ok<GoogleGrant>).value;
    expect(grant.address, 'ada@gmail.com');
    expect(grant.accessToken, 'ya29.granted');
    expect(grant.refreshToken, '1//granted');
    expect(grant.expiresAt, _now.add(const Duration(seconds: 3599)));

    expect(opened.host, 'accounts.google.com');
    final q = opened.queryParameters;
    expect(q['scope']!.split(' '), contains('https://mail.google.com/'));
    expect(q['login_hint'], 'ada@gmail.com');
    expect(q['prompt'], 'consent');
    expect(q['access_type'], 'offline');
    expect(q['code_challenge_method'], 'S256');
    expect(scheme, 'com.googleusercontent.apps.123-abc');
    expect(
      q['redirect_uri'],
      'com.googleusercontent.apps.123-abc:/oauth2redirect',
    );

    final exchange = requests.single.bodyFields;
    expect(exchange['code'], '4/0Ab');
    expect(exchange['redirect_uri'], q['redirect_uri']);
    expect(exchange['client_id'], _client.id);
    expect(exchange['code_verifier'], isNotEmpty);
  });

  test('a token without the Gmail scope (granular consent) is a MissingPermissionFailure', () async {
    token = 'token_exchange_no_gmail';
    final r = await consent().run();
    expect(
      r,
      isA<Err>().having(
        (e) => e.failure,
        'failure',
        isA<MissingPermissionFailure>(),
      ),
    );
  });

  test(
    'a token without refresh_token is a Failure, not an exception',
    () async {
      token = 'token_exchange_no_refresh';
      final r = await consent().run();
      expect(
        r,
        isA<Err>().having(
          (e) => e.failure,
          'failure',
          isA<UnexpectedFailure>().having(
            (f) => f.error,
            'error',
            'no refresh_token in code exchange',
          ),
        ),
      );
    },
  );

  test('desktop uses a loopback redirect', () async {
    await consent(loopback: true).run();
    expect(scheme, startsWith('http://localhost:'));
    expect(opened.queryParameters['redirect_uri'], scheme);
  });

  test(
    'without a client ID it fails clearly, before opening anything',
    () async {
      var asked = false;
      final r = await consent(
        client: const GoogleClient(''),
        browser: (_) {
          asked = true;
          return '';
        },
      ).run();
      expect(
        r,
        isA<Err>().having(
          (e) => e.failure,
          'failure',
          isA<ConfigurationFailure>(),
        ),
      );
      expect(asked, isFalse);
    },
  );

  test('closing the browser is a CancelledFailure', () async {
    final r = await consent(
      browser: (_) => throw PlatformException(code: 'CANCELED'),
    ).run();
    expect(
      r,
      isA<Err>().having((e) => e.failure, 'failure', isA<CancelledFailure>()),
    );
  });

  test('a callback with another state is refused, no code exchanged', () async {
    final r = await consent(
      browser: (u) =>
          '${u.queryParameters['redirect_uri']}?state=forged&code=x',
    ).run();
    expect(r, isA<Err>());
    expect(requests, isEmpty);
  });
}
