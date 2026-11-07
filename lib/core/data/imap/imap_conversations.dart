import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException;

import '../../domain/message.dart';
import '../../domain/result.dart';
import 'imap_bodies.dart';
import 'imap_failure.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';
import 'imap_threads.dart';

/// The whole Conversazione, searched on the server: Inviati, Archivio, the user's folders and what is older than the
/// sync window have messages the database may not hold.
class ImapConversations(final ImapSession _session, final String _address) {
  /// Every message of [folders] that is [conversationId] (a Message-ID, the root's: `imap_threads.dart`) or cites it
  /// in `References` or `In-Reply-To`, and the replies to those in turn (a chain with only `In-Reply-To`), up to
  /// [maxThreadDepth] levels; threaded as the syncs do, with the preview the list shows. [NotFoundFailure] when there
  /// is none.
  // ponytail: a reply threaded by its subject alone (no header citing the Conversazione) is not found; the sync has it.
  Future<List<Message>> fetch(ImapClient c, List<ImapFolder> folders, String conversationId) async {
    // A message without Message-ID is its own Conversazione, named by its Provider id: fetched by UID.
    final own = parseImapMessageId(conversationId);
    if (own == null && !_ascii(conversationId)) throw const ImapFailed(NotFoundFailure());
    final found = <String, ImapParsed>{};
    final snippets = <String, String>{};
    var criteria = <String>[];
    if (own == null) {
      final q = _quoted(conversationId);
      criteria = ['OR HEADER Message-ID $q OR HEADER References $q HEADER In-Reply-To $q'];
    } else if (folders.where((f) => f.path == own.path).firstOrNull case final f?) {
      try {
        final box = await selectFolder(c, f.path, condstore: _session.condstore);
        if ((box.uidValidity ?? 0) == own.uidValidity) {
          for (final p in await fetchMessages(c, f, own.uidValidity, [own.uid])) {
            found[p.message.id] = p;
            snippets[p.message.id] = await _snippet(c, p);
          }
        }
      } on ImapFailed catch (e) {
        if (e.failure is! NotFoundFailure) rethrow;
      }
    }
    for (var level = 0; level < maxThreadDepth && criteria.isNotEmpty; level++) {
      final fresh = <ImapParsed>[];
      for (final f in folders) {
        try {
          final box = await selectFolder(c, f.path, condstore: _session.condstore);
          final uids = {for (final k in criteria) ...await search(c, k)};
          final parsed = await fetchMessages(c, f, box.uidValidity ?? 0, uids.toList());
          for (final p in parsed) {
            if (found.containsKey(p.message.id)) continue;
            found[p.message.id] = p;
            snippets[p.message.id] = await _snippet(c, p);
            fresh.add(p);
          }
        } on ImapFailed catch (e) {
          if (e.failure is! NotFoundFailure) rethrow;
        } on ImapException catch (e) {
          if (!c.isConnected || e.message == 'timeout') rethrow;
        }
      }
      // The next level: the replies to what this one brought.
      criteria = [
        for (final id in {for (final p in fresh) p.message.messageId})
          if (_ascii(id)) 'HEADER In-Reply-To ${_quoted(id)}',
      ];
    }
    final inputs = [for (final p in found.values) (message: p.message, inReplyTo: p.inReplyTo)];
    final messages = [
      for (final m in threadMessages(inputs, known: inputs, address: _address))
        if (m.conversationId == conversationId) withConversation(m, m.conversationId, snippet: snippets[m.id]),
    ];
    if (messages.isEmpty) throw const ImapFailed(NotFoundFailure());
    return messages;
  }

  /// The preview of [p] (in the selected folder); empty if the message went in the meantime.
  Future<String> _snippet(ImapClient c, ImapParsed p) async {
    try {
      return imapSnippet(await readBody(c, parseImapMessageId(p.message.id)!.uid));
    } on ImapFailed catch (e) {
      if (e.failure is NotFoundFailure) return '';
      rethrow;
    }
  }
}

bool _ascii(String s) => RegExp(r'^[\x20-\x7e]+$').hasMatch(s);

String _quoted(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
