// The file of the Impostazioni di Postino (#124, ADR 0016): codec, schema versions, last-write-wins.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_document.dart';
import 'package:postino/core/domain/settings_entry.dart';

SettingsEntry _e(String key, String? value, int at, [String device = 'A']) =>
    SettingsEntry(key: key, value: value, updatedAt: at, deviceId: device, deleted: value == null);

SettingsDocument _decode(String json) => switch (decodeSettings(json)) {
  Ok(:final value) => value,
  Err(:final failure) => fail('$failure'),
};

void main() {
  group('codec', () {
    test('round trips voci and tombstones, values as JSON in the file', () {
      final entries = [_e('auto_labels/a1', '{"L1":{"automatic":true}}', 5), _e('auto_labels/a2', null, 7, 'B')];
      final json = encodeSettings(entries);
      final file = jsonDecode(json) as Map<String, dynamic>;
      final entry = (file['entries'] as Map<String, dynamic>)['auto_labels/a1'] as Map<String, dynamic>;
      expect(entry['value'], {
        'L1': {'automatic': true},
      });
      final doc = _decode(json);
      expect(doc.schemaVersion, settingsSchemaVersion);
      expect(doc.writable, isTrue);
      expect(doc.entries.values, entries);
    });

    test('a newer schema is read, voci that decode, but is not writable', () {
      final doc = _decode(
        jsonEncode({
          'schemaVersion': settingsSchemaVersion + 1,
          'entries': {
            'auto_labels/a1': {'value': <String, Object>{}, 'updatedAt': 1, 'deviceId': 'Z', 'deleted': false},
            'broken': {'value': 3},
          },
        }),
      );
      expect(doc.writable, isFalse);
      expect(doc.entries.keys, ['auto_labels/a1']);
    });

    test('a v1 file is read through the migration chain, and the file written is v3 (ADR 0019)', () {
      expect(settingsSchemaVersion, 3);
      final doc = _decode(
        jsonEncode({
          'schemaVersion': 1,
          'entries': {
            'auto_labels/a1': {'value': <String, Object>{}, 'updatedAt': 1, 'deviceId': 'Z', 'deleted': false},
          },
        }),
      );
      expect(doc.writable, isTrue);
      expect(doc.entries.values, [_e('auto_labels/a1', '{}', 1, 'Z')]);
      expect((jsonDecode(encodeSettings(doc.entries.values)) as Map<String, dynamic>)['schemaVersion'], 3);
    });

    test('a v2 file, the last written in clear, reads as it is', () {
      expect(lastPlainSchemaVersion, 2);
      final doc = _decode(
        '{"schemaVersion":2,"entries":{"auto_labels/a1":{"value":{},"updatedAt":1,"deviceId":"Z","deleted":false}}}',
      );
      expect((doc.schemaVersion, doc.writable), (2, true));
      expect(doc.entries.values, [_e('auto_labels/a1', '{}', 1, 'Z')]);
    });

    test('voci with a prefix this Postino does not know are kept, to write back', () {
      final doc = _decode(
        '{"schemaVersion":2,"entries":{"themes/x":{"value":1,"updatedAt":1,"deviceId":"Z","deleted":false}}}',
      );
      expect(doc.entries.keys, ['themes/x']);
      expect(encodeSettings(doc.entries.values), contains('themes/x'));
    });

    test('what is not a settings document fails, so it is never overwritten', () {
      expect(decodeSettings('nope'), isA<Err<SettingsDocument>>());
      expect(decodeSettings('{"entries":{}}'), isA<Err<SettingsDocument>>());
    });

    test('a file without an entries map fails instead of reading as empty and being overwritten', () {
      expect(decodeSettings('{"schemaVersion":1}'), isA<Err<SettingsDocument>>());
      expect(decodeSettings('{"schemaVersion":1,"entries":[]}'), isA<Err<SettingsDocument>>());
    });

    test('a schemaVersion below 1 fails, never a RangeError', () {
      expect(decodeSettings('{"schemaVersion":0,"entries":{}}'), isA<Err<SettingsDocument>>());
      expect(decodeSettings('{"schemaVersion":-3,"entries":{}}'), isA<Err<SettingsDocument>>());
    });
  });
}
