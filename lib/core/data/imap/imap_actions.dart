import 'package:enough_mail/enough_mail.dart' show ImapClient;

import '../../domain/action_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_flags.dart';
import 'imap_folders.dart';
import 'imap_lookup.dart';
import 'imap_message_parser.dart';
import 'imap_moves.dart';
import 'imap_session.dart';

/// The Message-ID (RFC 5322) of the message with Provider id `id`, as the app remembers it; null if it does not.
typedef MessageIdOf = Future<String?> Function(String id);

/// The Azioni on IMAP (ADR 0008): the message is read once (flags and folder), compared with the expected and the
/// wanted value, and written only if needed. Letto and Stella are `\Seen` and `\Flagged`, written conditionally
/// with CONDSTORE where the server has it; Archivia, Elimina and the Etichette (folders) are a move.
/// Failures are thrown as [ImapFailed].
class ImapActions(
  final ImapSession _session,
  final ImapLookup _lookup,
  final ImapMoves _moves,
  final Future<List<ImapFolder>> Function(ImapClient c) _folders,
  final MessageIdOf _messageIdOf,
) {
  /// Reads again at most this many times when CONDSTORE says the flags changed under the write.
  static const _tries = 3;

  /// Applies [action] to [messageId]; [expected] null forces it. A message gone from every known folder is
  /// [ActionMessageGone].
  Future<ActionOutcome> apply(ImapClient c, String messageId, MailAction action, Object? expected) async {
    final folders = await _folders(c);
    for (var i = 0; i < _tries; i++) {
      final at = await _locate(c, folders, messageId);
      if (at == null) return const ActionMessageGone();
      final current = _value(at, action);
      // Already as wanted: nothing to write.
      if (current == action.wanted) return const ActionApplied();
      // Elimina never conflicts. Another folder or flag changed is another attribute: not a Conflitto.
      if (expected != null && current != expected && action is! Delete) return ActionConflict(current);
      if (await _write(c, folders, at, action)) return const ActionApplied();
    }
    throw const ImapFailed(UnexpectedFailure('the flags kept changing under the write'));
  }

  /// The message where [id] says; if its UID is gone (moved elsewhere, UIDVALIDITY changed), where its Message-ID
  /// is in the known folders.
  Future<ImapPlace?> _locate(ImapClient c, List<ImapFolder> folders, String id) async {
    final parsed = parseImapMessageId(id);
    if (parsed == null) return null;
    if (_folder(folders, parsed.path) case final f?) {
      final at = await readPlace(c, f, parsed.uid, uidValidity: parsed.uidValidity, condstore: _session.condstore);
      if (at != null) return at;
    }
    final messageId = await _messageIdOf(id);
    if (messageId == null) return null;
    final found = await _lookup.byMessageId(c, folders, messageId);
    final now = found == null ? null : parseImapMessageId(found);
    final folder = now == null ? null : _folder(folders, now.path);
    if (now == null || folder == null) return null;
    return readPlace(c, folder, now.uid, uidValidity: now.uidValidity, condstore: _session.condstore);
  }

  static ImapFolder? _folder(List<ImapFolder> folders, String path) => folders.where((f) => f.path == path).firstOrNull;

  /// The value of the attribute of [action] at [at]: a folder that is neither the inbox nor the Cestino is
  /// archived, as on Gmail.
  static Object _value(ImapPlace at, MailAction action) => switch (action) {
    MarkRead() || MarkUnread() => at.seen,
    Star() || Unstar() => at.flagged,
    Archive() || Delete() => switch (at.folder.role) {
      FolderRole.inbox => Placement.inbox,
      FolderRole.trash => Placement.trash,
      _ => Placement.archive,
    },
    ApplyLabel(:final labelId) || RemoveLabel(:final labelId) => at.folder.labelId == labelId,
  };

  /// One write; false when CONDSTORE refused it because the flags changed since the read.
  Future<bool> _write(ImapClient c, List<ImapFolder> folders, ImapPlace at, MailAction action) async {
    switch (action) {
      case MarkRead() || MarkUnread():
        return storeFlag(c, at, seenFlag, add: action.wanted == true);
      case Star() || Unstar():
        return storeFlag(c, at, flaggedFlag, add: action.wanted == true);
      case Archive() || Delete():
        await _moves.move(c, at, await _moves.folderFor(c, folders, action.wanted as Placement));
      case ApplyLabel(:final labelId):
        // A folder deleted elsewhere: the Provider refuses, and the replay drops the voce.
        final target = folders.where((f) => f.labelId == labelId).firstOrNull;
        await _moves.move(c, at, target ?? (throw ImapFailed(RejectedFailure('the folder $labelId is gone'))));
      case RemoveLabel():
        // A message is in one folder only: out of it is back in the inbox.
        // ponytail: the inbox even if it came from the archive; remember the folder it left if that matters.
        await _moves.move(c, at, await _moves.folderFor(c, folders, Placement.inbox));
    }
    return true;
  }
}
