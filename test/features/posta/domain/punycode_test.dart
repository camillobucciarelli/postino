import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/domain/punycode.dart';

void main() {
  test('decodes the xn-- labels of a host, as RFC 3492 spells them', () {
    expect(decodeHost('xn--bcher-kva.example'), 'bücher.example');
    expect(decodeHost('xn--mnchen-3ya.de'), 'münchen.de');
    expect(decodeHost('xn--wgv71a119e.jp'), '日本語.jp');
    expect(decodeHost('xn--r8jz45g.jp'), '例え.jp');
    expect(decodeHost('xn--e1afmkfd.xn--p1ai'), 'пример.рф', reason: 'every label');
    expect(decodeHost('XN--BCHER-KVA.example'), 'bücher.example', reason: 'whatever its case');
  });

  test('a label that does not decode, and a plain one, stay as they are', () {
    expect(decodeHost('xn--a!.example'), 'xn--a!.example', reason: 'not a punycode digit');
    expect(decodeHost('xn--9.example'), 'xn--9.example', reason: 'ends in the middle of a number');
    expect(decodeHost('mail.example.com'), 'mail.example.com');
  });

  test('the last code point of Unicode decodes, the one past it does not', () {
    expect(decodeHost('xn--dn32g'), String.fromCharCode(0x10ffff));
    expect(decodeHost('xn--en32g'), 'xn--en32g', reason: 'U+110000');
  });

  test('hasPunycode finds an xn-- label in any case', () {
    expect(hasPunycode('xn--bcher-kva.example'), isTrue);
    expect(hasPunycode('mail.XN--p1ai'), isTrue);
    expect(hasPunycode('mail.example'), isFalse);
  });
}
