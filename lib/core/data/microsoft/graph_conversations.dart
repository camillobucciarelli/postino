import '../../domain/message.dart';
import 'graph_folders.dart';
import 'graph_http.dart';
import 'graph_message_parser.dart';

/// A Conversazione read from the whole mailbox, whatever the folder (Inviati too) and the age of its messages.
class GraphConversations(final GraphHttp _graph, final GraphFolders _folders) {
  /// Every message of [conversationId], headers only, following the pages.
  Future<List<Message>> fetch(String conversationId) async {
    // OData quotes a single quote by doubling it.
    final id = conversationId.replaceAll("'", "''");
    final items = await _graph.list(
      'messages',
      query: {r'$filter': "conversationId eq '$id'", r'$select': graphMessageSelect},
    );
    return [
      for (final j in items) parseGraphMessage(j, labelId: await _folders.labelOf(j['parentFolderId'] as String)),
    ];
  }
}
