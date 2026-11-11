import '../../domain/action_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import '../message_id_of.dart';
import '../oauth/oauth_failed.dart';
import 'graph_flags.dart';
import 'graph_folders.dart';
import 'graph_lookup.dart';
import 'graph_moves.dart';
import 'graph_place.dart';

/// The Azioni on Graph (ADR 0008): the message is read once (flags, folder, etag), compared with the expected and
/// the wanted value, and written only if needed. Letto and Stella are written with `If-Match` on the etag; Archivia,
/// Elimina and the Etichette (folders) are a move. Failures are thrown as [OAuthFailed].
class GraphActions(
  final GraphFolders _folders,
  final GraphLookup _lookup,
  final GraphFlags _flags,
  final GraphMoves _moves,
  final MessageIdOf _messageIdOf,
) {
  /// Reads again at most this many times when the etag moved under the write.
  static const _tries = 3;

  /// Applies [action] to [messageId]; [expected] null forces it. A message gone, also by its Message-ID, is
  /// [ActionMessageGone].
  Future<ActionOutcome> apply(String messageId, MailAction action, Object? expected) async {
    try {
      for (var i = 0; i < _tries; i++) {
        final at = await _locate(messageId);
        if (at == null) return const ActionMessageGone();
        final current = await _value(at, action);
        // Already as wanted: nothing to write.
        if (current == action.wanted) return const ActionApplied();
        // Elimina never conflicts. Another folder or flag changed is another attribute: not a Conflitto.
        if (expected != null && current != expected && action is! Delete) {
          return ActionConflict(current, movedTo: at.id == messageId ? null : at.id);
        }
        if (await _write(at, action)) return const ActionApplied();
      }
    } on OAuthFailed catch (e) {
      // Deleted between the read and the write.
      if (e.failure is NotFoundFailure) return const ActionMessageGone();
      rethrow;
    }
    throw const OAuthFailed(UnexpectedFailure('the message kept changing under the write'));
  }

  /// The message by its id; if that is gone, by the Message-ID the app remembers for it.
  Future<GraphPlace?> _locate(String id) async {
    if (await _lookup.read(id) case final at?) return at;
    final messageId = await _messageIdOf(id);
    return messageId == null ? null : _lookup.byInternetMessageId(messageId);
  }

  /// The value of the attribute of [action] at [at]: a folder that is neither the inbox nor the Cestino is archived.
  Future<Object> _value(GraphPlace at, MailAction action) async => switch (action) {
    MarkRead() || MarkUnread() => at.isRead,
    Star() || Unstar() => at.flagged,
    Archive() || Delete() => switch (await _folders.labelOf(at.folderId)) {
      inboxLabelId => Placement.inbox,
      trashLabelId => Placement.trash,
      _ => Placement.archive,
    },
    ApplyLabel(:final labelId) || RemoveLabel(:final labelId) => await _folders.labelOf(at.folderId) == labelId,
  };

  /// One write; false when the etag moved since the read.
  Future<bool> _write(GraphPlace at, MailAction action) async {
    switch (action) {
      case MarkRead() || MarkUnread() || Star() || Unstar():
        return _flags.write(at, action);
      case Archive():
        await _moves.move(at.id, GraphMoves.archive);
      case Delete():
        await _moves.move(at.id, GraphMoves.trash);
      case ApplyLabel(:final labelId):
        await _moves.move(at.id, labelId);
      case RemoveLabel():
        // A message is in one folder only: out of it is back in the inbox.
        // ponytail: the inbox even if it came from the archive; remember the folder it left if that matters.
        await _moves.move(at.id, GraphMoves.inbox);
    }
    return true;
  }
}
