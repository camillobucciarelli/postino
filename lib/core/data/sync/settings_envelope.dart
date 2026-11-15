import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../attachment_crypto.dart';
import 'sync_key.dart';

/// The version of the envelope this Postino writes and reads (`postinoEncrypted`).
const settingsEnvelopeVersion = 1;

const _nonceLength = 12;
const _tagBits = 128;

/// What a copy of the file is, opened with the device's key (ADR 0019).
sealed class const SettingsCopy() {
  /// Costruttore delle varianti.
  this;
}

/// A file in clear: an older Postino's, or one put there by whoever controls Drive.
final class const PlainCopy(
  /// The document as it is.
  final String json,
) extends SettingsCopy {
  /// Crea la copia in chiaro.
  this;
}

/// Sealed with the key: [json] is the document inside.
final class const OpenedCopy(
  /// The document inside the envelope.
  final String json,
) extends SettingsCopy {
  /// Crea la copia aperta.
  this;
}

/// Sealed with a key this device does not hold: another `keyId`, or none here.
final class const LockedCopy() extends SettingsCopy {
  /// Crea la copia chiusa.
  this;
}

/// Not a file this Postino can read, so never overwritten: a malformed envelope, a tag that does not match (damaged
/// or tampered), or a newer format ([newer]).
final class const UnreadableCopy(
  /// Why, for the error log: never the key nor the content.
  final String reason, {

  /// From a newer Postino: an update reads it.
  final bool newer = false,
}) extends SettingsCopy {
  /// Crea la copia illeggibile.
  this;
}

/// [json] in the envelope `{"postinoEncrypted":1,"keyId","nonce","ciphertext"}`: AES-256-GCM under a fresh random
/// 96-bit nonce, the header (version and `keyId`) authenticated as associated data.
String sealSettings(String json, SyncKey key) {
  final nonce = randomBytes(_nonceLength);
  final sealed = _gcm(
    encrypt: true,
    key: key,
    nonce: nonce,
    version: settingsEnvelopeVersion,
    keyId: key.id,
  ).process(Uint8List.fromList(utf8.encode(json)));
  return jsonEncode({
    'postinoEncrypted': settingsEnvelopeVersion,
    'keyId': key.id,
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(sealed),
  });
}

/// Opens a copy of the file with [key], null when this device has none.
SettingsCopy openSettings(String text, SyncKey? key) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    return const UnreadableCopy('not JSON');
  }
  if (root is! Map<String, Object?>) return const UnreadableCopy('not an object');
  if (!root.containsKey('postinoEncrypted')) return PlainCopy(text);
  final (version, keyId, nonce, ciphertext) = (
    root['postinoEncrypted'],
    root['keyId'],
    root['nonce'],
    root['ciphertext'],
  );
  if (version is! int || version < 1) return const UnreadableCopy('malformed envelope');
  if (version > settingsEnvelopeVersion) return const UnreadableCopy('envelope from a newer Postino', newer: true);
  if (keyId is! String || nonce is! String || ciphertext is! String) return const UnreadableCopy('malformed envelope');
  if (key == null || keyId != key.id) return const LockedCopy();
  try {
    final iv = base64Decode(nonce);
    if (iv.length != _nonceLength) return const UnreadableCopy('malformed envelope');
    final plain = _gcm(
      encrypt: false,
      key: key,
      nonce: iv,
      version: version,
      keyId: keyId,
    ).process(base64Decode(ciphertext));
    return OpenedCopy(utf8.decode(plain));
  } on FormatException {
    return const UnreadableCopy('malformed envelope');
  } on InvalidCipherTextException {
    return const UnreadableCopy('tag does not match: damaged or tampered');
  } on ArgumentError {
    return const UnreadableCopy('malformed envelope');
  }
}

GCMBlockCipher _gcm({
  required bool encrypt,
  required SyncKey key,
  required Uint8List nonce,
  required int version,
  required String keyId,
}) {
  // The header as associated data: changing the version or the keyId breaks the tag.
  final header = Uint8List.fromList(utf8.encode(jsonEncode({'postinoEncrypted': version, 'keyId': keyId})));
  return GCMBlockCipher(AESEngine())..init(encrypt, AEADParameters(KeyParameter(key.bytes), _tagBits, nonce, header));
}
