import 'package:enough_mail/enough_mail.dart' show ImapClient, Mailbox, MessageSequence, MimeMessage;

import 'imap_cursor.dart';
import 'imap_folders.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';

/// What syncing one folder gave: the messages new or changed, the ids gone, and what to remember of it.
typedef FolderDelta = ({List<ImapParsed> messages, List<String> removed, FolderState state});

/// A page of a folder's window, as soon as it is fetched.
typedef FolderPage = Future<void> Function(List<ImapParsed> page);

/// Syncs one folder on the session's connection: its window (the initial sync, a new folder, a new UIDVALIDITY)
/// or what changed since its [FolderState]. Bodies come only for the inbox (ADR 0003).
class ImapFolderSync(final ImapSession _session) {
  /// Messages per FETCH.
  static const _page = 50;

  /// The messages of [folder] whose INTERNALDATE is on or after [since], newest first, a page at a time.
  Future<FolderDelta> window(ImapClient c, ImapFolder folder, DateTime since, {FolderPage? onPage}) async {
    final box = await selectFolder(c, folder.path, condstore: _session.condstore);
    return _window(c, folder, box, since, onPage: onPage);
  }

  Future<FolderDelta> _window(
    ImapClient c,
    ImapFolder folder,
    Mailbox box,
    DateTime since, {
    FolderPage? onPage,
  }) async {
    final uidValidity = box.uidValidity ?? 0;
    final uids = (await search(c, 'SINCE ${imapDate(since)}'))..sort((a, b) => b - a);
    final messages = <ImapParsed>[];
    for (var i = 0; i < uids.length; i += _page) {
      final page = await _fetch(c, folder, uidValidity, uids.skip(i).take(_page).toList(), bodies: true);
      messages.addAll(page);
      await onPage?.call(page);
    }
    final fetched = {for (final m in messages) _uid(m)};
    return (
      messages: messages,
      removed: const <String>[],
      state: FolderState(
        uidValidity: uidValidity,
        uidNext: box.uidNext ?? (fetched.isEmpty ? 1 : fetched.reduce((a, b) => a > b ? a : b) + 1),
        modSeq: _session.condstore ? box.highestModSequence : null,
        uids: fetched,
        seen: {
          for (final m in messages)
            if (m.message.isRead) _uid(m),
        },
        flagged: {
          for (final m in messages)
            if (m.message.isStarred) _uid(m),
        },
      ),
    );
  }

