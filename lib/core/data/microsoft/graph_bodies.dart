import 'dart:typed_data';

import '../../domain/message.dart';
import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import 'graph_http.dart';
import 'graph_message_parser.dart';

/// The body and the attachments of one message, from Graph's JSON and not from the whole MIME (`/$value`), so a
/// body does not download its attachments too. Reading changes nothing: `isRead` stays as it is.
class GraphBodies(final GraphHttp _graph) {
  static const _html = 'outlook.body-content-type="html"';
  static const _attachmentSelect = 'id,name,contentType,size,isInline,microsoft.graph.fileAttachment/contentId';

  /// The body of message [id] as HTML (Graph converts a plain text one) and its [Attachment]s: those the user sees,
  /// not the images the HTML shows through `cid:`, as on Gmail and IMAP. An `itemAttachment` (an attached message)
  /// is `message/rfc822`; a `referenceAttachment` (a OneDrive link) is listed by name and cannot be downloaded.
  // `uniqueBody` is asked as the issue says, but the full `body` is what is shown, as on Gmail and IMAP.
  Future<MessageBody> body(String id) async {
    final j = await _graph.get('messages/$id', query: {r'$select': 'body,uniqueBody,hasAttachments'}, prefer: _html);
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
    final items = await _list(id);
    final refs = _cidRefs(html);
    return [
      for (final a in items)
        if (!_shownByHtml(a, refs))
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

  /// The attachments with their `contentId`; a Graph that refuses it on the base type (400) gives the list without,
  /// and [_shownByHtml] then goes by `isInline` alone.
  Future<List<Map<String, dynamic>>> _list(String id) async {
    try {
      return await _graph.list('messages/$id/attachments', query: {r'$select': _attachmentSelect});
    } on OAuthFailed catch (e) {
      if (e.failure is! UnexpectedFailure) rethrow;
      return _graph.list(
        'messages/$id/attachments',
        query: {r'$select': _attachmentSelect.substring(0, _attachmentSelect.lastIndexOf(','))},
      );
    }
  }

  /// The `cid:` references of [html], lowercased and each percent-decoded on its own (a malformed escape stays raw):
  /// the body as a whole is never decoded, a literal `%` in it is not an escape.
  static Set<String> _cidRefs(String html) => {
    for (final m in RegExp('cid:([^"\'\\s)>&]+)', caseSensitive: false).allMatches(html)) _decode(m[1]!.toLowerCase()),
  };

  static String _decode(String ref) {
    try {
      return Uri.decodeComponent(ref);
    } on ArgumentError {
      return ref;
    }
  }

  /// An inline attachment whose Content-ID is among the [refs] of the body (whole references, so `logo-1` is not
  /// `logo-10`): part of the body, not a file. Without a `contentId`, any reference does.
  static bool _shownByHtml(Map<String, dynamic> a, Set<String> refs) {
    if (a['isInline'] != true) return false;
    if (!a.containsKey('contentId')) return refs.isNotEmpty;
    final cid = (a['contentId'] as String?)?.toLowerCase();
    return cid != null && cid.isNotEmpty && refs.contains(cid);
  }
}
