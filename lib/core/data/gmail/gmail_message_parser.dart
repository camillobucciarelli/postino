import 'dart:convert';
import 'dart:typed_data';

import '../../domain/message.dart';
import '../../domain/mailbox.dart';

/// A Gmail message resource (`full` or `metadata`) as a [Message].
Message parseGmailMessage(Map<String, dynamic> j) {
  final payload = j['payload'] as Map<String, dynamic>? ?? const {};
  final headers = {
    for (final h in payload['headers'] as List? ?? const [])
      (h['name'] as String).toLowerCase(): h['value'] as String,
  };
  final labels = [
    for (final l in j['labelIds'] as List? ?? const []) l as String,
  ];
  final from = parseMailbox(headers['from'] ?? '');
  return Message(
    id: j['id'] as String,
    messageId: headers['message-id'] ?? '',
    conversationId: j['threadId'] as String,
    labelIds: labels,
    isRead: !labels.contains('UNREAD'),
    isStarred: labels.contains('STARRED'),
    from: from.address,
    fromName: from.name,
    to: [for (final m in parseMailboxes(headers['to'] ?? '')) formatMailbox(m)],
    cc: [for (final m in parseMailboxes(headers['cc'] ?? '')) formatMailbox(m)],
    bcc: [
      for (final m in parseMailboxes(headers['bcc'] ?? '')) formatMailbox(m),
    ],
    subject: decodeWords(headers['subject'] ?? ''),
    snippet: _unescape(j['snippet'] as String? ?? ''),
    replyTo: switch (parseMailboxes(headers['reply-to'] ?? '')) {
      [final m, ...] => formatMailbox(m),
      _ => null,
    },
    references: (headers['references'] ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((r) => r.isEmpty),
    date: DateTime.fromMillisecondsSinceEpoch(
      int.parse(j['internalDate'] as String),
      isUtc: true,
    ),
  );
}

/// The attachments of a message [payload], ids being the part ids.
List<Attachment> gmailAttachments(Map<String, dynamic> payload) => [
  for (final p in gmailAttachmentParts(payload))
    Attachment(
      id: p['partId'] as String,
      name: p['filename'] as String? ?? '',
      size: (p['body'] as Map?)?['size'] as int? ?? 0,
      mimeType: p['mimeType'] as String?,
    ),
];

/// The parts the user sees as attachments, depth first; a part without a filename has an empty name. An image the HTML shows through `cid:`
/// (a Content-ID, not marked `attachment`) is part of the body, not an attachment.
Iterable<Map<String, dynamic>> gmailAttachmentParts(
  Map<String, dynamic> part,
) sync* {
  final headers = _partHeaders(part);
  final body = part['body'] as Map?;
  // A filename (an empty file too), or `Content-Disposition: attachment` with content even without one
  // (its name is then empty).
  if (_isAttachment(part) &&
      ((part['filename'] as String? ?? '').isNotEmpty ||
          body?['attachmentId'] != null ||
          body?['data'] != null) &&
      (headers['content-id'] == null ||
          (headers['content-disposition'] ?? '').startsWith('attachment'))) {
    yield part;
  }
  for (final p in part['parts'] as List? ?? const []) {
    yield* gmailAttachmentParts(p as Map<String, dynamic>);
  }
}

/// The first [mime] part carrying its content, inline or by attachmentId; attachments are skipped.
Map<String, dynamic>? gmailBodyPart(Map<String, dynamic> part, String mime) {
  if (_isAttachment(part)) return null;
  final body = part['body'] as Map?;
  if (part['mimeType'] == mime &&
      (body?['data'] != null || body?['attachmentId'] != null)) {
    return part;
  }
  for (final p in part['parts'] as List? ?? const []) {
    if (gmailBodyPart(p as Map<String, dynamic>, mime) case final found?) {
      return found;
    }
  }
  return null;
}

/// Gmail's base64url `data`, padding optional.
Uint8List decodeGmailData(String data) =>
    base64Url.decode(base64Url.normalize(data));

/// A part's headers by lowercase name, values lowercased.
Map<String, String> _partHeaders(Map<String, dynamic> part) => {
  for (final h in part['headers'] as List? ?? const [])
    (h['name'] as String).toLowerCase(): (h['value'] as String).toLowerCase(),
};

bool _isAttachment(Map<String, dynamic> part) =>
    (part['filename'] as String? ?? '').isNotEmpty ||
    (_partHeaders(part)['content-disposition'] ?? '').startsWith('attachment');

/// Gmail HTML-escapes snippets.
String _unescape(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
