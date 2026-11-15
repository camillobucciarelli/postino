import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import '../json_objects.dart';
import '../oauth/oauth_failed.dart';
import 'graph_http.dart';
import 'graph_message_parser.dart';

/// One delta round of a folder: its messages new or changed (each in its last state), the inbox bodies, the ids
/// gone from it (`@removed`: deleted, or moved to another folder) and the `@odata.deltaLink` of the next round.
typedef FolderDelta = ({
  Map<String, Message> messages,
  Map<String, MessageBody> bodies,
  Set<String> removed,
  String link,
});

/// The message delta query of Graph, per folder (`/me/mailFolders/{id}/messages/delta`).
class GraphDelta(final GraphHttp _graph, {final int cap = filterCap}) {
  /// Graph answers a delta with `$filter` with at most this many messages (delta-query-messages).
  static const filterCap = 5000;

  /// The first round of folder [folderId], whose Etichetta is [labelId]: the messages received since [since],
  /// newest first, page by page to [onPage]. The next rounds keep the window and the properties asked here.
  /// A round that reaches the cap was cut by Graph: the rest of the window comes from the paged list of the
  /// folder, `receivedDateTime` up to the oldest message seen (`le`: others may share its date); the delta link
  /// stays the one of the filtered round.
  // ponytail: not checked on a real account: whether the later rounds report the flag changes (Stella) of the
  // messages of that tail. If they do not, redo without `$filter` the folders that reach the cap.
  Future<FolderDelta> start(String folderId, String labelId, DateTime since, {SyncPage? onPage}) async {
    final select = labelId == inboxLabelId ? graphBodySelect : graphMessageSelect;
    final from = 'receivedDateTime ge ${since.toUtc().toIso8601String()}';
    final d = await _round(
      _graph.get(
        'mailFolders/$folderId/messages/delta',
        query: {r'$select': select, r'$filter': from, r'$orderby': 'receivedDateTime desc'},
      ),
      labelId,
      onPage,
    );
    if (d.messages.length < cap) return d;
    final oldest = d.messages.values.map((m) => m.date).reduce((a, b) => a.isBefore(b) ? a : b);
    var page = await _graph.get(
      'mailFolders/$folderId/messages',
      query: {
        r'$select': select,
        r'$filter': '$from and receivedDateTime le ${oldest.toUtc().toIso8601String()}',
        r'$orderby': 'receivedDateTime desc',
      },
    );
    while (true) {
      final fresh = <Message>[];
      final freshBodies = <String, MessageBody>{};
      for (final j in jsonObjects(page['value'])) {
        final id = j['id'] as String;
        if (d.messages.containsKey(id)) continue;
        final m = d.messages[id] = parseGraphMessage(j, labelId: labelId);
        fresh.add(m);
        if (graphBody(j) case final body?) d.bodies[id] = freshBodies[id] = body;
      }
      await onPage?.call(fresh, freshBodies);
      if (page['@odata.nextLink'] case final String next) {
        page = await _graph.follow(next);
      } else {
        return d;
      }
    }
  }

  /// The changes since the round that handed out [link].
  Future<FolderDelta> follow(String link, String labelId) => _round(_graph.follow(link), labelId, null);

  /// Message [id] as it is now (its headers, `parentFolderId` the folder it is in); null when it is gone.
  Future<Map<String, dynamic>?> current(String id) async {
    try {
      return await _graph.get('messages/$id', query: {r'$select': graphMessageSelect});
    } on OAuthFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }

  Future<FolderDelta> _round(Future<Map<String, dynamic>> first, String labelId, SyncPage? onPage) async {
    final messages = <String, Message>{};
    final bodies = <String, MessageBody>{};
    final removed = <String>{};
    for (var page = await first; ; page = await _graph.follow(page['@odata.nextLink'] as String)) {
      final pageMessages = <Message>[];
      final pageBodies = <String, MessageBody>{};
      // In order, so each message ends in its last state.
      for (final j in jsonObjects(page['value'])) {
        final id = j['id'] as String;
        if (j.containsKey('@removed')) {
          removed.add(id);
          messages.remove(id);
          bodies.remove(id);
          continue;
        }
        final m = messages[id] = parseGraphMessage(j, labelId: labelId);
        removed.remove(id);
        pageMessages.add(m);
        if (graphBody(j) case final body?) bodies[id] = pageBodies[id] = body;
      }
      await onPage?.call(pageMessages, pageBodies);
      if (page['@odata.deltaLink'] case final String link) {
        return (messages: messages, bodies: bodies, removed: removed, link: link);
      }
    }
  }
}
