// Gmail adapter on recorded HTTP responses (test/fixtures/gmail): no network.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_provider.dart';
import 'package:postino/core/data/gmail/gmail_tokens.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../domain/mail_provider_contract.dart';

const _account = 'gmail:ada@gmail.com';
final _now = DateTime.utc(2026, 10, 28, 12);

http.Response _fixture(String name) {
  final j = jsonDecode(
    File('test/fixtures/gmail/$name.json').readAsStringSync(),
  );
  return http.Response(
    jsonEncode(j['body']),
    j['status'] as int,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Google as seen over HTTP: the token endpoint and the Gmail API, from recorded responses.
class GmailHarness implements ContractHarness {
  GmailHarness({
    String access = 'ya29.initial',
    Duration validFor = const Duration(hours: 1),
  }) {
    // FakeSecureStore writes synchronously.
    GmailTokens(
      access: access,
      refresh: '1//refresh',
      expiresAt: _now.add(validFor),
    ).write(keychain, _account);
  }

  final keychain = FakeSecureStore();
  final requests = <http.Request>[];
  final _accepted = {'ya29.initial', 'ya29.refreshed'};
  bool _authBroken = false, _offline = false;

  @override
  late final MailProvider provider = GmailProvider(
    _account,
    keychain,
    MockClient((r) async {
      requests.add(r);
      if (_offline) throw http.ClientException('Failed host lookup');
      if (r.url.host == 'oauth2.googleapis.com') {
        return _fixture(_authBroken ? 'token_invalid_grant' : 'token_refresh');
      }
      final bearer = r.headers['authorization']?.substring('Bearer '.length);
      return _fixture(_accepted.contains(bearer) ? 'profile' : 'unauthorized');
    }),
    FakeClock(_now),
    const GoogleClient('test-client.apps.googleusercontent.com'),
  );

  Future<GmailTokens?> get tokens => GmailTokens.read(keychain, _account);

  // ponytail: mailbox simulation comes with the Gmail sync (#31).
  @override
  void deliver(Message m) => throw UnimplementedError('#31');
  @override
  void removeRemotely(String id) => throw UnimplementedError('#31');

  @override
  void goOffline() => _offline = true;

  @override
  void breakAuth() {
    _authBroken = true;
    _accepted.clear();
  }
}

Matcher _err<F>() => isA<Err>().having((e) => e.failure, 'failure', isA<F>());

void main() {
  mailProviderAuthContract('GmailProvider', GmailHarness.new);

  test('refreshAuth swaps the access token in the keychain, keeping the refresh token', () async {
    final h = GmailHarness();
    expect(await h.provider.refreshAuth(), isA<Ok>());

    final r = h.requests.single;
    expect(r.url, Uri.parse('https://oauth2.googleapis.com/token'));
    expect(r.bodyFields, {
      'grant_type': 'refresh_token',
      'refresh_token': '1//refresh',
      'client_id': 'test-client.apps.googleusercontent.com',
    });
    final t = (await h.tokens)!;
    expect(t.access, 'ya29.refreshed');
    expect(t.refresh, '1//refresh');
    expect(t.expiresAt, _now.add(const Duration(seconds: 3599)));
  });

  test('an expired access token is refreshed before calling Gmail', () async {
    final h = GmailHarness(validFor: Duration.zero);
    expect(await h.provider.initialSync(), isNot(_err<AuthFailure>()));
    expect(
      [for (final r in h.requests) r.url.path],
      ['/token', '/gmail/v1/users/me/profile'],
    );
    expect(h.requests.last.headers['authorization'], 'Bearer ya29.refreshed');
  });

  test('a 401 from Gmail refreshes the token once and retries', () async {
    final h = GmailHarness(access: 'ya29.stale');
    expect(await h.provider.initialSync(), isNot(_err<AuthFailure>()));
    expect(
      [for (final r in h.requests) r.headers['authorization'] ?? r.url.path],
      ['Bearer ya29.stale', '/token', 'Bearer ya29.refreshed'],
    );
  });

  test('a 403 for insufficient scope is an AuthFailure, so the Account is Da ricollegare', () async {
    final h = GmailHarness();
    final p = GmailProvider(
      _account,
      h.keychain,
      MockClient((_) async => _fixture('insufficient_scope')),
      FakeClock(_now),
      const GoogleClient('test-client.apps.googleusercontent.com'),
    );
    expect(await p.initialSync(), _err<AuthFailure>());
  });

  test('no tokens in the keychain is an AuthFailure', () async {
    final h = GmailHarness()..keychain.values.clear();
    expect(await h.provider.refreshAuth(), _err<AuthFailure>());
    expect(await h.provider.initialSync(), _err<AuthFailure>());
    expect(h.requests, isEmpty);
  });
}
