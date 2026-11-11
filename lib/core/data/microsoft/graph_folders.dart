import '../../domain/message.dart';
import '../../domain/result.dart';
import '../json_objects.dart';
import '../oauth/oauth_failed.dart';
import 'graph_folder.dart';
import 'graph_http.dart';

/// The folders of a Microsoft Account (`/me/mailFolders`): the well-known ones by Graph's own names, never by their
/// display name, which is localized («Posta in arrivo»).
class GraphFolders(final GraphHttp _graph) {
  static const _outbox = 'OUTBOX';

  /// Graph's well-known folder names and the system Etichetta id of each.
  static const _wellKnown = {
    'inbox': inboxLabelId,
    'sentitems': sentLabelId,
    'drafts': draftLabelId,
    'deleteditems': trashLabelId,
    'junkemail': spamLabelId,
    'outbox': _outbox,
  };

  /// Not synced, nor what is inside them: Cestino and Spam as on IMAP, Posta in uscita being a
  /// transit folder.
  static const _unsynced = {trashLabelId, spamLabelId, _outbox};

  static const _query = {'includeHiddenFolders': 'false', r'$select': 'id,displayName,childFolderCount'};

  /// The system Etichetta id by Graph folder id.
  // ponytail: asked once per adapter, the ids of well-known folders never change; six GETs at every start.
  Map<String, String>? _system;

  /// Every synced folder, depth first, the inbox first: its page is the first the user sees.
  Future<List<GraphFolder>> list() async {
    final system = await _systemIds();
    final out = <GraphFolder>[];
    Future<void> walk(String? parentId, String parentPath) async {
      final path = parentId == null ? 'mailFolders' : 'mailFolders/$parentId/childFolders';
      for (final f in await _graph.list(path, query: _query)) {
        final id = f['id'] as String;
        final labelId = system[id] ?? id;
        if (_unsynced.contains(labelId) || isSearchFolder(f)) continue;
        final name = f['displayName'] as String? ?? '';
        final folderPath = parentId == null ? name : '$parentPath/$name';
        out.add(GraphFolder(id, folderPath, labelId));
        if ((f['childFolderCount'] as int? ?? 0) > 0) await walk(id, folderPath);
      }
    }

    await walk(null, '');
    return [...out.where((f) => f.labelId == inboxLabelId), ...out.where((f) => f.labelId != inboxLabelId)];
  }

  /// A search folder (`mailSearchFolder`, a derived type: OData annotates it with `@odata.type` whatever `$select`
  /// asks) holds no message of its own, only views of messages that live in another folder, with the same ids.
  static bool isSearchFolder(Map<String, dynamic> f) => f['@odata.type'] == '#microsoft.graph.mailSearchFolder';

  /// The folder delta from [link] (from scratch when null) to its end: whether any folder came, changed or went,
  /// and the `@odata.deltaLink` of the next round.
  Future<(bool, String)> delta(String? link) async {
    var changed = false;
    var page = link == null
        ? await _graph.get('mailFolders/delta', query: {r'$select': 'displayName,parentFolderId'})
        : await _graph.follow(link);
    while (true) {
      changed |= jsonObjects(page['value']).isNotEmpty;
      if (page['@odata.deltaLink'] case final String next) return (changed, next);
      page = await _graph.follow(page['@odata.nextLink'] as String);
    }
  }

  /// A top-level folder; idempotent on the name: one that already exists (`ErrorFolderExists`) is returned.
  Future<Label> create(String name) async {
    try {
      final f = await _graph.send('POST', 'mailFolders', body: {'displayName': name});
      return Label(id: f['id'] as String, name: f['displayName'] as String? ?? name, kind: LabelKind.cartella);
    } on OAuthFailed {
      // ponytail: any refused creation looks the name up (one GET); match ErrorFolderExists alone if that ever costs.
      if (await _named(name) case final existing?) return existing;
      rethrow;
    }
  }

  /// The user's top-level folder named [name], ignoring case as Outlook does.
  Future<Label?> _named(String name) async {
    final system = await _systemIds();
    for (final f in await _graph.list('mailFolders', query: _query)) {
      final id = f['id'] as String;
      final display = f['displayName'] as String? ?? '';
      if (!system.containsKey(id) && !isSearchFolder(f) && display.toLowerCase() == name.toLowerCase()) {
        return Label(id: id, name: display, kind: LabelKind.cartella);
      }
    }
    return null;
  }

  Future<Map<String, String>> _systemIds() async {
    if (_system case final known?) return known;
    final ids = await Future.wait(_wellKnown.keys.map(_idOf));
    return _system = {for (final (i, label) in _wellKnown.values.indexed) ?ids[i]: label};
  }

  /// The Graph id of the well-known folder [name]; null when the mailbox has none (Graph's 404).
  Future<String?> _idOf(String name) async {
    try {
      return (await _graph.get('mailFolders/$name', query: {r'$select': 'id'}))['id'] as String;
    } on OAuthFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }
}
