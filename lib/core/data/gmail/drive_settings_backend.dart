import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../../domain/settings_backend.dart';
import 'gmail_failure.dart';
import 'google_auth.dart';
import 'google_client.dart';

/// The file of the Impostazioni di Postino in the hidden appDataFolder of an Account's Drive (ADR 0016),
/// over Drive v3 REST with the Account's tokens. Never an [AuthFailure]: a missing `drive.appdata` scope is a
/// [DriveScopeFailure], so the Account's mail is never marked Da ricollegare because of Drive.
class DriveSettingsBackend(
  String accountId,
  SecureStore keychain,
  final http.Client _http,
  Clock clock, {
  GoogleClient client = const GoogleClient.fromEnvironment(),
}) implements SettingsBackend {
  this : _auth = GoogleAuth(accountId, keychain, _http, clock, client: client);

  final GoogleAuth _auth;

  /// Il nome del file nella appDataFolder.
  static const fileName = 'postino-settings.json';
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _boundary = 'postino-settings-boundary';
  static const _timeout = Duration(seconds: 30);

  /// Found by the last read, so a write right after it does not search again.
  String? _fileId;

  @override
  Future<Result<String?>> read() => gmailGuard(() async {
    final id = await _find();
    if (id == null) return const Ok(null);
    return Ok((await _send('GET', Uri.parse('$_api/$id').replace(queryParameters: {'alt': 'media'}))).body);
  });

  @override
  Future<Result<void>> write(String json) => gmailGuard(() async {
    if ((_fileId ?? await _find()) case final id?) {
      await _send(
        'PATCH',
        Uri.parse('$_upload/$id').replace(queryParameters: {'uploadType': 'media'}),
        body: json,
        type: 'application/json',
      );
      return const Ok(null);
    }
    final metadata = jsonEncode({
      'name': fileName,
      'parents': ['appDataFolder'],
    });
    final r = await _send(
      'POST',
      Uri.parse(_upload).replace(queryParameters: {'uploadType': 'multipart'}),
      body: [
        '--$_boundary',
        'content-type: application/json; charset=UTF-8',
        '',
        metadata,
        '--$_boundary',
        'content-type: application/json; charset=UTF-8',
        '',
        json,
        '--$_boundary--',
      ].join('\r\n'),
      type: 'multipart/related; boundary=$_boundary',
    );
    _fileId = (jsonDecode(r.body) as Map<String, dynamic>)['id'] as String;
    return const Ok(null);
  });

  // ponytail: no If-Match on the upload; two devices writing at once may drop the other's voci from the file,
  // and the next cycle of that device writes them back (its merge always includes every local voce).
  Future<String?> _find() async {
    final r = await _send(
      'GET',
      Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name = '$fileName' and trashed = false",
          'fields': 'files(id)',
        },
      ),
    );
    final files = (jsonDecode(r.body) as Map<String, dynamic>)['files'] as List<dynamic>;
    return _fileId = files.isEmpty ? null : (files.first as Map<String, dynamic>)['id'] as String;
  }

  /// A Drive call with a valid token, refreshed once more on a 401; anything but a 200 throws a [GmailFailed].
  Future<http.Response> _send(String method, Uri url, {String? body, String? type}) async {
    var tokens = await _auth.validTokens();
    Future<http.Response> attempt() {
      final request = http.Request(method, url)..headers['authorization'] = 'Bearer ${tokens.access}';
      if (body != null) {
        request
          ..headers['content-type'] = type!
          ..body = body;
      }
      return _http.send(request).then(http.Response.fromStream).timeout(_timeout);
    }

    var r = await attempt();
    if (r.statusCode == 401) {
      tokens = await _auth.refresh(tokens);
      r = await attempt();
    }
    if (r.statusCode == 200) return r;
    throw GmailFailed(switch (r.statusCode) {
      429 => const RateLimitFailure(),
      403 when r.body.contains('ateLimitExceeded') => const RateLimitFailure(),
      // The token lacks drive.appdata: only the incremental consent fixes it.
      403 => const DriveScopeFailure(),
      404 => const NotFoundFailure(),
      _ => UnexpectedFailure('Drive: HTTP ${r.statusCode}'),
    });
  }
}
