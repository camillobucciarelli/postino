import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException, MessageSequence;

import '../../domain/mail_action.dart';
import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_flags.dart';
import 'imap_folders.dart';
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
      await c.uidCopy(uid, targetMailboxPath: target.path);
      await c.uidMarkDeleted(uid);
      // ponytail: without UIDPLUS a plain EXPUNGE also takes the other messages marked \Deleted; UIDPLUS is
      // everywhere in practice.
      await (_session.uidPlus ? c.uidExpunge(uid) : c.expunge());
    } on ImapException catch (e) {
      if (!c.isConnected || e.message == 'timeout') rethrow;
      throw ImapFailed(RejectedFailure('the server refused the move to ${target.path}'));
    }
  }
}
