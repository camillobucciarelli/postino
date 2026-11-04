import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// The two halves of the cache key (#34): AES-256 for the content, HMAC-SHA256 for the tag.
typedef AttachmentKeys = ({Uint8List enc, Uint8List mac});

const _ivLength = 16;
const _macLength = 32;

/// What encryption adds to a file: the IV in front, the tag at the end.
const attachmentOverhead = _ivLength + _macLength;

/// A fresh 64-byte key as hex: the encryption half, then the MAC half.
String newAttachmentKeyHex() => hex(randomBytes(64));

AttachmentKeys attachmentKeysFromHex(String hex) {
  final bytes = Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
  return (enc: bytes.sublist(0, 32), mac: bytes.sublist(32));
}

/// AES-256-CTR under a random IV, then HMAC-SHA256 over IV and ciphertext.
Uint8List encryptAttachment(Uint8List plain, AttachmentKeys keys) {
  final iv = randomBytes(_ivLength);
  final out = BytesBuilder(copy: false)
    ..add(iv)
    ..add(_ctr(keys.enc, iv, plain));
  final sealed = out.takeBytes();
  return (BytesBuilder(copy: false)
        ..add(sealed)
        ..add(Hmac(sha256, keys.mac).convert(sealed).bytes))
      .takeBytes();
}

/// Null when the MAC does not match (damaged, or from another key).
Uint8List? decryptAttachment(Uint8List sealed, AttachmentKeys keys) {
  if (sealed.length < attachmentOverhead) return null;
  final body = Uint8List.sublistView(sealed, 0, sealed.length - _macLength);
  final mac = Hmac(sha256, keys.mac).convert(body).bytes;
  final tag = Uint8List.sublistView(sealed, sealed.length - _macLength);
  // Constant time.
  var diff = 0;
  for (var i = 0; i < _macLength; i++) {
    diff |= mac[i] ^ tag[i];
  }
  if (diff != 0) return null;
  return _ctr(
    keys.enc,
    Uint8List.sublistView(body, 0, _ivLength),
    Uint8List.sublistView(body, _ivLength),
  );
}

Uint8List _ctr(Uint8List key, Uint8List iv, Uint8List data) => (CTRStreamCipher(
  AESEngine(),
)..init(true, ParametersWithIV(KeyParameter(key), iv))).process(data);

Uint8List randomBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
}

String hex(List<int> bytes) =>
    [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
