import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../attachment_crypto.dart';

/// The prefix of the codice di abbinamento: the version of its format (ADR 0019).
const _codePrefix = 'P1';
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const _length = 32;

/// The Chiave di sincronizzazione (ADR 0019): 32 random bytes that seal the file of the Impostazioni on Drive. It
/// never goes to Drive, the database nor the logs, so it never prints.
class SyncKey._(final Uint8List _bytes) {
  /// A new random key, from `Random.secure()`.
  factory SyncKey.random() => SyncKey._(randomBytes(_length));

  /// The key [encode] saved; throws on anything else.
  factory SyncKey.decode(String saved) {
    final bytes = base64Decode(saved);
    if (bytes.length != _length) throw const FormatException('not a sync key');
    return SyncKey._(bytes);
  }

  /// The key a codice di abbinamento carries: `P1` and the key in Base32 (RFC 4648, no padding), in any case, with
  /// spaces and dashes between the groups. Null when it is not one: another prefix, length or character.
  static SyncKey? fromCode(String code) {
    final text = code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (!text.startsWith(_codePrefix)) return null;
    final bytes = _fromBase32(text.substring(_codePrefix.length));
    return bytes?.length == _length ? SyncKey._(bytes!) : null;
  }

  /// The AES-256 key.
  Uint8List get bytes => _bytes;

  /// The `keyId` of the file: the first 8 bytes of SHA-256 of a fixed label and the key, as 16 hex digits. Derived
  /// from the key, so never kept apart; with 256 random bits it tells nothing about it.
  String get id => hex(sha256.convert([...utf8.encode('postino-sync-key-id'), ..._bytes]).bytes.sublist(0, 8));

  /// The codice di abbinamento, without groups: what the QR encodes.
  String get code => '$_codePrefix${_toBase32(_bytes)}';

  /// The key as the keychain keeps it.
  String encode() => base64Encode(_bytes);

  /// Neutral: the key never reaches a log.
  @override
  String toString() => 'SyncKey(…)';
}

String _toBase32(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_alphabet[(buffer >> bits) & 31]);
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

/// Null on a character outside the alphabet, or trailing bits that are not zero (not the encoding of any key).
Uint8List? _fromBase32(String text) {
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final ch in text.split('')) {
    final v = _alphabet.indexOf(ch);
    if (v < 0) return null;
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((buffer >> bits) & 0xff);
    }
    buffer &= (1 << bits) - 1;
  }
  return buffer == 0 ? Uint8List.fromList(out) : null;
}
