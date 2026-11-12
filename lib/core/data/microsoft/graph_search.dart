import '../../domain/message.dart';
import '../../domain/provider_search_page.dart';
import '../../domain/result.dart';
import '../../domain/search_query.dart';
import '../json_objects.dart';
import '../oauth/oauth_failed.dart';
import 'graph_folders.dart';
import 'graph_http.dart';
import 'graph_kql.dart';
import 'graph_message_parser.dart';

/// What one `$search` on messages gives at most: Graph stops there.
const graphSearchLimit = 1000;

/// The search on Graph (#209): `GET /me/messages?$search=` over the whole mailbox, newest first (by date sent).
class GraphSearch(final GraphHttp _graph, final GraphFolders _folders) {
  /// Results per Graph page.
  static const _top = 50;

  /// Graph pages read in one call while the local filters keep none: the next ones come with «Mostra altri».
  static const _maxPages = 4;

  /// One page for [query] from [pageToken] (`<results seen> <@odata.nextLink>`, none: the first). Only messages
  /// of a synced folder, never Spam nor Cestino (Graph lists them too), with the folder's Etichetta as the sync
  /// gives it; those in [stored] give only their Conversazione. The page that ends at [graphSearchLimit] says so.
  /// A token that is not one of these (a link to another host) is [NotFoundFailure].
  Future<ProviderSearchPage> page(SearchQuery query, {required String? pageToken, required Set<String> stored}) async {
    final kql = graphKql(query);
    if (kql.isEmpty) return const ProviderSearchPage();
    var (seen, link) = pageToken == null ? (0, null) : _decode(pageToken);
    Map<String, String>? synced;
    final messages = <Message>[];
    final conversations = <String>{};
    for (var pages = 1; ; pages++) {
      final r = link == null
          ? await _graph.get('messages', query: {r'$search': kql, r'$top': '$_top', r'$select': graphMessageSelect})
          : await _graph.follow(link);
      final items = jsonObjects(r['value']).toList();
      seen += items.length;
      link = r['@odata.nextLink'] as String?;
      // The folders once per call, and only when something came: their Etichette as the sync has them.
      if (items.isNotEmpty) synced ??= {for (final f in await _folders.list()) f.id: f.labelId};
      for (final j in items) {
        final label = synced![j['parentFolderId']];
        if (label == null) continue;
        final m = parseGraphMessage(j, labelId: label);
        if (!graphSearchKeeps(query, m)) continue;
        conversations.add(m.conversationId);
        if (!stored.contains(m.id)) messages.add(m);
      }
      if (link == null || conversations.isNotEmpty || pages == _maxPages) break;
    }
    return ProviderSearchPage(
      messages: messages,
      conversationIds: conversations,
      nextPageToken: link == null ? null : '$seen $link',
      limit: link == null && seen >= graphSearchLimit ? graphSearchLimit : null,
    );
  }

  /// The results seen and the link of a token; the link is checked by [GraphHttp.follow].
  static (int, String) _decode(String token) {
    final space = token.indexOf(' ');
    final seen = space < 0 ? null : int.tryParse(token.substring(0, space));
    if (seen == null) throw const OAuthFailed(NotFoundFailure());
    return (seen, token.substring(space + 1));
  }
}
