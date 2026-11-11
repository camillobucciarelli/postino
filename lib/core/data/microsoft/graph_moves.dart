import '../../domain/message.dart';
import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import 'graph_folders.dart';
import 'graph_http.dart';
import 'graph_lookup.dart';

/// Archivia, Elimina and the Etichette (folders) on Graph: `POST /me/messages/{id}/move`, never a `DELETE`.
class GraphMoves(final GraphHttp _graph, final GraphFolders _folders, final GraphLookup _lookup) {
  /// Graph's well-known folders: Archivio, Cestino and the inbox.
  static const archive = 'archive';
  static const trash = 'deleteditems';
  static const inbox = 'inbox';

  /// The folder created when an Account has no `archive` (Outlook.com has one), as on IMAP.
  static const archiveName = 'Archivio';

  /// Graph's name for each system Etichetta (`TRASH` is `deleteditems`); any other Etichetta id is a folder id.
  static const _systemFolders = {
    inboxLabelId: inbox,
    trashLabelId: trash,
    spamLabelId: 'junkemail',
    sentLabelId: 'sentitems',
    draftLabelId: 'drafts',
  };

  /// The folder to move into for Etichetta [labelId].
  static String folderOf(String labelId) => _systemFolders[labelId] ?? labelId;

  /// Moves message [id] into folder [destination] (a Graph folder id or well-known name). Graph has no
  /// precondition for a move: the caller read the folder just before. A message gone is [NotFoundFailure];
  /// a folder gone is [RejectedFailure], except `archive`, which is created.
  Future<void> move(String id, String destination) async {
    try {
      await _move(id, destination);
    } on OAuthFailed catch (e) {
      // A 404 is the message or the destination: tell them apart by reading the message.
      if (e.failure is! NotFoundFailure || await _lookup.read(id) == null) rethrow;
      if (destination != archive) throw OAuthFailed(RejectedFailure('the folder $destination is gone'));
      await _move(id, (await _folders.create(archiveName)).id);
    }
  }

  Future<void> _move(String id, String destination) =>
      _graph.send('POST', 'messages/$id/move', body: {'destinationId': destination});
}
