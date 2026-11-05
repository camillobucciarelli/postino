// The OAuth tokens of a Google Account on their own, over a MockClient standing for the token endpoint.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_tokens.dart';
import 'package:postino/core/data/gmail/google_auth.dart';
import 'package:postino/core/data/gmail/google_failure.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart';

/// A GoogleAuth on [keychain], the token endpoint answering the recorded `token_refresh` or [token].
({GoogleAuth auth, List<http.Request> requests}) _auth(FakeSecureStore keychain, {String token = 'token_refresh'}) {
  final requests = <http.Request>[];
  final auth = GoogleAuth(
    gmailAccount,
    keychain,
    MockClient((r) async {
      requests.add(r);
      return gmailFixture(token);
    }),
    FakeClock(gmailNow),
    client: gmailTestClient,
  );
  return (auth: auth, requests: requests);
}

Matcher _throwsFailure<F>() => throwsA(isA<GoogleFailed>().having((e) => e.failure, 'failure', isA<F>()));

void main() {
  test('refresh swaps the access token in the keychain, keeping the refresh token', () async {
    final keychain = gmailKeychain();
    final t = _auth(keychain);
    await t.auth.refresh(await t.auth.tokens());

    final r = t.requests.single;
    expect(r.url, Uri.parse('https://oauth2.googleapis.com/token'));
    expect(r.bodyFields, {
      'grant_type': 'refresh_token',
      'refresh_token': '1//refresh',
      'client_id': 'test-client.apps.googleusercontent.com',
    });
    final saved = (await GmailTokens.read(keychain, gmailAccount))!;
    expect((saved.access, saved.refresh), ('ya29.refreshed', '1//refresh'));
    expect(saved.expiresAt, gmailNow.add(const Duration(seconds: 3599)));
  });

  test('validTokens keeps a valid access token and refreshes an expired one', () async {
    final valid = _auth(gmailKeychain());
    expect((await valid.auth.validTokens()).access, 'ya29.initial');
    expect(valid.requests, isEmpty);

    final expired = _auth(gmailKeychain(validFor: Duration.zero));
    expect((await expired.auth.validTokens()).access, 'ya29.refreshed');
    expect(expired.requests.single.url.path, '/token');
  });

  test('no tokens in the keychain, or a revoked refresh token, is an AuthFailure', () async {
    final none = _auth(FakeSecureStore());
    await expectLater(none.auth.validTokens(), _throwsFailure<AuthFailure>());
    expect(none.requests, isEmpty);

    final revoked = _auth(gmailKeychain(validFor: Duration.zero), token: 'token_invalid_grant');
    await expectLater(revoked.auth.validTokens(), _throwsFailure<AuthFailure>());
  });

  test('authorized sends again with a refreshed token after a 401, once', () async {
    final t = _auth(gmailKeychain());
    final sent = <String>[];
    final r = await t.auth.authorized((access) async {
      sent.add(access);
      return http.Response(jsonEncode({}), 401);
    });
    expect(r.statusCode, 401);
    expect(sent, ['ya29.initial', 'ya29.refreshed']);
  });
}
