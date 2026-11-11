// Gmail answering with the recorded HTTP responses of test/fixtures/gmail: no network.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/gmail_provider.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';
import 'package:postino/core/domain/result.dart';

import 'fake_platform.dart';

const gmailAccount = 'gmail:ada@gmail.com';
final gmailNow = DateTime.utc(2026, 10, 28, 12);
const gmailTestClient = GoogleClient('test-client.apps.googleusercontent.com');
const gmailApi = '/gmail/v1/users/me/';

/// The recorded response `test/fixtures/gmail/<name>.json`.
http.Response gmailFixture(String name) {
  final j = jsonDecode(File('test/fixtures/gmail/$name.json').readAsStringSync()) as Map<String, dynamic>;
  final status = j['status'] as int;
  // A 204 (batchModify) has no body.
  return j['body'] == null ? http.Response('', status) : gmailJson(j['body'] as Object, status);
}

http.Response gmailJson(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// A keychain holding [gmailAccount]'s tokens.
FakeSecureStore gmailKeychain({String access = 'ya29.initial', Duration validFor = const Duration(hours: 1)}) {
  final keychain = FakeSecureStore();
  // FakeSecureStore writes synchronously.
  unawaited(
    OAuthTokens(access: access, refresh: '1//refresh', expiresAt: gmailNow.add(validFor)).write(keychain, gmailAccount),
  );
  return keychain;
}

Matcher isErr<F>() => isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<F>());

T okValue<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

/// Gmail answering each request with the recorded response `route` names.
class RecordedGmail(String Function(http.Request r, String path) route) {
  this {
    provider = GmailProvider(
      gmailAccount,
      gmailKeychain(),
      MockClient((r) async {
        requests.add(r);
        // The token refresh a 401 triggers.
        if (r.url.host == 'oauth2.googleapis.com') return gmailFixture('token_refresh');
        return gmailFixture(route(r, r.url.path.substring(gmailApi.length)));
      }),
      FakeClock(gmailNow),
      client: gmailTestClient,
      sleep: (d) async => sleeps.add(d),
    );
  }

  late final GmailProvider provider;
  final requests = <http.Request>[];
  final sleeps = <Duration>[];

  Iterable<Uri> get urls => requests.map((r) => r.url);
}
