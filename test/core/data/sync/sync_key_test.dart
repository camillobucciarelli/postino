// The Chiave di sincronizzazione and its codice di abbinamento (ADR 0019).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/sync_key.dart';

void main() {
  test('a new key is 32 random bytes; its keyId is 16 hex digits derived from it', () {
    final a = SyncKey.random();
    final b = SyncKey.random();
    expect(a.bytes, hasLength(32));
    expect(a.bytes, isNot(b.bytes));
    expect(a.id, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(a.id, SyncKey.decode(a.encode()).id);
    expect(a.id, isNot(b.id));
  });

  test('the code is P1 and 52 Base32 characters, and gives back the same key', () {
    final key = SyncKey.random();
    expect(key.code, matches(RegExp(r'^P1[A-Z2-7]{52}$')));
    expect(SyncKey.fromCode(key.code)?.bytes, key.bytes);
  });

  test('a code typed by hand: lower case, in groups, with spaces, dashes or new lines', () {
    final key = SyncKey.random();
    final groups = [for (var i = 2; i < key.code.length; i += 4) key.code.substring(i, i + 4)];
    for (final typed in [
      key.code.toLowerCase(),
      'P1 ${groups.join(' ')}',
      'p1-${groups.join('-')}',
      ' P1\n${groups.join('\n')} ',
    ]) {
      expect(SyncKey.fromCode(typed)?.bytes, key.bytes, reason: typed);
    }
  });

  test('a malformed code is no key', () {
    final code = SyncKey.random().code;
    for (final bad in [
      '',
      'P1',
      code.substring(2),
      'P2${code.substring(2)}',
      code.substring(0, code.length - 1),
      '${code}A',
      '${code.substring(0, 10)}0${code.substring(11)}',
      '${code.substring(0, 10)}8${code.substring(11)}',
      // The last character carries 4 bits that must be zero.
      '${code.substring(0, code.length - 1)}B',
    ]) {
      expect(SyncKey.fromCode(bad), isNull, reason: bad);
    }
  });

  test('a saved key that is not one throws, without quoting it', () {
    expect(() => SyncKey.decode('AAAA'), throwsFormatException);
    expect(
      () => SyncKey.decode('SECRETxyz!'),
      throwsA(isA<FormatException>().having((e) => '$e', 'message', isNot(contains('SECRET')))),
    );
  });

  test('the key never prints', () {
    final key = SyncKey.random();
    expect('$key', isNot(contains(key.encode())));
    expect('$key', isNot(contains(key.code.substring(2))));
  });
}
