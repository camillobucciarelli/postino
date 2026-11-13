// The opaque cursor of a Microsoft Account.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/microsoft/graph_cursor.dart';

void main() {
  test('it reads back what it wrote', () {
    const cursor = GraphCursor('https://graph.microsoft.com/v1.0/me/mailFolders/delta?\$deltatoken=F', {
      'f-inbox': (label: 'INBOX', link: 'https://graph.microsoft.com/v1.0/me/mailFolders/f-inbox/messages/delta'),
    });
    final back = GraphCursor.decode(cursor.encode())!;
    expect(back.folders, cursor.folders);
    expect(back.messages, cursor.messages);
  });

  test('another Provider\'s cursor, or a corrupted one, is not one', () {
    for (final s in ['4242', '', '{"folders": 1}', '{"folders": "x", "messages": {"a": 1}}']) {
      expect(GraphCursor.decode(s), isNull, reason: s);
    }
  });
}
