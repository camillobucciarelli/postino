import 'package:enough_mail/enough_mail.dart' show ImapClient, MessageFlags;
import 'package:flutter/foundation.dart';

import '../../domain/result.dart';
import 'imap_drafts.dart';
import 'imap_failure.dart';
import 'imap_folders.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';
import 'imap_special_folder.dart';
import 'smtp_sender.dart';

/// Sending on IMAP (#166, `invio-posta-per-provider.md` §6): Inviati is searched by Message-ID first, so a send
/// whose answer was lost is not submitted again; SMTP submits; the copy in Inviati (`\Seen`) is a separate step,
/// whose failure is retried without a new SMTP submission; the Bozza with the same Message-ID goes last.
class ImapSent(
  final ImapSession _session,
  final SmtpSender _smtp,
  final ImapDrafts _drafts, {

  /// Whether the client stores the sent copy: false for a Provider that keeps the SMTP submissions by itself.
  required final bool appendToSent,
}) {
  /// Message-IDs submitted by SMTP whose copy in Inviati is not there yet: their retry only appends.
  // ponytail: in memory, so a restart between the submission and the APPEND submits again (a second delivery);
  // persist it with the outbox row if that ever bites.
  final _submitted = <String>{};

  /// Sends [raw], whose Message-ID is [messageId]; the id of its copy in Inviati.
  Future<String> send(String messageId, String raw) async {
    var id = await _session.run((c) => _find(c, messageId));
    if (id == null) {
      if (!_submitted.contains(messageId)) {
        await _smtp.send(raw);
        _submitted.add(messageId);
      }
      id = appendToSent
          ? await _session.run<String>((c) => _append(c, messageId, raw))
          // ponytail: the Provider may file its copy a moment later; the Message-ID stands in until the next sync.
          : await _session.run((c) => _find(c, messageId)) ?? messageId;
      _submitted.remove(messageId);
    }
    // Best effort: the message went, a Bozza left behind is deleted by the next save or by hand.
    try {
      await _drafts.delete(messageId);
    } on ImapFailed catch (e) {
      if (e.failure is! NotFoundFailure) debugPrint('[imap] draft of sent $messageId not deleted, ${e.failure}');
    }
    return id;
  }

  /// The id of the message with [messageId] in Inviati, null if it is not there.
  Future<String?> _find(ImapClient c, String messageId) async {
    final folder = await specialFolder(c, _session, FolderRole.sent, 'Sent');
    final box = await selectFolder(c, folder.path, condstore: _session.condstore);
    final uids = await uidsOfMessageId(c, messageId);
    return uids.isEmpty ? null : imapMessageId(folder.path, box.uidValidity ?? 0, uids.first);
  }

  Future<String> _append(ImapClient c, String messageId, String raw) async {
    final folder = await specialFolder(c, _session, FolderRole.sent, 'Sent');
    await c.appendMessageText(
      raw,
      targetMailboxPath: folder.path,
      flags: [MessageFlags.seen],
      responseTimeout: ImapSession.timeout,
    );
    return await _find(c, messageId) ?? (throw const ImapFailed(UnexpectedFailure('sent copy not found')));
  }
}
