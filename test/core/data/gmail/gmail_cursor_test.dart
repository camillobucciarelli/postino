import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/gmail/gmail_cursor.dart';

void main() {
  final now = DateTime.utc(2026, 11, 13, 9);

  test('a message failing again and again waits at most an hour, also across encode and decode', () {
    var c = const GmailCursor('1');
    for (var i = 0; i < 12; i++) {
      c = GmailCursor.decode(c.after('1', settled: const [], failed: const ['x'], now: now).encode());
    }
    expect(c.retries['x']!.tries, 12);
    expect(c.retries['x']!.due, now.add(const Duration(hours: 1)));
  });

  test('a cursor that is not ours is taken as a historyId, which Gmail refuses: the initial sync redoes it', () {
    expect(GmailCursor.decode('{not json').historyId, '{not json');
    expect(GmailCursor.decode('{not json').retries, isEmpty);
  });
}
