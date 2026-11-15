import 'dart:async';
import 'dart:convert';

import '../../domain/result.dart';
import '../../domain/settings_backend.dart';
import '../oauth/oauth_guard.dart';
import 'drive_http.dart';

/// The file of the Impostazioni di Postino in the hidden appDataFolder of an Account's Drive (ADR 0016),
/// over [DriveHttp]: finding it, reading it, creating it and updating it. It moves sealed text and never sees the
/// key (ADR 0019): the copies doubled by two devices that created the file at once are merged by `SettingsSync`.
class DriveSettingsBackend(final DriveHttp _drive) implements SettingsBackend {
  /// Il nome del file nella appDataFolder.
  static const fileName = 'postino-settings.json';
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _boundary = 'postino-settings-boundary';

  /// The copies the last read found, oldest first: a write right after it does not search again.
  var _ids = <String>[];

  String? get _fileId => _ids.firstOrNull;

  @override
  Future<Result<List<String>>> read() => oauthGuard(() async {
    final ids = await _find();
    return Ok([for (final id in ids) (await _drive.send('GET', _media(id))).body]);
  });

  @override
  Future<Result<void>> dropDuplicates() => oauthGuard(() async {
    for (final id in _ids.skip(1)) {
      await _drive.send('DELETE', Uri.parse('$_api/$id'));
    }
    _ids = _ids.take(1).toList();
    return const Ok(null);
  });

  @override
  Future<Result<void>> write(String text) => oauthGuard(() async {
    if (_fileId ?? (await _find()).firstOrNull case final id?) {
      await _patch(id, text);
      return const Ok(null);
    }
    final metadata = jsonEncode({
      'name': fileName,
      'parents': ['appDataFolder'],
    });
    final r = await _drive.send(
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
        text,
        '--$_boundary--',
      ].join('\r\n'),
      type: 'multipart/related; boundary=$_boundary',
    );
    _ids = [(jsonDecode(r.body) as Map<String, dynamic>)['id'] as String];
    return const Ok(null);
  });

  // ponytail: no If-Match on the upload; two devices writing at once may drop the other's voci from the file,
  // and the next cycle of that device writes them back (its merge always includes every local voce).
  /// The ids of the file, oldest first: more than one when two devices created it at once.
  Future<List<String>> _find() async {
    final r = await _drive.send(
      'GET',
      Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name = '$fileName' and trashed = false",
          'orderBy': 'createdTime',
          'fields': 'files(id)',
        },
      ),
    );
    final files = (jsonDecode(r.body) as Map<String, dynamic>)['files'] as List<dynamic>;
    return _ids = [for (final f in files) (f as Map<String, dynamic>)['id'] as String];
  }

  Uri _media(String id) => Uri.parse('$_api/$id').replace(queryParameters: {'alt': 'media'});

  Future<void> _patch(String id, String json) => _drive.send(
    'PATCH',
    Uri.parse('$_upload/$id').replace(queryParameters: {'uploadType': 'media'}),
    body: json,
    type: 'application/json',
  );
}
