// The file of the Impostazioni di Postino on Drive (#124), over a MockClient standing for Drive v3.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/drive_settings_backend.dart';
import 'package:postino/core/data/gmail/gmail_tokens.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';

const _account = 'gmail:ada@gmail.com';
final _now = DateTime.utc(2026, 11, 5, 12);

/// A Drive with one appDataFolder: what the backend sends, and what it would answer.
class _Drive() {
  String? content;
  final requests = <http.Request>[];

  /// While set, every call answers it.
  http.Response? failure;

  late final client = MockClient((r) async {
    requests.add(r);
    if (failure case final f?) return f;
    if (r.method == 'GET' && r.url.path == '/drive/v3/files') {
      return http.Response(
        jsonEncode({
          'files': [
            if (content != null) {'id': 'f1'},
          ],
        }),
        200,
      );
    }
    if (r.method == 'GET' && r.url.path == '/drive/v3/files/f1') return http.Response(content!, 200);
    if (r.method == 'POST' && r.url.path == '/upload/drive/v3/files') {
      content = r.body.split('\r\n')[7];
      return http.Response(jsonEncode({'id': 'f1'}), 200);
    }
    if (r.method == 'PATCH' && r.url.path == '/upload/drive/v3/files/f1') {
      content = r.body;
      return http.Response('{}', 200);
    }
    return http.Response('?', 500);
  });

  DriveSettingsBackend backend() {
    final keychain = FakeSecureStore();
    unawaited(
      GmailTokens(
        access: 'ya29.a',
        refresh: '1//r',
        expiresAt: _now.add(const Duration(hours: 1)),
      ).write(keychain, _account),
    );
    return DriveSettingsBackend(_account, keychain, client, FakeClock(_now), client: const GoogleClient('test'));
  }
}

void main() {
  test('no file reads null; the first write creates it in the appDataFolder, the next ones update it', () async {
    final drive = _Drive();
    final backend = drive.backend();
    expect(await backend.read(), isA<Ok<String?>>().having((r) => r.value, 'value', isNull));
    expect(drive.requests.single.url.queryParameters['spaces'], 'appDataFolder');

    expect(await backend.write('{"schemaVersion":1}'), isA<Ok<void>>());
    final create = drive.requests.last;
    expect(create.url.queryParameters['uploadType'], 'multipart');
    expect(create.headers['authorization'], 'Bearer ya29.a');
    expect(create.body, contains('"parents":["appDataFolder"]'));
    expect(create.body, contains('"name":"postino-settings.json"'));
    expect(drive.content, '{"schemaVersion":1}');

    final other = drive.backend();
    expect(await other.read(), isA<Ok<String?>>().having((r) => r.value, 'value', '{"schemaVersion":1}'));
    expect(await other.write('{"schemaVersion":1,"entries":{}}'), isA<Ok<void>>());
    expect(drive.requests.last.method, 'PATCH');
    expect(drive.content, '{"schemaVersion":1,"entries":{}}');
  });

  test('a 403 without the drive.appdata scope is its own failure, not an AuthFailure', () async {
    final drive = _Drive()..failure = http.Response('{"error":{"errors":[{"reason":"insufficientScopes"}]}}', 403);
    final r = await drive.backend().read();
    expect(r, isA<Err<String?>>().having((e) => e.failure, 'failure', isA<DriveScopeFailure>()));
  });

  test('a quota hit is a RateLimitFailure, no network an OfflineFailure', () async {
    final drive = _Drive()..failure = http.Response('{"reason":"userRateLimitExceeded"}', 403);
    expect((await drive.backend().write('{}') as Err).failure, isA<RateLimitFailure>());
    final offline = DriveSettingsBackend(
      _account,
      FakeSecureStore()
        ..values['oauth:$_account'] = jsonEncode({
          'access': 'a',
          'refresh': 'r',
          'expiresAt': _now.add(const Duration(hours: 1)).toIso8601String(),
        }),
      MockClient((_) => throw http.ClientException('offline')),
      FakeClock(_now),
      client: const GoogleClient('test'),
    );
    expect((await offline.read() as Err).failure, isA<OfflineFailure>());
  });
}
