import 'package:flutter/foundation.dart';

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
class GraphDelta(final GraphHttp _graph) {
  /// Graph answers a delta with `$filter` with at most this many messages (delta-query-messages).
  static const filterCap = 5000;

  /// The first round of folder [folderId], whose Etichetta is [labelId]: the messages received since [since],
  /// newest first, page by page to [onPage]. The next rounds keep the window and the properties asked here.
  // ponytail: a folder with more than [filterCap] messages in the window syncs only [filterCap] of them; drop the
  // `$filter` and keep the window here if such folders show up (a far longer first round).
  Future<FolderDelta> start(String folderId, String labelId, DateTime since, {SyncPage? onPage}) async {
    final d = await _round(
      _graph.get(
        'mailFolders/$folderId/messages/delta',
        query: {
          r'$select': labelId == inboxLabelId ? graphBodySelect : graphMessageSelect,
          r'$filter': 'receivedDateTime ge ${since.toUtc().toIso8601String()}',
          r'$orderby': 'receivedDateTime desc',
        },
      ),
      labelId,
      onPage,
    );
    if (d.messages.length >= filterCap) debugPrint('[graph] a folder reached the $filterCap messages of a delta');
    return d;
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
