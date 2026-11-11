/// The properties an Azione reads: where the message is and the attributes it can change (the `@odata.etag` comes along).
const graphPlaceSelect = 'id,internetMessageId,parentFolderId,isRead,flag';

/// A message as Graph has it now: its folder (`parentFolderId`), flags and the etag that any change moves.
typedef GraphPlace = ({String id, String etag, String folderId, bool isRead, bool flagged});

/// The [GraphPlace] of a message answered with `graphPlaceSelect`.
GraphPlace parseGraphPlace(Map<String, dynamic> j) => (
  id: j['id'] as String,
  etag: j['@odata.etag'] as String? ?? '',
  folderId: j['parentFolderId'] as String? ?? '',
  isRead: j['isRead'] as bool? ?? false,
  flagged: (j['flag'] as Map<String, dynamic>?)?['flagStatus'] == 'flagged',
);
