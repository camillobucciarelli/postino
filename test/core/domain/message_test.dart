import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';

void main() {
  test('newMessageId is <24 alphanumerics@domain of the address>', () {
    final id = newMessageId('ada@example.com');
    expect(id, matches(r'^<[A-Za-z0-9]{24}@example\.com>$'));
  });

  test('newMessageId falls back to postino.local without a domain', () {
    expect(newMessageId('ada'), endsWith('@postino.local>'));
  });

  test('newMessageId never repeats', () {
    final ids = {for (var i = 0; i < 1000; i++) newMessageId('a@b.it')};
    expect(ids, hasLength(1000));
  });
}