  /// What changed in [folder] since [known]. A new UIDVALIDITY rebuilds it: the old ids all go, the window comes
  /// again. With CONDSTORE only the flags changed since the last HIGHESTMODSEQ come (with QRESYNC the UIDs
  /// expunged too, `VANISHED`); without it the flags of every known UID are compared with [known]. The [stored]
  /// messages of the folder (in the app's cache, maybe older than the window) are known UIDs from now on; every
  /// UID above the last UIDNEXT is new, whatever its date (a message moved here keeps its INTERNALDATE).
  Future<FolderDelta> changes(
    ImapClient c,
    ImapFolder folder,
    FolderState known,
    DateTime since, {
    Iterable<({String path, int uidValidity, int uid})> stored = const [],
  }) async {
    final box = await selectFolder(c, folder.path, condstore: _session.condstore);
    final uidValidity = box.uidValidity ?? 0;
    final was = FolderState(
      uidValidity: known.uidValidity,
      uidNext: known.uidNext,
      modSeq: known.modSeq,
      uids: {
        ...known.uids,
        for (final s in stored)
          if (s.uidValidity == known.uidValidity && s.uid < known.uidNext) s.uid,
      },
      seen: known.seen,
      flagged: known.flagged,
    );
    if (uidValidity != was.uidValidity) {
      final rebuilt = await _window(c, folder, box, since);
      return (
        messages: rebuilt.messages,
        removed: [for (final u in was.uids) imapMessageId(folder.path, was.uidValidity, u)],
        state: rebuilt.state,
      );
    }
    final modSeq = _session.condstore ? box.highestModSequence : null;
    final uidNext = box.uidNext ?? was.uidNext;
    // Only QRESYNC makes an EXPUNGE raise HIGHESTMODSEQ (RFC 7162 §3.2.10): with CONDSTORE alone a deletion may
    // leave it as it was.
    if (_session.qresync && modSeq != null && modSeq == was.modSeq && uidNext == was.uidNext) {
      return (messages: const <ImapParsed>[], removed: const <String>[], state: known);
    }

    final (:flags, :gone) = await _knownFlags(c, was, condstore: modSeq != null && was.modSeq != null);
    final seen = {...was.seen};
    final flagged = {...was.flagged};
    final changed = <int>[];
    for (final MapEntry(key: uid, value: (isSeen, isFlagged)) in flags.entries) {
      if (gone.contains(uid) || !was.uids.contains(uid)) continue;
      // A stored message seen here for the first time comes again: its flags here are not known.
      if (!known.uids.contains(uid) || isSeen != seen.contains(uid) || isFlagged != flagged.contains(uid)) {
        changed.add(uid);
      }
      isSeen ? seen.add(uid) : seen.remove(uid);
      isFlagged ? flagged.add(uid) : flagged.remove(uid);
    }
    final fresh = [
      for (final u in await search(c, 'UID ${was.uidNext}:*'))
        if (u >= was.uidNext) u,
    ];
    final messages = [
      // Whole, as Gmail's changed messages: a header-only one would come without its snippet.
      // ponytail: a read elsewhere downloads the inbox message again; keep the stored snippet if that costs too much.
      ...await _fetch(c, folder, uidValidity, changed, bodies: true),
      ...await _fetch(c, folder, uidValidity, fresh, bodies: true),
    ];
    final added = {for (final m in messages) _uid(m)}.where(fresh.contains);
    for (final m in messages) {
      final u = _uid(m);
      m.message.isRead ? seen.add(u) : seen.remove(u);
      m.message.isStarred ? flagged.add(u) : flagged.remove(u);
    }
    final uids = {...was.uids.difference(gone), ...added};
    return (
      messages: messages,
      removed: [for (final u in gone) imapMessageId(folder.path, uidValidity, u)],
      state: FolderState(
        uidValidity: uidValidity,
        uidNext: [uidNext, was.uidNext, for (final u in added) u + 1].reduce((a, b) => a > b ? a : b),
        modSeq: modSeq,
        uids: uids,
        seen: seen.intersection(uids),
        flagged: flagged.intersection(uids),
      ),
    );
  }

