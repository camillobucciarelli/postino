import 'dart:typed_data';

import '../../domain/message.dart';
import 'graph_http.dart';
import 'graph_message_parser.dart';

/// The body and the attachments of one message, from Graph's JSON and not from the whole MIME (`/$value`), so a
/// body does not download its attachments too. Reading changes nothing: `isRead` stays as it is.
class GraphBodies(final GraphHttp _graph) {
  static const _html = 'outlook.body-content-type="html"';
  static const _attachmentSelect = 'id,name,contentType,size,isInline,contentId';

  /// The body of message [id] as HTML (Graph converts a plain text one) and its [Attachment]s: those the user sees,
  /// not the images the HTML shows through `cid:`, as on Gmail and IMAP. An `itemAttachment` (an attached message)
  /// is `message/rfc822`; a `referenceAttachment` (a OneDrive link) is listed by name and cannot be downloaded.
  // ponytail: `uniqueBody` (without the quoted replies) is not asked: the full body is what Gmail and IMAP show.
  Future<MessageBody> body(String id) async {
    final j = await _graph.get('messages/$id', query: {r'$select': 'body,hasAttachments'}, prefer: _html);
    final body = graphBody(j) ?? const MessageBody('', BodyKind.testo);
    final attachments = j['hasAttachments'] == true ? await _attachments(id, body.content) : const <Attachment>[];
    return MessageBody(body.content, body.kind, attachments: attachments);
  }

  /// The bytes of attachment [attachmentId] of message [id], `onProgress` out of `Content-Length`.
  Future<Uint8List> attachment(
    String id,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final bytes = await _graph.getBytes(
      'messages/$id/attachments/$attachmentId/\$value',
      onProgress: onProgress,
      cancel: cancel,
    );
    onProgress?.call(1);
    return bytes;
  }

  Future<List<Attachment>> _attachments(String id, String html) async {
    final items = await _graph.list('messages/$id/attachments', query: {r'$select': _attachmentSelect});
    final lower = html.toLowerCase();
    return [
      for (final a in items)
        if (!_shownByHtml(a, lower))
          Attachment(
            id: a['id'] as String,
            name: a['name'] as String? ?? '',
            size: a['size'] as int? ?? 0,
            mimeType: a['@odata.type'] == '#microsoft.graph.itemAttachment'
                ? 'message/rfc822'
                : a['contentType'] as String?,
          ),
    ];
  }

  /// An inline attachment whose Content-ID the [lowerHtml] refers to as `cid:`: part of the body, not a file.
  static bool _shownByHtml(Map<String, dynamic> a, String lowerHtml) {
    final cid = (a['contentId'] as String?)?.toLowerCase();
    return a['isInline'] == true && cid != null && cid.isNotEmpty && lowerHtml.contains('cid:$cid');
  }
}
