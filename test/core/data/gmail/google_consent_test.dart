// Real consent on recorded HTTP responses; the browser step is faked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/data/gmail/google_consent.dart';
import 'package:postino/core/domain/oauth_grant.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

const _client = GoogleClient('123-abc.apps.googleusercontent.com');
final _now = DateTime.utc(2026, 10, 28, 12);

http.Response _fixture(String name) {
  final j = jsonDecode(File('test/fixtures/gmail/$name.json').readAsStringSync()) as Map<String, dynamic>;
  return http.Response(jsonEncode(j['body']), j['status'] as int);
}

void main() {
  late List<http.Request> requests;
  late FakeErrorLog log;
  late Uri opened;
  late String scheme;

  String token = 'token_exchange';

  GoogleWebConsent consent({GoogleClient client = _client, bool loopback = false, String Function(Uri url)? browser}) =>
      GoogleWebConsent(
        MockClient((r) async {
          requests.add(r);
          return _fixture(token);
        }),
        FakeClock(_now),
        log,
        client: client,
        authenticate: ({required url, required callbackUrlScheme}) async {
          opened = Uri.parse(url);
          scheme = callbackUrlScheme;
          return browser?.call(opened) ??
              '${opened.queryParameters['redirect_uri']}?state=${opened.queryParameters['state']}&code=4/0Ab';
        },
        loopback: loopback,
      );

  setUp(() {
    requests = [];
    log = FakeErrorLog();
    token = 'token_exchange';
  });

  test('consent with PKCE, then the code is exchanged for the tokens and the address', () async {
    final r = await consent().run(loginHint: 'ada@gmail.com');

    final grant = (r as Ok<OAuthGrant>).value;
    expect(grant.address, 'ada@gmail.com');
    expect(grant.accessToken, 'ya29.granted');
    expect(grant.refreshToken, '1//granted');
    expect(grant.expiresAt, _now.add(const Duration(seconds: 3599)));
    // The scopes go with the grant into the synced voce (#321).
    expect(grant.scopes, ['https://mail.google.com/', 'openid', 'https://www.googleapis.com/auth/userinfo.email']);

    expect(opened.host, 'accounts.google.com');
    final q = opened.queryParameters;
    expect(q['scope']!.split(' '), contains('https://mail.google.com/'));
    expect(q['login_hint'], 'ada@gmail.com');
    expect(q['prompt'], 'consent');
    expect(q['access_type'], 'offline');
    expect(q['code_challenge_method'], 'S256');
    expect(scheme, 'com.googleusercontent.apps.123-abc');
    expect(q['redirect_uri'], 'com.googleusercontent.apps.123-abc:/oauth2redirect');

    final exchange = requests.single.bodyFields;
    expect(exchange['code'], '4/0Ab');
    expect(exchange['redirect_uri'], q['redirect_uri']);
    expect(exchange['client_id'], _client.id);
    expect(exchange['code_verifier'], isNotEmpty);
  });

  test('a refresh token that expires is said in the log, with its lifetime only (#353)', () async {
    await consent().run();
    expect(log.entries, isEmpty, reason: 'a token that does not expire says nothing');

    token = 'token_exchange_expiring';
    await consent().run();
    expect(await log.read(), 'refresh_token_expires_in 604799');
  });

  test('a token without the Gmail scope (granular consent) is a MissingPermissionFailure', () async {
    token = 'token_exchange_no_gmail';
    final r = await consent().run();
    expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<MissingPermissionFailure>()));
  });

  test('a token without refresh_token is a Failure, not an exception', () async {
    token = 'token_exchange_no_refresh';
    final r = await consent().run();
    expect(
      r,
      isA<Err<Object?>>().having(
        (e) => e.failure,
        'failure',
        isA<UnexpectedFailure>().having((f) => f.error, 'error', 'no refresh_token in code exchange'),
      ),
    );
  });

  test('desktop uses a loopback redirect', () async {
    await consent(loopback: true).run();
    expect(scheme, startsWith('http://localhost:'));
    expect(opened.queryParameters['redirect_uri'], scheme);
  });

  test('without a client ID it fails clearly, before opening anything', () async {
    var asked = false;
    final r = await consent(
      client: const GoogleClient(''),
      browser: (_) {
        asked = true;
        return '';
      },
    ).run();
    expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<ConfigurationFailure>()));
    expect(asked, isFalse);
  });

  test('closing the browser is a CancelledFailure', () async {
    final r = await consent(browser: (_) => throw PlatformException(code: 'CANCELED')).run();
    expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<CancelledFailure>()));
  });

  test('a callback with another state is refused, no code exchanged', () async {
    final r = await consent(browser: (u) => '${u.queryParameters['redirect_uri']}?state=forged&code=x').run();
    expect(r, isA<Err<Object?>>());
    expect(requests, isEmpty);
  });

  test('the Gmail consent never asks for Drive', () async {
    await consent().run(loginHint: 'ada@gmail.com');
    expect(opened.queryParameters['scope'], isNot(contains('drive')));
    expect(opened.queryParameters.containsKey('include_granted_scopes'), isFalse);
  });

  test('the incremental consent asks for drive.appdata on top of the granted scopes, for that address', () async {
    token = 'token_exchange_drive';
    final r = await consent().run(loginHint: 'ada@gmail.com', drive: true);

    expect(r, isA<Ok<OAuthGrant>>());
    final q = opened.queryParameters;
    expect(
      q['scope']!.split(' '),
      containsAll(['https://mail.google.com/', 'https://www.googleapis.com/auth/drive.appdata']),
    );
    expect(q['include_granted_scopes'], 'true');
    expect(q['login_hint'], 'ada@gmail.com');
  });

  test('a grant without drive.appdata is a DriveScopeFailure', () async {
    final r = await consent().run(drive: true);
    expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<DriveScopeFailure>()));
  });

  test('a grant without Gmail is still a MissingPermissionFailure when Drive is asked', () async {
    token = 'token_exchange_no_gmail';
    final r = await consent().run(drive: true);
    expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<MissingPermissionFailure>()));
  });
}
