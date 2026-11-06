import 'package:enough_mail/enough_mail.dart' show ImapClient, MessageSequence;

import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';
import 'imap_threads.dart';

/// Searches on the server across the synced folders: a message by Message-ID, and the messages a reply needs to
/// find its Conversazione when they are not in the batch.
class ImapLookup(final ImapSession _session) {
  /// The Provider id of the message with [messageId] in the first of [folders] that holds it; null if none does.
  Future<String?> byMessageId(ImapClient c, List<ImapFolder> folders, String messageId) async {
    for (final f in folders) {
      final box = await selectFolder(c, f.path, condstore: _session.condstore);
      final uids = await search(c, 'HEADER Message-ID ${_quoted(messageId)}');
      if (uids.isNotEmpty) return imapMessageId(f.path, box.uidValidity ?? 0, uids.first);
    }
    return null;
  }

  /// The headers [threadMessages] needs beyond [messages]: the parent of a reply with only `In-Reply-To`, the
  /// messages with the subject of a reply without references within [threadWindow] before it.
  // ponytail: one level of parents and a SEARCH per such message and folder; they are rare (most replies carry
  // References), an index of the window if a mailbox makes them slow.
  Future<List<ThreadInput>> related(ImapClient c, List<ImapFolder> folders, List<ImapParsed> messages) async {
    final keys = <String>[
      for (final p in messages)
        if (p.message.references.isEmpty)
          if (p.inReplyTo case final parent?)
            'HEADER Message-ID ${_quoted(parent)}'
          else if (_searchWord(p.message.subject) case final word?)
            // By the Date header (SENT*), as the window of threadMessages.
            'SENTSINCE ${imapDate(p.message.date.subtract(threadWindow))} '
                'SENTBEFORE ${imapDate(p.message.date.add(const Duration(days: 1)))} SUBJECT ${_quoted(word)}',
    ];
    if (keys.isEmpty) return const [];
    final out = <ThreadInput>[];
    for (final f in folders) {
      final box = await selectFolder(c, f.path, condstore: _session.condstore);
      final uids = {for (final k in keys) ...await search(c, k)}.toList();
      if (uids.isEmpty) continue;
      final r = await c.uidFetchMessages(
        MessageSequence.fromIds(uids, isUid: true),
        '(UID FLAGS INTERNALDATE BODY.PEEK[HEADER])',
      );
      for (final m in r.messages) {
        if (m.uid case final uid?) {
          final p = parseImapMessage(m, id: imapMessageId(f.path, box.uidValidity ?? 0, uid), labelId: f.labelId);
          out.add((message: p.message, inReplyTo: p.inReplyTo));
        }
      }
    }
    return out;
  }
}

/// What to SEARCH SUBJECT for a reply without references: its normalized subject if plain ASCII (a quoted string
/// may hold nothing else), else its longest ASCII word, filtered exactly afterwards; null when there is none to
/// search or the subject is no reply.
String? _searchWord(String subject) {
  if (!hasReplyPrefix(subject)) return null;
  final s = normalizedSubject(subject);
  if (s.isEmpty) return null;
  if (RegExp(r'^[\x20-\x7e]+$').hasMatch(s)) return s;
  final words = RegExp(r'[\x21-\x7e]{3,}').allMatches(s).map((m) => m[0]!).toList()
    ..sort((a, b) => b.length - a.length);
  return words.firstOrNull;
}

String _quoted(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
