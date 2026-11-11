// The Microsoft consent on hand-written token responses (test/fixtures/graph); the browser step is faked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/microsoft/microsoft_client.dart';
import 'package:postino/core/data/microsoft/microsoft_consent.dart';
import 'package:postino/core/domain/oauth_grant.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

// A made-up client ID: never the registered one.
const _client = MicrosoftClient('00000000-test-0000-0000-000000000000');
final _now = DateTime.utc(2026, 11, 8, 12);

http.Response _fixture(String name) {
  final j = jsonDecode(File('test/fixtures/graph/$name.json').readAsStringSync()) as Map<String, dynamic>;
  return http.Response(jsonEncode(j['body']), j['status'] as int);
}

void main() {
  late List<http.Request> requests;
  late Uri opened;
  late String scheme;
  var token = 'token_exchange';

  MicrosoftWebConsent consent({
    MicrosoftClient client = _client,
    bool loopback = false,
    String Function(Uri url)? browser,
  }) => MicrosoftWebConsent(
    MockClient((r) async {
      requests.add(r);
      return _fixture(token);
    }),
    FakeClock(_now),
    client: client,
    authenticate: ({required url, required callbackUrlScheme}) async {
      opened = Uri.parse(url);
      scheme = callbackUrlScheme;
      return browser?.call(opened) ??
          '${opened.queryParameters['redirect_uri']}?state=${opened.queryParameters['state']}&code=M.C5.code';
    },
    loopback: loopback,
  );

  Matcher failsWith<F>() => isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<F>());

  setUp(() {
    requests = [];
    token = 'token_exchange';
  });

  test('consent at the consumers endpoint with PKCE, then the code is exchanged for tokens and the address', () async {
    final r = await consent().run(loginHint: 'ada@outlook.com');

    final grant = (r as Ok<OAuthGrant>).value;
    // From the id_token's `email`, lower case.
    expect(grant.address, 'ada@outlook.com');
    expect(grant.accessToken, 'EwB.granted');
    expect(grant.refreshToken, 'M.C5.granted');
    expect(grant.expiresAt, _now.add(const Duration(seconds: 3599)));

    expect(opened.host, 'login.microsoftonline.com');
    expect(opened.path, '/consumers/oauth2/v2.0/authorize');
    final q = opened.queryParameters;
    expect(q['client_id'], _client.id);
    expect(q['response_type'], 'code');
    expect(q['scope']!.split(' '), ['openid', 'email', 'offline_access', 'User.Read', 'Mail.ReadWrite', 'Mail.Send']);
    expect(q['prompt'], 'select_account');
    expect(q['login_hint'], 'ada@outlook.com');
    expect(q['code_challenge_method'], 'S256');
    expect(q['code_challenge'], isNotEmpty);
    expect(scheme, 'msal${_client.id}');
    expect(q['redirect_uri'], 'msal${_client.id}://auth');

    final exchange = requests.single;
    expect(exchange.url, Uri.parse('https://login.microsoftonline.com/consumers/oauth2/v2.0/token'));
    expect(exchange.bodyFields, {
      'grant_type': 'authorization_code',
      'code': 'M.C5.code',
      'code_verifier': exchange.bodyFields['code_verifier'],
      'redirect_uri': q['redirect_uri'],
      'client_id': _client.id,
    });
    expect(exchange.bodyFields['code_verifier'], isNotEmpty);
  });

  test('IMAP.AccessAsUser.All is not asked: polling only for Microsoft in v1', () async {
    await consent().run();
    expect(opened.queryParameters['scope'], isNot(contains('IMAP')));
  });

  test('without a login hint none is sent', () async {
    await consent().run();
    expect(opened.queryParameters.containsKey('login_hint'), isFalse);
  });

  test('the address falls back to preferred_username when the id_token has no email', () async {
    token = 'token_exchange_no_email_claim';
    final r = await consent().run();
    expect((r as Ok<OAuthGrant>).value.address, 'ada@hotmail.it');
  });

  test('desktop uses a loopback redirect', () async {
    await consent(loopback: true).run();
    expect(scheme, 'http://localhost:53682');
    expect(opened.queryParameters['redirect_uri'], scheme);
  });

  test('without a client ID it fails clearly, before opening anything', () async {
    var asked = false;
    final r = await consent(
      client: const MicrosoftClient(''),
      browser: (_) {
        asked = true;
        return '';
      },
    ).run();
    expect(r, failsWith<ConfigurationFailure>());
    expect((r as Err).failure.toString(), 'ConfigurationFailure(MICROSOFT_CLIENT_ID)');
    expect(asked, isFalse);
  });

  test('closing the browser is a CancelledFailure, nothing is exchanged', () async {
    final r = await consent(browser: (_) => throw PlatformException(code: 'CANCELED')).run();
    expect(r, failsWith<CancelledFailure>());
    expect(requests, isEmpty);
  });

  test('a callback without a code (access_denied) is a CancelledFailure', () async {
    final r = await consent(
      browser: (u) => '${u.queryParameters['redirect_uri']}?state=${u.queryParameters['state']}&error=access_denied',
    ).run();
    expect(r, failsWith<CancelledFailure>());
  });

  test('a callback with another state is refused, no code exchanged', () async {
    final r = await consent(browser: (u) => '${u.queryParameters['redirect_uri']}?state=forged&code=x').run();
    expect(r, failsWith<UnexpectedFailure>());
    expect(requests, isEmpty);
  });

  test('a work or school account (another tid) is a WorkAccountFailure', () async {
    token = 'token_exchange_work_account';
    expect(await consent().run(), failsWith<WorkAccountFailure>());
  });

  test('a token without Mail.Send (granular consent) is a MissingPermissionFailure', () async {
    token = 'token_exchange_no_mail_scope';
    expect(await consent().run(), failsWith<MissingPermissionFailure>());
  });

  test('a refused code exchange is a Failure, not an exception', () async {
    token = 'token_invalid_grant';
    expect(await consent().run(), failsWith<UnexpectedFailure>());
  });

  test('no network during the exchange is an OfflineFailure', () async {
    final offline = MicrosoftWebConsent(
      MockClient((_) async => throw http.ClientException('no network')),
      FakeClock(_now),
      client: _client,
      authenticate: ({required url, required callbackUrlScheme}) async {
        final q = Uri.parse(url).queryParameters;
        return '${q['redirect_uri']}?state=${q['state']}&code=x';
      },
      loopback: false,
    );
    expect(await offline.run(), failsWith<OfflineFailure>());
  });
}
