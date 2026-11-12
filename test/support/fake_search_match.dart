import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/search_query.dart';

/// Whether [m] matches [q] the way a Provider's search would (#207), simplified: every text field is a
/// case-insensitive substring, the dates are the user's local days. [attached] says whether it has attachments.
bool fakeSearchMatches(Message m, SearchQuery q, {bool attached = false}) {
  bool has(Iterable<String?> fields, String? text) {
    if (text == null) return true;
    final all = fields.nonNulls.join(' ').toLowerCase();
    return text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(all.contains);
  }

  final anywhere = [m.subject, m.from, m.fromName, ...m.to, ...m.cc, m.snippet];
  final after = q.after;
  final before = q.before;
  return q.terms.every((t) => has(anywhere, t)) &&
      (q.phrase == null || anywhere.nonNulls.join(' ').toLowerCase().contains(q.phrase!.toLowerCase())) &&
      has([m.from, m.fromName], q.from) &&
      has([...m.to, ...m.cc], q.to) &&
      has([m.subject], q.subject) &&
      (after == null || !m.date.isBefore(DateTime(after.year, after.month, after.day))) &&
      (before == null || m.date.isBefore(DateTime(before.year, before.month, before.day + 1))) &&
      (q.unread != true || !m.isRead) &&
      (q.starred != true || m.isStarred) &&
      (q.hasAttachment != true || attached);
}
