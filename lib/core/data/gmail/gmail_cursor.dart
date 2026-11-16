import 'dart:convert';
import 'dart:math';

/// A message the sync could not download yet: its failed tries and when the next one is due.
typedef GmailRetry = ({int tries, DateTime due});

/// The sync cursor of a Gmail Account, opaque to the core: the historyId the next sync starts from and the messages
/// a sync could not download (#252), retried by the next syncs with backoff. Saved with the batch in one transaction,
/// so a message left behind is never lost. Without retries it is the bare historyId, as before.
class const GmailCursor(final String historyId, [final Map<String, GmailRetry> retries = const {}]) {
  /// The wait after the first failed try, doubled by each next one up to [_maxWait].
  static const _firstWait = Duration(minutes: 1);
  static const _maxWait = Duration(minutes: 5);

  String encode() => retries.isEmpty
      ? historyId
      : jsonEncode({
          'historyId': historyId,
          'retries': {
            for (final MapEntry(:key, :value) in retries.entries)
              key: {'tries': value.tries, 'due': value.due.millisecondsSinceEpoch},
          },
        });

  /// A bare historyId or the JSON of [encode]; anything else is taken as a historyId, which Gmail refuses with a
  /// 404: the caller redoes the initial sync.
  static GmailCursor decode(String cursor) {
    if (!cursor.startsWith('{')) return GmailCursor(cursor);
    try {
      final j = jsonDecode(cursor) as Map<String, dynamic>;
      return GmailCursor(j['historyId'] as String, {
        for (final MapEntry(:key, :value) in (j['retries'] as Map<String, dynamic>).entries)
          key: (
            tries: (value as Map<String, dynamic>)['tries'] as int,
            due: DateTime.fromMillisecondsSinceEpoch(value['due'] as int, isUtc: true),
          ),
      });
    } on Object catch (_) {
      return GmailCursor(cursor);
    }
  }

  /// The messages whose retry is due at [now].
  Iterable<String> due(DateTime now) => [
    for (final MapEntry(:key, :value) in retries.entries)
      if (!value.due.isAfter(now)) key,
  ];

  /// The cursor at [next], after a sync that settled [settled] (downloaded, or gone) and failed [failed] at [now]:
  /// those failed again wait twice as long as the last time.
  GmailCursor after(
    String next, {
    required Iterable<String> settled,
    required Iterable<String> failed,
    required DateTime now,
  }) {
    final left = {...retries}..removeWhere((id, _) => settled.contains(id));
    for (final id in failed) {
      final tries = (left[id]?.tries ?? 0) + 1;
      final wait = _firstWait * pow(2, min(tries - 1, 10)).toInt();
      left[id] = (tries: tries, due: now.add(wait > _maxWait ? _maxWait : wait));
    }
    return GmailCursor(next, left);
  }
}
