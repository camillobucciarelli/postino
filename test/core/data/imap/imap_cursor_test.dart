// The opaque IMAP cursor: UIDVALIDITY, UIDNEXT, HIGHESTMODSEQ and the known UIDs per folder.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_cursor.dart';

void main() {
  test('round trip, the UID sets as ranges', () {
    const c = ImapCursor({
      'INBOX': FolderState(
        uidValidity: 7,
        uidNext: 45,
        modSeq: 900,
        uids: {1, 2, 3, 4, 10, 44},
        seen: {1, 2},
        flagged: {44},
      ),
      'Viaggi/2026': FolderState(uidValidity: 9, uidNext: 1),
    });
    final encoded = c.encode();
    expect(encoded, contains('"1:4,10,44"'));
    final back = ImapCursor.decode(encoded)!;
    final inbox = back.folders['INBOX']!;
    expect((inbox.uidValidity, inbox.uidNext, inbox.modSeq), (7, 45, 900));
    expect(inbox.uids, {1, 2, 3, 4, 10, 44});
    expect(inbox.seen, {1, 2});
    expect(inbox.flagged, {44});
    final viaggi = back.folders['Viaggi/2026']!;
    expect(viaggi.modSeq, isNull);
    expect(viaggi.uids, isEmpty);
  });

  test('a cursor this adapter did not write is unreadable', () {
    for (final s in ['0', '', 'abc', '{"v":2,"f":{}}', '{"v":1,"f":{"INBOX":{"uv":"x"}}}', '[]']) {
      expect(ImapCursor.decode(s), isNull, reason: s);
    }
  });
}
