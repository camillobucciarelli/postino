import 'package:postino/core/domain/message.dart';

final _token = RegExp(r'\{([^}]*)\}|(?:(\w+):)?"([^"]*)"|(\w+):(\S+)');

/// Whether [m] matches the `q` that `gmailQuery` writes, as Gmail would read it, simplified: a quoted value is a
/// case-insensitive substring of its field, `{…}` is OR, `after:`/`before:` are epoch seconds. [attached] says
/// whether it has attachments.
bool gmailQueryMatches(Message m, String q, {bool attached = false}) =>
    _token.allMatches(q).every((t) => _matches(m, t, attached));

bool _matches(Message m, RegExpMatch t, bool attached) {
  if (t[1] case final any?) return _token.allMatches(any).any((i) => _matches(m, i, attached));
  bool has(Iterable<String?> fields) => fields.nonNulls.join(' ').toLowerCase().contains(t[3]!.toLowerCase());
  if (t[3] != null) {
    return switch (t[2]) {
      null => has([m.subject, m.from, m.fromName, ...m.to, ...m.cc, m.snippet]),
      'from' => has([m.from, m.fromName]),
      'to' => has(m.to),
      'cc' => has(m.cc),
      'subject' => has([m.subject]),
      final op => throw UnsupportedError('operator $op'),
    };
  }
  final seconds = m.date.millisecondsSinceEpoch ~/ 1000;
  return switch ((t[4], t[5])) {
    ('after', final s) => seconds >= int.parse(s!),
    ('before', final s) => seconds < int.parse(s!),
    ('is', 'unread') => !m.isRead,
    ('is', 'starred') => m.isStarred,
    ('has', 'attachment') => attached,
    final op => throw UnsupportedError('operator $op'),
  };
}
