import 'dart:async';
import 'dart:convert';

import '../../domain/result.dart';
import '../../domain/settings_backend.dart';
import '../../domain/settings_document.dart';
import '../../domain/settings_entry.dart';
import '../../domain/settings_merge.dart';
import 'drive_http.dart';
import 'google_failure.dart';

/// The file of the Impostazioni di Postino in the hidden appDataFolder of an Account's Drive (ADR 0016),
/// over [DriveHttp]: finding it, reading it, creating it and updating it.
class DriveSettingsBackend(final DriveHttp _drive) implements SettingsBackend {
  /// Il nome del file nella appDataFolder.
  static const fileName = 'postino-settings.json';
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _boundary = 'postino-settings-boundary';

  /// Found by the last read, so a write right after it does not search again.
  String? _fileId;

  @override
  Future<Result<String?>> read() => googleGuard(() async {
    final ids = await _find();
    if (ids.isEmpty) return const Ok(null);
    final contents = [for (final id in ids) (await _drive.send('GET', _media(id))).body];
    if (contents.length == 1) return Ok(contents.single);
    return Ok(await _mergeDuplicates(ids, contents));
  });

  @override
  Future<Result<void>> write(String json) => googleGuard(() async {
    if (_fileId ?? (await _find()).firstOrNull case final id?) {
      await _patch(id, json);
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
    final ids = [for (final f in files) (f as Map<String, dynamic>)['id'] as String];
    _fileId = ids.firstOrNull;
    return ids;
  }

  /// Duplicates merged last-write-wins into the oldest, the others deleted, so every device reads one file.
  /// A copy that cannot be read or comes from a newer Postino is never touched: the oldest is read as it is.
  Future<String> _mergeDuplicates(List<String> ids, List<String> contents) async {
    var merged = <String, SettingsEntry>{};
    for (final c in contents) {
      if (decodeSettings(c) case Ok(:final value) when value.writable) {
        merged = mergeSettings(merged, value.entries);
      } else {
        return contents.first;
      }
    }
    final json = encodeSettings(merged.values);
    await _patch(ids.first, json);
    for (final id in ids.skip(1)) {
      await _drive.send('DELETE', Uri.parse('$_api/$id'));
    }
    return json;
  }

  Uri _media(String id) => Uri.parse('$_api/$id').replace(queryParameters: {'alt': 'media'});

  Future<void> _patch(String id, String json) => _drive.send(
    'PATCH',
    Uri.parse('$_upload/$id').replace(queryParameters: {'uploadType': 'media'}),
    body: json,
    type: 'application/json',
  );
}
