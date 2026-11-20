// The OAuth tokens of a Google Account on their own, over a MockClient standing for the token endpoint.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/oauth/oauth_auth.dart';
import 'package:postino/core/data/oauth/oauth_failed.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart';

/// A OAuthAuth on [keychain], the token endpoint answering the recorded `token_refresh` or [token].
({OAuthAuth auth, List<http.Request> requests}) _auth(FakeSecureStore keychain, {String token = 'token_refresh'}) {
  final requests = <http.Request>[];
  final auth = OAuthAuth(
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

Matcher _throwsFailure<F>() => throwsA(isA<OAuthFailed>().having((e) => e.failure, 'failure', isA<F>()));

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
    final saved = (await OAuthTokens.read(keychain, gmailAccount))!;
    expect((saved.access, saved.refresh), ('ya29.refreshed', '1//refresh'));
    expect(saved.expiresAt, gmailNow.add(const Duration(seconds: 3599)));
  });

  test('a refresh that ends after the Account was removed does not write its tokens back (#174)', () async {
    final keychain = gmailKeychain();
    final t = _auth(keychain);
    final old = await t.auth.tokens();
    await OAuthTokens.delete(keychain, gmailAccount);

    await t.auth.refresh(old);

    expect(keychain.values, isEmpty);
  });

  test('a refresh that ends after the Account was connected again keeps the new tokens (#174)', () async {
    final keychain = gmailKeychain();
    final t = _auth(keychain);
    final old = await t.auth.tokens();
    await OAuthTokens(access: 'new', refresh: '1//new', expiresAt: gmailNow).write(keychain, gmailAccount);

    await t.auth.refresh(old);

    expect((await OAuthTokens.read(keychain, gmailAccount))!.refresh, '1//new');
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
    await expectLater(
      none.auth.validTokens(),
      throwsA(
        isA<OAuthFailed>().having((e) => '${e.failure}', 'failure', 'AuthFailure(token refresh: no tokens here)'),
      ),
    );
    expect(none.requests, isEmpty);

    final revoked = _auth(gmailKeychain(validFor: Duration.zero), token: 'token_invalid_grant');
    await expectLater(revoked.auth.validTokens(), _throwsFailure<AuthFailure>());
  });

  test('invalid_grant says why in the AuthFailure: Provider, status and error, never the description (#353)', () async {
    final refused = _auth(gmailKeychain(validFor: Duration.zero), token: 'token_invalid_grant');
    await expectLater(
      refused.auth.validTokens(),
      throwsA(
        isA<OAuthFailed>().having(
          (e) => '${e.failure}',
          'failure',
          'AuthFailure(token refresh: oauth2.googleapis.com, HTTP 400, invalid_grant)',
        ),
      ),
    );
  });

  test('a token adopted from the synced file is said so when it is refused (#353)', () async {
    final keychain = FakeSecureStore();
    await OAuthTokens(
      access: '',
      refresh: '1//from-file',
      expiresAt: DateTime.utc(1970),
      synced: true,
    ).write(keychain, gmailAccount);
    // A refresh that works keeps knowing where the refresh token came from.
    await _auth(keychain).auth.validTokens();
    expect((await OAuthTokens.read(keychain, gmailAccount))!.synced, isTrue);
    await OAuthTokens(
      access: '',
      refresh: '1//from-file',
      expiresAt: DateTime.utc(1970),
      synced: true,
    ).write(keychain, gmailAccount);
    final refused = _auth(keychain, token: 'token_invalid_grant');
    await expectLater(
      refused.auth.validTokens(),
      throwsA(isA<OAuthFailed>().having((e) => '${e.failure}', 'failure', endsWith('invalid_grant, synced token)'))),
    );
  });

  test('the client refused, not the token: an UnexpectedFailure, the Account stays connected (#353)', () async {
    for (final (status, error) in [(401, 'invalid_client'), (401, 'unauthorized_client'), (400, 'invalid_request')]) {
      final auth = OAuthAuth(
        gmailAccount,
        gmailKeychain(validFor: Duration.zero),
        MockClient((_) async => gmailJson({'error': error, 'error_description': 'Unauthorized'}, status)),
        FakeClock(gmailNow),
        client: gmailTestClient,
      );
      await expectLater(
        auth.validTokens(),
        throwsA(
          isA<OAuthFailed>().having(
            (e) => '${e.failure}',
            'failure',
            'UnexpectedFailure(token refresh: oauth2.googleapis.com, HTTP $status, $error)',
          ),
        ),
      );
    }
  });

  test('an error code longer than an OAuth one is cut in the log (#353)', () async {
    final long = 'x' * 50;
    final auth = OAuthAuth(
      gmailAccount,
      gmailKeychain(validFor: Duration.zero),
      MockClient((_) async => gmailJson({'error': long}, 400)),
      FakeClock(gmailNow),
      client: gmailTestClient,
    );
    await expectLater(
      auth.validTokens(),
      throwsA(isA<OAuthFailed>().having((e) => '${e.failure}', 'failure', endsWith('HTTP 400, ${'x' * 40})'))),
    );
  });

  test('a refused refresh tries once the refresh token another device brought meanwhile (#321)', () async {
    final keychain = gmailKeychain(validFor: Duration.zero);
    final requests = <String>[];
    final auth = OAuthAuth(
      gmailAccount,
      keychain,
      MockClient((r) async {
        requests.add(r.bodyFields['refresh_token']!);
        // The voce from another device arrives while this refresh is in flight.
        if (requests.length == 1) {
          await OAuthTokens(access: 'a', refresh: '1//arrived', expiresAt: gmailNow).write(keychain, gmailAccount);
          return gmailFixture('token_invalid_grant');
        }
        return gmailFixture('token_refresh');
      }),
      FakeClock(gmailNow),
      client: gmailTestClient,
    );

    expect((await auth.validTokens()).access, 'ya29.refreshed');
    expect(requests, ['1//refresh', '1//arrived']);
    expect((await auth.tokens())!.refresh, '1//arrived');
  });

  test('a refresh token refused with nothing else in the keychain, or refused again, is an AuthFailure', () async {
    final same = _auth(gmailKeychain(validFor: Duration.zero), token: 'token_invalid_grant');
    await expectLater(same.auth.validTokens(), _throwsFailure<AuthFailure>());
    expect(same.requests, hasLength(1));

    // The one tried again is refused too: no further round.
    final keychain = gmailKeychain(validFor: Duration.zero);
    var n = 0;
    final auth = OAuthAuth(
      gmailAccount,
      keychain,
      MockClient((r) async {
        await OAuthTokens(access: 'a', refresh: '1//other-${n++}', expiresAt: gmailNow).write(keychain, gmailAccount);
        return gmailFixture('token_invalid_grant');
      }),
      FakeClock(gmailNow),
      client: gmailTestClient,
    );
    await expectLater(auth.validTokens(), _throwsFailure<AuthFailure>());
    expect(n, 2);
  });

  test('a keychain that fails the read again after a refused refresh still answers AuthFailure (#321)', () async {
    final keychain = gmailKeychain(validFor: Duration.zero);
    final auth = OAuthAuth(
      gmailAccount,
      keychain,
      MockClient((r) async {
        keychain.failure = Exception('locked');
        return gmailFixture('token_invalid_grant');
      }),
      FakeClock(gmailNow),
      client: gmailTestClient,
    );
    await expectLater(auth.validTokens(), _throwsFailure<AuthFailure>());
  });

  test('the scopes of a token saved without them are learnt at its refresh, then kept (#321)', () async {
    final keychain = gmailKeychain(validFor: Duration.zero);
    final t = _auth(keychain);
    await t.auth.validTokens();
    expect((await t.auth.tokens())!.scopes, ['https://mail.google.com/']);

    const consented = ['https://mail.google.com/', 'openid', 'https://www.googleapis.com/auth/drive.appdata'];
    await OAuthTokens(
      access: 'a',
      refresh: '1//refresh',
      expiresAt: gmailNow,
      scopes: consented,
    ).write(keychain, gmailAccount);
    await t.auth.validTokens();
    expect((await t.auth.tokens())!.scopes, consented);
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
