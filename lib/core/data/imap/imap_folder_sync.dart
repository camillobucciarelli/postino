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

  /// What changed in [folder] since [was]. A new UIDVALIDITY rebuilds it: the old ids all go, the window comes
  /// again. With CONDSTORE only the flags changed since the last HIGHESTMODSEQ come (with QRESYNC the UIDs
  /// expunged too, `VANISHED`); without it the flags of every known UID are compared with [was].
  Future<FolderDelta> changes(ImapClient c, ImapFolder folder, FolderState was, DateTime since) async {
    final box = await selectFolder(c, folder.path, condstore: _session.condstore);
    final uidValidity = box.uidValidity ?? 0;
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
      return (messages: const <ImapParsed>[], removed: const <String>[], state: was);
    }

    final (:flags, :gone) = await _knownFlags(c, was, condstore: modSeq != null && was.modSeq != null);
    final seen = {...was.seen};
    final flagged = {...was.flagged};
    final changed = <int>[];
    for (final MapEntry(key: uid, value: (isSeen, isFlagged)) in flags.entries) {
      if (gone.contains(uid) || !was.uids.contains(uid)) continue;
      if (isSeen != seen.contains(uid) || isFlagged != flagged.contains(uid)) changed.add(uid);
      isSeen ? seen.add(uid) : seen.remove(uid);
      isFlagged ? flagged.add(uid) : flagged.remove(uid);
    }
    final fresh = [
      for (final u in await search(c, 'UID ${was.uidNext}:* SINCE ${imapDate(since)}'))
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

  /// The flags (seen, flagged) of the known UIDs that may have changed, and the known UIDs gone from the folder.
  /// Asked for the range from the lowest known UID to the highest, not the UIDs one by one: a sparse set would
  /// make a command longer than servers take (RFC 7162 §4 suggests 8192 octets); what else the range holds is
  /// left out.
  Future<({Map<int, (bool, bool)> flags, Set<int> gone})> _knownFlags(
    ImapClient c,
    FolderState was, {
    required bool condstore,
  }) async {
    if (was.uids.isEmpty) return (flags: const <int, (bool, bool)>{}, gone: const <int>{});
    final sorted = was.uids.toList()..sort();
    final known = MessageSequence.fromRange(sorted.first, sorted.last, isUidSequence: true);
    Map<int, (bool, bool)> flagsOf(List<MimeMessage> ms) => {
      for (final m in ms)
        if (m.uid case final uid? when was.uids.contains(uid)) uid: (m.isSeen, m.isFlagged),
    };
    if (condstore && _session.qresync) {
      final r = await c.uidFetchMessagesByCriteria(
        '$known (FLAGS) (CHANGEDSINCE ${was.modSeq} VANISHED)',
        responseTimeout: ImapSession.timeout,
      );
      final vanished = r.vanishedMessagesUidSequence?.toList() ?? const <int>[];
      return (flags: flagsOf(r.messages), gone: was.uids.intersection(vanished.toSet()));
    }
    if (condstore) {
      final r = await c.uidFetchMessages(
        known,
        '(FLAGS)',
        changedSinceModSequence: was.modSeq,
        responseTimeout: ImapSession.timeout,
      );
      return (flags: flagsOf(r.messages), gone: was.uids.difference((await search(c, 'UID $known')).toSet()));
    }
    // ponytail: every known UID's flags on every poll; fine for a 90-day window, CONDSTORE spares it where announced.
    final r = await c.uidFetchMessages(known, '(UID FLAGS)', responseTimeout: ImapSession.timeout);
    final flags = flagsOf(r.messages);
    return (flags: flags, gone: was.uids.difference(flags.keys.toSet()));
  }

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

/// The UIDs of the selected folder matching [criteria] (an IMAP SEARCH key).
Future<List<int>> search(ImapClient c, String criteria) async {
  final r = await c.uidSearchMessages(searchCriteria: criteria, responseTimeout: ImapSession.timeout);
  final found = r.matchingSequence;
  return found == null || found.isEmpty ? <int>[] : found.toList();
}

/// A date as IMAP SEARCH writes it: `8-Aug-2026`.
String imapDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day}-${months[d.month - 1]}-${d.year}';
}
