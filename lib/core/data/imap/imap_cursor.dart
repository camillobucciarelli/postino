import 'dart:convert';

import 'package:enough_mail/enough_mail.dart' show MessageSequence;

/// What the last sync saw of one folder: UIDVALIDITY, UIDNEXT, HIGHESTMODSEQ (CONDSTORE only) and the UIDs it
/// knows, with those read (`\Seen`) and with the Stella (`\Flagged`): the fallback without CONDSTORE compares the
/// flags against them, and every path tells a deletion by a known UID gone.
class const FolderState({
  required final int uidValidity,
  required final int uidNext,
  final int? modSeq,
  final Set<int> uids = const {},
  final Set<int> seen = const {},
  final Set<int> flagged = const {},
});

/// The opaque cursor of an IMAP Account: one [FolderState] per synced folder, by path. JSON, the UID sets as
/// IMAP sequence sets (`1:40,42`), which keeps a 90-day window small.
class const ImapCursor(final Map<String, FolderState> folders) {
  String encode() => jsonEncode({
    'v': 1,
    'f': {
      for (final MapEntry(key: path, value: s) in folders.entries)
        path: {
          'uv': s.uidValidity,
          'n': s.uidNext,
          'm': ?s.modSeq,
          'u': _set(s.uids),
          's': _set(s.seen),
          'f': _set(s.flagged),
        },
    },
  });

  /// Null for a cursor this adapter did not write (or a later version).
  static ImapCursor? decode(String cursor) {
    try {
      final j = jsonDecode(cursor) as Map<String, dynamic>;
      if (j['v'] != 1) return null;
      return ImapCursor({
        for (final MapEntry(key: path, value: raw) in (j['f'] as Map<String, dynamic>).entries)
          path: switch (raw as Map<String, dynamic>) {
            final s => FolderState(
              uidValidity: s['uv'] as int,
              uidNext: s['n'] as int,
              modSeq: s['m'] as int?,
              uids: _parse(s['u'] as String),
              seen: _parse(s['s'] as String),
              flagged: _parse(s['f'] as String),
            ),
          },
      });
    } on Object {
      return null;
    }
  }

  static String _set(Set<int> uids) => uids.isEmpty ? '' : (MessageSequence.fromIds(uids.toList()..sort())).toString();

  static Set<int> _parse(String s) => s.isEmpty ? {} : MessageSequence.parse(s).toList().toSet();
}
