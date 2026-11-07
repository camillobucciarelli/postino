import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException, MessageSequence;

import '../../domain/mail_action.dart';
import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_flags.dart';
import 'imap_folder_sync.dart' show search;
import 'imap_folders.dart';
import 'imap_lookup.dart' show messageIdCriteria;
import 'imap_session.dart';

/// Moves a message between folders and finds the folder a [Placement] means; the folders Archivia and Elimina need
/// are created when the Account has none.
class ImapMoves(final ImapSession _session, final Future<ImapFolder> Function(ImapClient c, String name) _ensure) {
  /// The folder for [placement] among [folders]: the inbox, the Cestino (created as «Trash» if missing) or the
  /// archive (`\Archive`, iCloud's «Archive», else «Archivio» created at the first Archivia).
  Future<ImapFolder> folderFor(ImapClient c, List<ImapFolder> folders, Placement placement) async {
    final (role, name) = switch (placement) {
      Placement.inbox => (FolderRole.inbox, 'INBOX'),
      Placement.trash => (FolderRole.trash, 'Trash'),
      Placement.archive => (FolderRole.archive, 'Archivio'),
    };
    return folders.where((f) => f.role == role).firstOrNull ?? await _ensure(c, name);
  }

  /// Moves [at] to [target]: `UID MOVE`, or without MOVE COPY, `\Deleted` and EXPUNGE of that UID.
  /// A refusal of the server (a folder deleted elsewhere) is [RejectedFailure].
  Future<void> move(ImapClient c, ImapPlace at, ImapFolder target) async {
    await selectFolder(c, at.folder.path, condstore: _session.condstore);
    final uid = MessageSequence.fromId(at.uid, isUid: true);
    try {
      if (_session.move) {
        await c.uidMove(uid, targetMailboxPath: target.path);
        return;
      }
      // A COPY done by an earlier try that failed before the EXPUNGE must not be repeated.
      if (!await _copied(c, at, target)) await c.uidCopy(uid, targetMailboxPath: target.path);
      await c.uidMarkDeleted(uid);
      // ponytail: without UIDPLUS a plain EXPUNGE also takes the other messages marked \Deleted; UIDPLUS is
      // everywhere in practice.
      await (_session.uidPlus ? c.uidExpunge(uid) : c.expunge());
    } on ImapException catch (e) {
      if (!c.isConnected || e.message == 'timeout') rethrow;
      throw ImapFailed(RejectedFailure('the server refused the move to ${target.path}'));
    }
  }

  /// Whether [target] already holds the message of [at] (by Message-ID); [at]'s folder is selected again after.
  Future<bool> _copied(ImapClient c, ImapPlace at, ImapFolder target) async {
    final r = await c.uidFetchMessages(
      MessageSequence.fromId(at.uid, isUid: true),
      '(UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])',
      responseTimeout: ImapSession.timeout,
    );
    final criteria = switch (r.messages
        .where((m) => m.uid == at.uid)
        .firstOrNull
        ?.getHeaderValue('message-id')
        ?.trim()) {
      final id? => messageIdCriteria(id),
      null => null,
    };
    if (criteria == null) return false;
    await selectFolder(c, target.path, condstore: _session.condstore);
    final found = (await search(c, criteria)).isNotEmpty;
    await selectFolder(c, at.folder.path, condstore: _session.condstore);
    return found;
  }
}
