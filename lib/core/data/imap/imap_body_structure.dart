import 'package:enough_mail/enough_mail.dart' show BodyPart, ContentDisposition, MailCodec, MediaSubtype, MimePart;

import '../../domain/message.dart';

/// A leaf of a message's MIME tree: what tells a text part from an attachment and what a download needs.
typedef PartInfo = ({
  /// The IMAP part number (`1`, `2.1`): what `BODY[...]` fetches.
  String id,

  /// Lowercase `type/subtype`.
  String type,
  ContentDisposition? disposition,

  /// Empty when the part gives none.
  String name,
  bool hasContentId,

  /// Bytes of the content: exact from a whole message, estimated from a BODYSTRUCTURE (which gives the
  /// transfer-encoded size).
  int size,

  /// Bytes of the part as the server sends it (transfer-encoded); 0 when unknown.
  int wireSize,

  /// The `Content-Transfer-Encoding`, lowercase.
  String? encoding,
  String? charset,
});

// ponytail: a multipart that is itself an attachment is descended (enough_mail does not read the disposition of a
// multipart from a BODYSTRUCTURE); its text could pass for the message's. Rare; skip it by name if it shows up.
/// The leaves of a BODYSTRUCTURE, numbered as IMAP does; a nested message (`message/rfc822`) is a leaf, not descended.
List<PartInfo> structureParts(BodyPart root) {
  final out = <PartInfo>[];
  void walk(BodyPart p, String id) {
    final kids = p.parts;
    if (kids != null && kids.isNotEmpty && p.contentType?.mediaType.sub != MediaSubtype.messageRfc822) {
      for (var i = 0; i < kids.length; i++) {
        walk(kids[i], id.isEmpty ? '${i + 1}' : '$id.${i + 1}');
      }
      return;
    }
    final encoding = p.encoding?.toLowerCase();
    out.add((
      id: id.isEmpty ? '1' : id,
      type: p.contentType?.mediaType.text.toLowerCase() ?? 'text/plain',
      disposition: p.contentDisposition?.disposition,
      name: _name(p.contentDisposition?.filename, p.contentType?.parameters['name']),
      hasContentId: p.cid != null,
      // The size the sender wrote in Content-Disposition, if any, else the estimate.
      size: p.contentDisposition?.size ?? _decodedSize(p.size ?? 0, encoding),
      wireSize: p.size ?? 0,
      encoding: encoding,
      charset: p.contentType?.charset,
    ));
  }

  walk(root, '');
  return out;
}

/// The leaves of a whole message, numbered as [structureParts] does, sized by their decoded content.
List<PartInfo> mimeParts(MimePart root) {
  final out = <PartInfo>[];
  void walk(MimePart p, String id) {
    final kids = p.parts;
    if (kids != null && kids.isNotEmpty && p.mediaType.sub != MediaSubtype.messageRfc822) {
      for (var i = 0; i < kids.length; i++) {
        walk(kids[i], id.isEmpty ? '${i + 1}' : '$id.${i + 1}');
      }
      return;
    }
    final type = p.getHeaderContentType();
    final disposition = p.getHeaderContentDisposition();
    out.add((
      id: id.isEmpty ? '1' : id,
      type: p.mediaType.text.toLowerCase(),
      disposition: disposition?.disposition,
      name: _name(disposition?.filename, type?.parameters['name']),
      hasContentId: p.getHeaderValue('content-id') != null,
      size: p.decodeContentBinary()?.length ?? 0,
      wireSize: 0,
      encoding: p.getHeaderValue('content-transfer-encoding')?.toLowerCase(),
      charset: type?.charset,
    ));
  }

  walk(root, '');
  return out;
}

/// The parts the user sees as attachments, as Gmail decides (`gmailAttachmentParts`) so the rendering does not know
/// the Provider: a filename (an empty file too) or `Content-Disposition: attachment` with content, but an image the
/// HTML shows through `cid:` (a Content-ID, not marked `attachment`) belongs to the body.
List<Attachment> imapAttachments(List<PartInfo> parts) => [
  for (final p in parts)
    if (_isAttachment(p) && (p.name.isNotEmpty || p.size > 0) && (!p.hasContentId || _marked(p)))
      Attachment(id: p.id, name: p.name, size: p.size, mimeType: p.type),
];

/// The first part of [type] with content that is not an attachment: an attached `report.html` is not the text.
PartInfo? textPartOf(List<PartInfo> parts, String type) =>
    parts.where((p) => p.type == type && !_isAttachment(p) && p.size > 0).firstOrNull;

bool _marked(PartInfo p) => p.disposition == ContentDisposition.attachment;

bool _isAttachment(PartInfo p) => p.name.isNotEmpty || _marked(p);

String _name(String? disposition, String? type) => MailCodec.decodeHeader(disposition ?? type) ?? '';

/// The content size from the transfer-encoded [size]: base64 is 4 characters per 3 bytes, 76 to a line, plus the
/// line break. Within the padding (2 bytes) of the real one.
int _decodedSize(int size, String? encoding) {
  if (encoding != 'base64') return size;
  final lines = (size + 77) ~/ 78;
  return (size - 2 * lines) * 3 ~/ 4;
}
