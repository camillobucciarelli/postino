// The envelope of the file of the Impostazioni on Drive (ADR 0019): AES-256-GCM, header authenticated.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/settings_envelope.dart';
import 'package:postino/core/data/sync/sync_key.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_document.dart';

const _doc = '{"schemaVersion":3,"entries":{"auto_labels/a1":{"value":{"L1":{}},"updatedAt":1,"deviceId":"A"}}}';

Map<String, Object?> _fields(String sealed) => jsonDecode(sealed) as Map<String, Object?>;

String _with(String sealed, String field, Object? value) => jsonEncode({..._fields(sealed), field: value});

/// [b64] with one bit of its byte [at] flipped.
String _flip(String b64, int at) {
  final bytes = base64Decode(b64);
  bytes[at] ^= 1;
  return base64Encode(bytes);
}

void main() {
  final key = SyncKey.random();

  test('sealed then opened with the same key gives the document back', () {
    final sealed = sealSettings(_doc, key);
    expect(openSettings(sealed, key), isA<OpenedCopy>().having((c) => c.json, 'json', _doc));
  });

  test('only the header is in clear: version, keyId, nonce and ciphertext', () {
    final fields = _fields(sealSettings(_doc, key));
    expect(fields.keys, unorderedEquals(['postinoEncrypted', 'keyId', 'nonce', 'ciphertext']));
    expect(fields['postinoEncrypted'], 1);
    expect(fields['keyId'], key.id);
    expect(base64Decode(fields['nonce']! as String), hasLength(12));
    expect(jsonEncode(fields), isNot(contains('auto_labels')));
  });

  test('a fresh nonce at every write: the same document seals differently', () {
    final a = _fields(sealSettings(_doc, key));
    final b = _fields(sealSettings(_doc, key));
    expect(a['nonce'], isNot(b['nonce']));
    expect(a['ciphertext'], isNot(b['ciphertext']));
  });

  test('a ciphertext or a nonce changed by one bit is refused', () {
    final sealed = sealSettings(_doc, key);
    final c = _fields(sealed)['ciphertext']! as String;
    for (final at in [0, base64Decode(c).length - 1]) {
      expect(openSettings(_with(sealed, 'ciphertext', _flip(c, at)), key), isA<UnreadableCopy>());
    }
    final n = _fields(sealed)['nonce']! as String;
    expect(openSettings(_with(sealed, 'nonce', _flip(n, 0)), key), isA<UnreadableCopy>());
  });

  test('the keyId is authenticated: another key\'s ciphertext under this keyId fails the tag', () {
    final other = SyncKey.random();
    final forged = _with(sealSettings(_doc, other), 'keyId', key.id);
    expect(openSettings(forged, key), isA<UnreadableCopy>());
    // And a keyId changed to another value is a file this key does not open.
    expect(openSettings(_with(sealSettings(_doc, key), 'keyId', other.id), key), isA<LockedCopy>());
  });

  test('a version changed or newer is refused: never read as the version this Postino knows', () {
    final sealed = sealSettings(_doc, key);
    expect(
      openSettings(_with(sealed, 'postinoEncrypted', 2), key),
      isA<UnreadableCopy>().having((c) => c.newer, 'newer', isTrue),
    );
    for (final v in [0, '1', null, 1.5]) {
      expect(
        openSettings(_with(sealed, 'postinoEncrypted', v), key),
        isA<UnreadableCopy>().having((c) => c.newer, 'newer', isFalse),
        reason: '$v',
      );
    }
  });

  test('another key, or none, does not open it', () {
    final sealed = sealSettings(_doc, key);
    expect(openSettings(sealed, SyncKey.random()), isA<LockedCopy>());
    expect(openSettings(sealed, null), isA<LockedCopy>());
  });

  test('a file in clear is told apart; what is not an envelope nor JSON is unreadable', () {
    expect(openSettings(_doc, key), isA<PlainCopy>().having((c) => c.json, 'json', _doc));
    expect(openSettings('nope', key), isA<UnreadableCopy>());
    expect(openSettings('[1]', key), isA<UnreadableCopy>());
    final sealed = sealSettings(_doc, key);
    for (final (field, value) in [
      ('nonce', '!!'),
      ('nonce', base64Encode([1, 2])),
      ('ciphertext', 7),
      ('keyId', 3),
    ]) {
      expect(openSettings(_with(sealed, field, value), key), isA<UnreadableCopy>(), reason: field);
    }
  });

  test('an older Postino (≤1.5.x) reads the envelope as no settings document, so it never overwrites it', () {
    expect(decodeSettings(sealSettings(_doc, key)), isA<Err<SettingsDocument>>());
  });

  test('the reason of an unreadable copy never carries the key nor the content', () {
    final c = openSettings(_with(sealSettings(_doc, key), 'ciphertext', 'AAAA'), key) as UnreadableCopy;
    expect(c.reason, isNot(contains(key.encode())));
    expect(c.reason, isNot(contains('auto_labels')));
  });
}
