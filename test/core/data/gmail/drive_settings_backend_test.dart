// The file of the Impostazioni di Postino on Drive (#124), over a MockClient standing for Drive v3.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/drive_http.dart';
import 'package:postino/core/data/gmail/drive_settings_backend.dart';
import 'package:postino/core/data/gmail/gmail_tokens.dart';
import 'package:postino/core/data/gmail/google_client.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_document.dart';
import 'package:postino/core/domain/settings_entry.dart';

import '../../../support/fake_platform.dart';

const _account = 'gmail:ada@gmail.com';
final _now = DateTime.utc(2026, 11, 5, 12);

/// A Drive with one appDataFolder: its files by id, oldest first, and what the backend sends.
class _Drive() {
  final files = <String, String>{};
  final requests = <http.Request>[];
  var _seq = 0;

  late final client = MockClient((r) async {
    requests.add(r);
    final path = r.url.path;
    if (r.method == 'GET' && path == '/drive/v3/files') {
      return http.Response(
        jsonEncode({
          'files': [
            for (final id in files.keys) {'id': id},
          ],
        }),
        200,
      );
    }
    if (r.method == 'POST' && path == '/upload/drive/v3/files') {
      final id = 'f${++_seq}';
      files[id] = r.body.split('\r\n')[7];
      return http.Response(jsonEncode({'id': id}), 200);
    }
    final id = path.split('/').last;
    if (!files.containsKey(id)) return http.Response('?', 404);
    switch (r.method) {
      case 'GET':
        return http.Response(files[id]!, 200);
      case 'PATCH':
        files[id] = r.body;
        return http.Response(jsonEncode({'id': id}), 200);
      case 'DELETE':
        files.remove(id);
        return http.Response('', 204);
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
    return DriveSettingsBackend(
      DriveHttp(_account, keychain, client, FakeClock(_now), client: const GoogleClient('test')),
    );
  }
}

SettingsEntry _e(String key, int at, [String device = 'A']) =>
    SettingsEntry(key: key, value: '{"at":$at}', updatedAt: at, deviceId: device);

void main() {
  test('no file reads null; the first write creates it in the appDataFolder, the next ones update it', () async {
    final drive = _Drive();
    final backend = drive.backend();
    expect(await backend.read(), isA<Ok<String?>>().having((r) => r.value, 'value', isNull));
    final list = drive.requests.single.url.queryParameters;
    expect((list['spaces'], list['orderBy']), ('appDataFolder', 'createdTime'));

    expect(await backend.write('{"schemaVersion":1}'), isA<Ok<void>>());
    final create = drive.requests.last;
    expect(create.url.queryParameters['uploadType'], 'multipart');
    expect(create.headers['authorization'], 'Bearer ya29.a');
    expect(create.body, contains('"parents":["appDataFolder"]'));
    expect(create.body, contains('"name":"postino-settings.json"'));
    expect(drive.files, {'f1': '{"schemaVersion":1}'});

    final other = drive.backend();
    expect(await other.read(), isA<Ok<String?>>().having((r) => r.value, 'value', '{"schemaVersion":1}'));
    expect(await other.write('{"schemaVersion":1,"entries":{}}'), isA<Ok<void>>());
    expect(drive.requests.last.method, 'PATCH');
    expect(drive.files, {'f1': '{"schemaVersion":1,"entries":{}}'});
  });

  test('two files from a concurrent first write are merged into the oldest, the other deleted', () async {
    final drive = _Drive()
      ..files['f1'] = encodeSettings([_e('auto_labels/a1', 5), _e('auto_labels/a2', 1)])
      ..files['f2'] = encodeSettings([_e('auto_labels/a1', 3, 'B'), _e('auto_labels/a3', 2, 'B')]);
    final r = await drive.backend().read();

    final merged = [_e('auto_labels/a1', 5), _e('auto_labels/a2', 1), _e('auto_labels/a3', 2, 'B')];
    expect(r, isA<Ok<String?>>().having((r) => r.value, 'value', encodeSettings(merged)));
    expect(drive.files, {'f1': encodeSettings(merged)});
  });

  test('a duplicate that cannot be read is left alone: the oldest is read as it is', () async {
    final oldest = encodeSettings([_e('auto_labels/a1', 5)]);
    final drive = _Drive()
      ..files['f1'] = oldest
      ..files['f2'] = 'nope';
    expect(await drive.backend().read(), isA<Ok<String?>>().having((r) => r.value, 'value', oldest));
    expect(drive.files.keys, ['f1', 'f2']);
    expect(drive.requests.map((r) => r.method), everyElement('GET'));
  });
}
