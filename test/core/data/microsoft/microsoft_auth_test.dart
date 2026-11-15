// The refresh of a Microsoft Account's tokens, over a MockClient standing for the token endpoint.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/microsoft/microsoft_auth.dart';
import 'package:postino/core/data/microsoft/microsoft_client.dart';
import 'package:postino/core/data/oauth/oauth_auth.dart';
import 'package:postino/core/data/oauth/oauth_failed.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

const _account = 'microsoft:ada@outlook.com';
final _now = DateTime.utc(2026, 11, 8, 12);

http.Response _fixture(String name) {
  final j = jsonDecode(File('test/fixtures/graph/$name.json').readAsStringSync()) as Map<String, dynamic>;
  return http.Response(jsonEncode(j['body']), j['status'] as int);
}

FakeSecureStore _keychain({Duration validFor = const Duration(hours: 1)}) {
  final keychain = FakeSecureStore();
  // FakeSecureStore writes synchronously.
  OAuthTokens(
    access: 'EwB.initial',
    refresh: 'M.C5.initial',
    expiresAt: _now.add(validFor),
  ).write(keychain, _account).ignore();
  return keychain;
}

({OAuthAuth auth, List<http.Request> requests}) _auth(FakeSecureStore keychain, {String token = 'token_refresh'}) {
  final requests = <http.Request>[];
  final auth = microsoftAuth(
    _account,
    keychain,
    MockClient((r) async {
      requests.add(r);
      return _fixture(token);
    }),
    FakeClock(_now),
    client: const MicrosoftClient('00000000-test-0000-0000-000000000000'),
  );
  return (auth: auth, requests: requests);
}

Matcher _throwsFailure<F>() => throwsA(isA<OAuthFailed>().having((e) => e.failure, 'failure', isA<F>()));

void main() {
  test('refresh goes to the common token endpoint and the rotated refresh token replaces the old one', () async {
    final keychain = _keychain();
    final t = _auth(keychain);
    await t.auth.refresh(await t.auth.tokens());

    final r = t.requests.single;
    expect(r.url, Uri.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token'));
    expect(r.bodyFields, {
      'grant_type': 'refresh_token',
      'refresh_token': 'M.C5.initial',
      'client_id': '00000000-test-0000-0000-000000000000',
    });
    final saved = (await OAuthTokens.read(keychain, _account))!;
    expect((saved.access, saved.refresh), ('EwB.refreshed', 'M.C5.rotated'));
    expect(saved.expiresAt, _now.add(const Duration(seconds: 3599)));
  });

  test('invalid_grant is an AuthFailure, the tokens stay as they were', () async {
    final keychain = _keychain(validFor: Duration.zero);
    final t = _auth(keychain, token: 'token_invalid_grant');

    await expectLater(t.auth.validTokens(), _throwsFailure<AuthFailure>());
    expect((await OAuthTokens.read(keychain, _account))!.refresh, 'M.C5.initial');
  });

  test('interaction_required (MFA, Conditional Access) is an AuthFailure: the Account is to reconnect', () async {
    final keychain = _keychain(validFor: Duration.zero);
    final t = _auth(keychain, token: 'token_interaction_required');

    await expectLater(t.auth.validTokens(), _throwsFailure<AuthFailure>());
    expect((await OAuthTokens.read(keychain, _account))!.refresh, 'M.C5.initial');
  });

  test('a 401 from the token endpoint is an AuthFailure too', () async {
    final auth = microsoftAuth(
      _account,
      _keychain(validFor: Duration.zero),
      MockClient((_) async => http.Response('{}', 401)),
      FakeClock(_now),
      client: const MicrosoftClient('x'),
    );
    await expectLater(auth.validTokens(), _throwsFailure<AuthFailure>());
  });
}
