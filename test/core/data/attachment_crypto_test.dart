import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/attachment_crypto.dart';

void main() {
  final keys = attachmentKeysFromHex(newAttachmentKeyHex());
  final plain = Uint8List.fromList(List.generate(100, (i) => i));

  test('the key hex parses into two 32-byte halves', () {
    final k = attachmentKeysFromHex('${'01' * 32}${'ff' * 32}');
    expect(k.enc, everyElement(1));
    expect(k.mac, everyElement(255));
    expect(k.enc.length + k.mac.length, 64);
  });

  test('encrypt then decrypt returns the plain bytes', () {
    final sealed = encryptAttachment(plain, keys);
    expect(sealed.length, plain.length + attachmentOverhead);
    expect(decryptAttachment(sealed, keys), plain);
  });

  test('a tampered byte is rejected', () {
    final sealed = encryptAttachment(plain, keys);
    sealed[20] ^= 1;
    expect(decryptAttachment(sealed, keys), isNull);
  });
}
