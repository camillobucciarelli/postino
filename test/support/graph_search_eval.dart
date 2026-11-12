import 'package:postino/core/domain/message.dart';

final _clause = RegExp(r'\(([^)]*)\)|(?:(\w+):)?"([^"]*)"|(\w+)(>=|<=|:)([\w-]+)');

/// Whether [m] matches the `$search` that `graphKql` writes, as Graph would read it, simplified: the outer quotes
/// gone and `\"` unescaped, a quoted value matches whole words of its field (free: sender, subject and body), or
/// their beginnings when it ends in `*`; `(…)` is OR, the days of `received` are UTC. [attached] says whether it
/// has attachments.
bool graphSearchMatches(Message m, String search, {bool attached = false}) {
  final kql = search.substring(1, search.length - 1).replaceAll(r'\"', '"');
  return _clause.allMatches(kql).every((c) => _matches(m, c, attached));
}

/// Whether [m] matches the `$filter` that `graphStateFilter` writes.
bool graphFilterMatches(Message m, String filter) =>
    (!filter.contains('isRead eq false') || !m.isRead) && (!filter.contains("'flagged'") || m.isStarred);

bool _matches(Message m, RegExpMatch c, bool attached) {
  if (c[1] case final any?) return _clause.allMatches(any).any((i) => _matches(m, i, attached));
  bool has(Iterable<String?> fields) {
    final v = c[3]!;
    final prefix = v.endsWith('*');
    final word = RegExp.escape(prefix ? v.substring(0, v.length - 1) : v);
    return RegExp(
      '(^|[^\\p{L}\\p{N}])$word${prefix ? '' : r'($|[^\p{L}\p{N}])'}',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(fields.nonNulls.join(' '));
  }

  if (c[3] != null) {
    return switch (c[2]) {
      null => has([m.subject, m.from, m.fromName, m.snippet]),
      'from' => has([m.from, m.fromName]),
      'to' => has(m.to),
      'cc' => has(m.cc),
      'subject' => has([m.subject]),
      final op => throw UnsupportedError('property $op'),
    };
  }
  final day = DateTime.utc(m.date.year, m.date.month, m.date.day);
  return switch ((c[4], c[5], c[6])) {
    ('hasAttachments', ':', 'true') => attached,
    ('received', '>=', final d) => !day.isBefore(DateTime.parse('${d}T00:00:00Z')),
    ('received', '<=', final d) => !day.isAfter(DateTime.parse('${d}T00:00:00Z')),
    final op => throw UnsupportedError('clause $op'),
  };
}
