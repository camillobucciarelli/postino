// Addresses of the From, To and Cc headers (#47): display names, quoted and RFC 2047 encoded.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mailbox.dart';

void main() {
  test('a name and an address', () {
    expect(parseMailbox('Ada Okafor <ada@example.com>'), (name: 'Ada Okafor', address: 'ada@example.com'));
  });

  test('a bare address, or one in angle brackets, has no name', () {
    expect(parseMailbox(' ada@example.com '), (name: null, address: 'ada@example.com'));
    expect(parseMailbox('<ada@example.com>'), (name: null, address: 'ada@example.com'));
  });

  test('a quoted name loses its quotes and escapes', () {
    expect(parseMailbox(r'"Okafor, Ada \"Lex\"" <ada@example.com>').name, 'Okafor, Ada "Lex"');
  });

  test('RFC 2047 names: Base64 and Q, UTF-8 and Latin-1, adjacent words joined', () {
    expect(parseMailbox('=?UTF-8?B?QWRhIFJvc3NpIOKAkyBTdHVkaW8=?= <ada@x.it>').name, 'Ada Rossi – Studio');
    expect(parseMailbox('=?ISO-8859-1?Q?Nicol=F2_Neri?= <n@x.it>').name, 'Nicolò Neri');
    expect(parseMailbox('"=?utf-8?q?Caf=C3=A9?= =?utf-8?q?_Bar?=" <c@x.it>').name, 'Café Bar');
    expect(decodeWords('=?UTF-8?B?not base64!?='), '=?UTF-8?B?not base64!?=');
  });

  test('a list splits on commas outside quotes and angle brackets', () {
    expect(parseMailboxes('"Rossi, Carla" <carla@x.it>, bruno@x.it,, <"strano,"@x.it>'), [
      (name: 'Rossi, Carla', address: 'carla@x.it'),
      (name: null, address: 'bruno@x.it'),
      (name: null, address: '"strano,"@x.it'),
    ]);
  });

  test('formatMailbox writes the name before the address, if any', () {
    expect(formatMailbox((name: 'Ada', address: 'a@x.it')), 'Ada <a@x.it>');
    expect(formatMailbox((name: null, address: 'a@x.it')), 'a@x.it');
  });

  test('a name with specials is quoted and survives the round trip', () {
    for (final name in ['Rossi, Carla', 'Ada "Ace" Okafor', r'Back\slash', 'A <b>']) {
      final m = (name: name, address: 'a@x.it');
      expect(parseMailboxes(formatMailbox(m)), [m], reason: name);
    }
    expect(formatMailbox((name: 'Rossi, Carla', address: 'c@x.it')), '"Rossi, Carla" <c@x.it>');
  });
}
