import 'dart:convert';

/// Where a synced folder's next delta round starts: its Etichetta id and its `@odata.deltaLink`.
typedef FolderLink = ({String label, String link});

/// The sync cursor of a Microsoft Account, opaque to the core: the `@odata.deltaLink` of the folder delta
/// ([folders]: folders new, renamed or deleted) and, by Graph folder id, the message delta of each synced folder.
class const GraphCursor(final String folders, final Map<String, FolderLink> messages) {
  String encode() => jsonEncode({
    'folders': folders,
    'messages': {
      for (final MapEntry(:key, :value) in messages.entries) key: {'label': value.label, 'link': value.link},
    },
  });

  /// Null for a cursor that is not one (another Provider's, or corrupted): the caller redoes the initial sync.
  static GraphCursor? decode(String cursor) {
    try {
      final j = jsonDecode(cursor) as Map<String, dynamic>;
      return GraphCursor(j['folders'] as String, {
        for (final MapEntry(:key, :value) in (j['messages'] as Map<String, dynamic>).entries)
          key: (label: (value as Map<String, dynamic>)['label'] as String, link: value['link'] as String),
      });
    } on Object catch (_) {
      return null;
    }
  }
}
