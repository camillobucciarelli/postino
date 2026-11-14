import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException, ReturnOption;

import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/provider_search_page.dart';
import '../../domain/result.dart';
import '../../domain/search_query.dart';
import 'imap_failure.dart';
import 'imap_folder_sync.dart' show fetchMessages;
import 'imap_folders.dart';
import 'imap_message_parser.dart';
import 'imap_search.dart';
import 'imap_session.dart';
import 'imap_threads.dart' show ThreadInput;

/// Where a folder's search stands: the UIDs below `before` are still to come (UIDVALIDITY `uidValidity` when it was
/// read; null before the first page).
typedef _Resume = ({String path, int? uidValidity, int? before});

/// What one folder gave: its messages, where to go on if it has more, whether it timed out.
typedef _Done = ({List<ImapParsed> messages, _Resume? more, bool timedOut});

/// One page of the search on the Provider (#208) over the user's folders, never Cestino nor Spam.
/// A folder gives at most [_page] results per page, the newest UIDs first (PARTIAL where announced, else all the UIDs
/// and the first of them); the pages are merged by date, and the page token holds, for each folder with more, the
/// UID to go on from. A folder that times out or refuses the SEARCH is left out of this page, the others answer.
class ImapFolderSearch(
  final ImapSession _session,

  /// What the budget is measured on: a [Stopwatch] of its own would run on real time in the widget tests, where the
  /// timeouts run on fake time (#265).
  final Clock _clock,

  /// The messages threaded as the syncs do (`ImapProvider._thread`), over the headers `_related` looked up.
  final List<Message> Function(List<ImapParsed> messages, List<ThreadInput> related) _thread,
  final Future<List<ThreadInput>> Function(ImapClient c, List<ImapFolder> folders, List<ImapParsed> messages)
  _related, {

  /// How long one folder may take (a server without a full-text index scans every body).
  final Duration timeout = const Duration(seconds: 6),
}) {
  static const _page = 50;

  /// All the folders together, under the 15 s the core waits for a page: what is left is the next page's.
  static const _budget = Duration(seconds: 13);

  /// The least the parents' lookup gets when the folders used the budget up.
  static const _minLookup = Duration(seconds: 1);

  /// The folders searched: Cestino, Spam and Bozze never.
  static List<ImapFolder> searchable(List<ImapFolder> folders) => [
    for (final f in folders)
      if (const {FolderRole.inbox, FolderRole.sent, FolderRole.archive, FolderRole.user}.contains(f.role)) f,
  ];

  /// One page over the folders `list` gives. Every phase (the LIST, each folder, the lookup of the parents) runs on
  /// the session through [_within], inside the 13 s budget: one that times out has its connection dropped and the next
  /// opens a new one, with the results already collected kept.
  Future<ProviderSearchPage> page(
    Future<List<ImapFolder>> Function(ImapClient c) list,
    SearchQuery query,
    String? token,
    Set<String> stored,
  ) async {
    final elapsed = _clock.stopwatch();
    final all = await _within<List<ImapFolder>>(_budget, list);
    final resumes = _decode(token);
    final pending = <_Resume>[
      for (final f in searchable(all))
        if (resumes == null) (path: f.path, uidValidity: null, before: null) else ?resumes[f.path],
    ];
    final folders = {for (final f in all) f.path: f};
    final found = <ImapParsed>[];
    final next = <_Resume>[];
    final slow = <String>{};
    var answered = 0;
    for (final (i, r) in pending.indexed) {
      final left = _budget - elapsed();
      if (left <= Duration.zero) {
        next.addAll(pending.skip(i));
        break;
      }
      final limit = left < timeout ? left : timeout;
      final done = await _folderWithin(limit, folders[r.path]!, r, query);
      if (done == null) continue;
      if (done.timedOut) {
        slow.add(r.path);
        continue;
      }
      found.addAll([
        for (final p in done.messages)
          if (imapInDays(query, p.message.date)) p,
      ]);
      if (done.more != null) next.add(done.more!);
      answered++;
    }
    // Nobody answered in time: not "no results".
    if (answered == 0 && slow.isNotEmpty) throw const ImapFailed(OfflineFailure());
    // Never in Cestino nor Spam, the lookups of the replies' parents neither; nor in a folder that just timed out, and
    // within what is left of the budget.
    final lookup = [
      for (final f in searchable(all))
        if (!slow.contains(f.path)) f,
    ];
    final rest = _budget - elapsed();
    final related = await _within<List<ThreadInput>>(
      rest < _minLookup ? _minLookup : rest,
      (c) => _related(c, lookup, found),
      onTimeout: () => const <ThreadInput>[],
    );
    final threaded = _thread(found, related)..sort((a, b) => b.date.compareTo(a.date));
    return ProviderSearchPage(
      messages: [
        for (final m in threaded)
          if (!stored.contains(m.id)) m,
      ],
      conversationIds: {for (final m in threaded) m.conversationId},
      nextPageToken: next.isEmpty ? null : _encode(next),
    );
  }

  /// [body] on the session within [limit], the opening of a new connection included: the one place every phase of a
  /// page goes through. What takes longer drops the connection (the server is still busy with it, nothing after it
  /// would be answered) and is [onTimeout], or, without one, an [OfflineFailure].
  Future<T> _within<T>(Duration limit, Future<T> Function(ImapClient c) body, {T Function()? onTimeout}) async {
    ({T? value, bool slow}) done;
    try {
      // The timeout is a value, not a throw: the session would open a new connection and run [body] again.
      done = await _session.run((c) async {
        try {
          return (value: await body(c).timeout(limit), slow: false);
        } on Object catch (e) {
          if (!_isTimeout(e)) rethrow;
          await _drop(c);
          return (value: null, slow: true);
        }
      }, setup: limit);
    } on ImapFailed catch (e) {
      // A connection that did not open in time, or at all.
      if (e.failure is! OfflineFailure) rethrow;
      done = (value: null, slow: true);
    }
    if (!done.slow) return done.value as T;
    return onTimeout != null ? onTimeout() : throw const ImapFailed(OfflineFailure());
  }

  /// [_folder] within [limit] (SELECT, SEARCH and FETCH together); null when the folder is gone or refuses the SEARCH:
  /// the others still answer.
  // ponytail: any refusal (a server without CHARSET UTF-8, `[LIMIT]`) leaves the folder out silently, never a RateLimitFailure.
  Future<_Done?> _folderWithin(Duration limit, ImapFolder f, _Resume r, SearchQuery query) async {
    try {
      return await _within<_Done?>(limit, (c) async {
        try {
          return await _folder(c, f, r, query, limit);
        } on ImapException catch (e) {
          if (!c.isConnected || _isTimeout(e)) rethrow;
          return null;
        }
      });
    } on ImapFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      if (e.failure is OfflineFailure) return (messages: const <ImapParsed>[], more: null, timedOut: true);
      rethrow;
    }
  }

  static bool _isTimeout(Object e) => e is TimeoutException || (e is ImapException && e.message == 'timeout');

  /// The server is still busy with the command that timed out: nothing after it would be answered on this connection.
  static Future<void> _drop(ImapClient c) async {
    try {
      await c.disconnect().timeout(const Duration(seconds: 5));
    } on Object {
      // Already gone.
    }
  }

  /// The next [_page] results of [folder] after [resume], with where to go on if there are more. The headers of the
  /// results already stored come too: the Conversazione of a message is known only from them.
  Future<_Done> _folder(ImapClient c, ImapFolder folder, _Resume resume, SearchQuery query, Duration timeout) async {
    final box = await selectFolder(c, folder.path, condstore: _session.condstore);
    final uidValidity = box.uidValidity ?? 0;
    // The UIDs mean something else now: that folder's pages after the first are not ours to follow.
    if (resume.uidValidity != null && resume.uidValidity != uidValidity) {
      return (messages: const <ImapParsed>[], more: null, timedOut: false);
    }
    final r = await c.uidSearchMessages(
      searchCriteria: imapSearchCriteria(query, below: resume.before)!,
      // One more than a page tells whether there is another.
      returnOptions: _session.partial ? [ReturnOption.partial('-1:-${_page + 1}')] : null,
      responseTimeout: timeout,
    );
    final sequence = r.matchingSequence;
    final uids = (sequence == null || sequence.isEmpty ? <int>[] : sequence.toList())..sort((a, b) => b - a);
    final taken = uids.take(_page).toList();
    return (
      messages: await fetchMessages(c, folder, uidValidity, taken),
      more: uids.length > _page ? (path: folder.path, uidValidity: uidValidity, before: taken.last) : null,
      timedOut: false,
    );
  }

  static String _encode(List<_Resume> resumes) => jsonEncode([
    for (final r in resumes) [r.path, r.uidValidity, r.before],
  ]);

  /// The folders to go on with, by path; null for the first page. A token that is not ours is [NotFoundFailure].
  static Map<String, _Resume>? _decode(String? token) {
    if (token == null) return null;
    try {
      return {
        for (final e in jsonDecode(token) as List)
          (e as List)[0] as String: (path: e[0] as String, uidValidity: e[1] as int?, before: e[2] as int?),
      };
    } on Object {
      throw const ImapFailed(NotFoundFailure());
    }
  }
}
