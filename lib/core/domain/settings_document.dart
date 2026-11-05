import 'dart:convert';

import 'result.dart';
import 'settings_entry.dart';

/// The file of the Impostazioni di Postino (ADR 0016):
/// `{"schemaVersion":1,"entries":{"<key>":{"value":<JSON>|null,"updatedAt":ms,"deviceId":"…","deleted":bool}}}`.
class const SettingsDocument({
  /// La versione dello schema con cui il file è stato scritto.
  required final int schemaVersion,

  /// Le voci che si sono decodificate, per chiave.
  required final Map<String, SettingsEntry> entries,
}) {
  /// Crea il documento.
  this;

  /// False for a file from a newer Postino: it is read, but never overwritten.
  bool get writable => schemaVersion <= settingsSchemaVersion;
}

/// The migrations, forward only and applied on read: the one at index i takes a document from v(i+1) to v(i+2).
/// A new schema version is one function appended here.
final List<Map<String, Object?> Function(Map<String, Object?>)> _migrations = [];

/// La versione dello schema che questo Postino scrive.
int get settingsSchemaVersion => _migrations.length + 1;

/// Reads the file, migrated to [settingsSchemaVersion]. A malformed voce is skipped; a file that is not a
/// settings document at all (no `entries` map, a `schemaVersion` below 1) is an [UnexpectedFailure], so the
/// caller never overwrites what it cannot read.
Result<SettingsDocument> decodeSettings(String json) {
  Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    return Err(UnexpectedFailure(e));
  }
  if (root is! Map<String, Object?> || root['schemaVersion'] is! int || (root['schemaVersion']! as int) < 1) {
    return const Err(UnexpectedFailure('not a settings document'));
  }
  final version = root['schemaVersion']! as int;
  var doc = root;
  for (var v = version; v < settingsSchemaVersion; v++) {
    doc = _migrations[v - 1](doc);
  }
  // Without the voci it is not a settings document: read as empty, the next write would wipe it.
  if (doc['entries'] case final Map<String, Object?> raw) {
    return Ok(
      SettingsDocument(
        schemaVersion: version,
        entries: {for (final MapEntry(:key, :value) in raw.entries) key: ?_entry(key, value)},
      ),
    );
  }
  return const Err(UnexpectedFailure('settings document without entries'));
}

/// The file for [entries] at [settingsSchemaVersion].
String encodeSettings(Iterable<SettingsEntry> entries) => jsonEncode({
  'schemaVersion': settingsSchemaVersion,
  'entries': {
    for (final e in entries)
      e.key: {
        'value': e.value == null ? null : jsonDecode(e.value!),
        'updatedAt': e.updatedAt,
        'deviceId': e.deviceId,
        'deleted': e.deleted,
      },
  },
});

SettingsEntry? _entry(String key, Object? json) {
  if (json is! Map<String, Object?>) return null;
  final (updatedAt, deviceId, deleted) = (json['updatedAt'], json['deviceId'], json['deleted'] == true);
  if (updatedAt is! int || deviceId is! String) return null;
  final value = json['value'];
  if (!deleted && value == null) return null;
  return SettingsEntry(
    key: key,
    value: deleted ? null : jsonEncode(value),
    updatedAt: updatedAt,
    deviceId: deviceId,
    deleted: deleted,
  );
}
