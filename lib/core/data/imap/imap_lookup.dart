import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException;

import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';
import 'imap_threads.dart';

/// Searches on the server across the synced folders: a message by Message-ID, and the messages a reply needs to
/// find its Conversazione when they are not in the batch.
class ImapLookup(final ImapSession _session) {
  /// Parents and subject predecessors followed at most this far back.
  static const _depth = 5;

  /// The Provider id of the message with [messageId] in the first of [folders] that holds it; null if none does.
  Future<String?> byMessageId(ImapClient c, List<ImapFolder> folders, String messageId) async {
    if (!_ascii(messageId)) return null;
    for (final f in folders) {
      final box = await selectFolder(c, f.path, condstore: _session.condstore);
      final uids = await search(c, 'HEADER Message-ID ${_quoted(messageId)}');
      if (uids.isNotEmpty) return imapMessageId(f.path, box.uidValidity ?? 0, uids.first);
    }
    return null;
  }

  /// The headers [threadMessages] needs beyond [known] to thread [messages]: the parent of a reply with only
  /// `In-Reply-To`, the messages with the subject of a reply without references within [threadWindow] before it;
  /// and theirs in turn, up to [_depth] levels. The same lookups in the initial and the incremental sync keep a
  /// Conversazione's id from moving when a message comes back changed. Best effort: a folder or a SEARCH the server
  /// refuses is skipped.
  // ponytail: a SEARCH per such message, folder and level; they are rare (most replies carry References), an index
  // of the window if a mailbox makes them slow.
  Future<List<ThreadInput>> related(
    ImapClient c,
    List<ImapFolder> folders,
    List<ThreadInput> messages,
    Iterable<ThreadInput> known,
  ) async {
    final ids = {for (final k in known) k.message.messageId};
    final searched = <String>{};
    final out = <ThreadInput>[];
    var pending = messages;
    for (var level = 0; level < _depth && pending.isNotEmpty; level++) {
      final keys = {
        for (final t in pending)
          if (t.message.references.isEmpty) ?_key(t, ids),
      }.difference(searched);
      searched.addAll(keys);
      if (keys.isEmpty) break;
      final found = <ThreadInput>[];
      for (final f in folders) {
        found.addAll(await _search(c, f, keys));
      }
      pending = [
        for (final t in found)
          if (ids.add(t.message.messageId)) t,
      ];
      out.addAll(pending);
    }
    return out;
  }

  /// The headers of the messages of [f] matching any of [keys]; none when the server refuses.
  Future<List<ThreadInput>> _search(ImapClient c, ImapFolder f, Set<String> keys) async {
    try {
      final box = await selectFolder(c, f.path, condstore: _session.condstore);
      final uids = <int>{};
      for (final k in keys) {
        uids.addAll(await search(c, k));
      }
      return [
        for (final p in await fetchMessages(c, f, box.uidValidity ?? 0, uids.toList()))
          (message: p.message, inReplyTo: p.inReplyTo),
      ];
    } on ImapFailed catch (e) {
      if (e.failure is NotFoundFailure) return const [];
      rethrow;
    } on ImapException catch (e) {
      if (!c.isConnected || e.message == 'timeout') rethrow;
      return const [];
    }
  }
}

/// The SEARCH key for what [t] answers, null when it needs none: its parent already in [known] or a plain subject.
String? _key(ThreadInput t, Set<String> known) {
  final m = t.message;
  if (t.inReplyTo case final parent?) {
    return known.contains(parent) || !_ascii(parent) ? null : 'HEADER Message-ID ${_quoted(parent)}';
  }
  final word = _searchWord(m.subject);
  if (word == null) return null;
  // By the Date header (SENT*), as the window of threadMessages.
  return 'SENTSINCE ${imapDate(m.date.subtract(threadWindow))} '
      'SENTBEFORE ${imapDate(m.date.add(const Duration(days: 1)))} SUBJECT ${_quoted(word)}';
}

/// What to SEARCH SUBJECT for a reply without references: its normalized subject if plain ASCII (a quoted string
/// may hold nothing else), else its longest ASCII word, filtered exactly afterwards; null when there is none to
/// search or the subject is no reply.
String? _searchWord(String subject) {
  if (!hasReplyPrefix(subject)) return null;
  final s = normalizedSubject(subject);
  if (s.isEmpty) return null;
  if (_ascii(s)) return s;
  final words = RegExp(r'[\x21-\x7e]{3,}').allMatches(s).map((m) => m[0]!).toList()
    ..sort((a, b) => b.length - a.length);
  return words.firstOrNull;
}

bool _ascii(String s) => RegExp(r'^[\x20-\x7e]+$').hasMatch(s);

String _quoted(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
