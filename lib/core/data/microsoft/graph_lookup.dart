import '../../domain/result.dart';
import '../json_objects.dart';
import '../oauth/oauth_failed.dart';
import 'graph_http.dart';
import 'graph_place.dart';

/// Where a message is now, read for an Azione: by its Graph id, or by its `internetMessageId` when the id is gone.
class GraphLookup(final GraphHttp _graph) {
  /// Message [id] as it is now; null when it is gone (404).
  Future<GraphPlace?> read(String id) async {
    try {
      return parseGraphPlace(await _graph.get('messages/$id', query: {r'$select': graphPlaceSelect}));
    } on OAuthFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }

  /// The message with Message-ID [messageId] wherever it is in the mailbox; null when there is none. Two copies
  /// (a self-sent message is in Inviati too) do not say which one the Azione was queued for: [UnexpectedFailure],
  /// the Azione stays queued rather than acting on a guess.
  Future<GraphPlace?> byInternetMessageId(String messageId) async {
    // OData quotes a single quote by doubling it.
    final quoted = messageId.replaceAll("'", "''");
    final page = await _graph.get(
      'messages',
      query: {r'$filter': "internetMessageId eq '$quoted'", r'$select': graphPlaceSelect, r'$top': '2'},
    );
    final found = jsonObjects(page['value']).map(parseGraphPlace).toList();
    if (found.length > 1) throw const OAuthFailed(UnexpectedFailure('Graph: more messages share the Message-ID'));
    return found.firstOrNull;
  }
}