  /// The flags (seen, flagged) of the known UIDs that may have changed, and the known UIDs gone from the folder:
  /// expunged, or `\Deleted` and not expunged yet (as another client's Elimina means it). With CONDSTORE asked
  /// for the range from the lowest known UID to the highest (what else it holds is left out); without it for the
  /// known UIDs a block at a time: a sparse set in one command would be longer than servers take (RFC 7162 §4
  /// suggests 8192 octets).
  // ponytail: `\Answered`, `$Forwarded` and the keywords are not read: no indicator shows them, nor an Etichetta.
  Future<({Map<int, (bool, bool)> flags, Set<int> gone})> _knownFlags(
    ImapClient c,
    FolderState was, {
    required bool condstore,
  }) async {
    if (was.uids.isEmpty) return (flags: const <int, (bool, bool)>{}, gone: const <int>{});
    final sorted = was.uids.toList()..sort();
    final known = MessageSequence.fromRange(sorted.first, sorted.last, isUidSequence: true);
    final flags = <int, (bool, bool)>{};
    final deleted = <int>{};
    void read(List<MimeMessage> ms) {
      for (final m in ms) {
        if (m.uid case final uid? when was.uids.contains(uid)) {
          // ponytail: `\Deleted` cleared again elsewhere does not bring the message back (its UID is left behind);
          // keep the deleted UIDs in the state if a client that undoes deletions shows up.
          m.isDeleted ? deleted.add(uid) : flags[uid] = (m.isSeen, m.isFlagged);
        }
      }
    }

    if (condstore && _session.qresync) {
      final r = await c.uidFetchMessagesByCriteria(
        '$known (FLAGS) (CHANGEDSINCE ${was.modSeq} VANISHED)',
        responseTimeout: ImapSession.timeout,
      );
      read(r.messages);
      final vanished = r.vanishedMessagesUidSequence?.toList() ?? const <int>[];
      return (flags: flags, gone: {...was.uids.intersection(vanished.toSet()), ...deleted});
    }
    if (condstore) {
      final r = await c.uidFetchMessages(
        known,
        '(FLAGS)',
        changedSinceModSequence: was.modSeq,
        responseTimeout: ImapSession.timeout,
      );
      read(r.messages);
      return (flags: flags, gone: was.uids.difference((await search(c, 'UID $known')).toSet()));
    }
    // ponytail: every known UID's flags on every poll; fine for a 90-day window, CONDSTORE spares it where announced.
    for (var i = 0; i < sorted.length; i += _flagsBlock) {
      final block = MessageSequence.fromIds(sorted.skip(i).take(_flagsBlock).toList(), isUid: true);
      read((await c.uidFetchMessages(block, '(UID FLAGS)', responseTimeout: ImapSession.timeout)).messages);
    }
    return (flags: flags, gone: was.uids.difference(flags.keys.toSet()));
  }

  /// UIDs per FETCH FLAGS without CONDSTORE: 500 sparse ones stay under 8192 octets.
  static const _flagsBlock = 500;

  /// [fetchMessages] whole only for the inbox (ADR 0003).
  static Future<List<ImapParsed>> _fetch(
    ImapClient c,
    ImapFolder folder,
    int uidValidity,
    List<int> uids, {
    required bool bodies,
  }) => fetchMessages(c, folder, uidValidity, uids, withBody: bodies && folder.role == FolderRole.inbox);

  static int _uid(ImapParsed m) => parseImapMessageId(m.message.id)!.uid;
}

/// The [uids] of the selected [folder] in that order (the server answers in its own), headers only or, [withBody],
/// whole; a page at a time: short commands, and a body page that fits the timeout.
Future<List<ImapParsed>> fetchMessages(
  ImapClient c,
  ImapFolder folder,
  int uidValidity,
  List<int> uids, {
  bool withBody = false,
}) async {
  const page = 50;
  final byUid = <int, MimeMessage>{};
  for (var i = 0; i < uids.length; i += page) {
    final r = await c.uidFetchMessages(
      MessageSequence.fromIds(uids.skip(i).take(page).toList(), isUid: true),
      withBody ? '(UID FLAGS INTERNALDATE BODY.PEEK[])' : '(UID FLAGS INTERNALDATE BODY.PEEK[HEADER])',
      responseTimeout: ImapSession.timeout,
    );
    byUid.addAll({for (final m in r.messages) ?m.uid: m});
  }
  return [
    for (final uid in uids)
      if (byUid[uid] case final m?)
        parseImapMessage(
          m,
          id: imapMessageId(folder.path, uidValidity, uid),
          labelId: folder.labelId,
          withBody: withBody,
        ),
  ];
}

/// The UIDs of the selected folder matching [criteria] (an IMAP SEARCH key), but those `\Deleted` and not expunged
/// yet: deleted elsewhere, they are gone for every caller.
Future<List<int>> search(ImapClient c, String criteria) async {
  final r = await c.uidSearchMessages(searchCriteria: '$criteria NOT DELETED', responseTimeout: ImapSession.timeout);
  final found = r.matchingSequence;
  return found == null || found.isEmpty ? <int>[] : found.toList();
}

/// A date as IMAP SEARCH writes it: `8-Aug-2026`.
String imapDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day}-${months[d.month - 1]}-${d.year}';
}
