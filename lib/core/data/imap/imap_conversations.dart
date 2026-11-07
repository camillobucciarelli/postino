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
  /// in `References` or `In-Reply-To`, threaded as the syncs do and with the preview the list shows. [NotFoundFailure]
  /// when there is none.
  // ponytail: a reply threaded by its subject alone (no headers citing the root) is not found; the sync has it.
  Future<List<Message>> fetch(ImapClient c, List<ImapFolder> folders, String conversationId) async {
    if (!_ascii(conversationId)) throw const ImapFailed(NotFoundFailure());
    final q = _quoted(conversationId);
    final criteria = 'OR HEADER Message-ID $q OR HEADER References $q HEADER In-Reply-To $q';
    final found = <ImapParsed>[];
    final snippets = <String, String>{};
    for (final f in folders) {
      try {
        final box = await selectFolder(c, f.path, condstore: _session.condstore);
        final parsed = await fetchMessages(c, f, box.uidValidity ?? 0, await search(c, criteria));
        for (final p in parsed) {
          snippets[p.message.id] = await _snippet(c, p);
        }
        found.addAll(parsed);
      } on ImapFailed catch (e) {
        if (e.failure is! NotFoundFailure) rethrow;
      } on ImapException catch (e) {
        if (!c.isConnected || e.message == 'timeout') rethrow;
      }
    }
    final inputs = [for (final p in found) (message: p.message, inReplyTo: p.inReplyTo)];
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
