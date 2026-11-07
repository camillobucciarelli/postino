import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart'
    show BinaryMimeData, BodyPart, ImapClient, MailCodec, MimePart, TextMimeData;

import '../../domain/message.dart';
import '../../domain/result.dart';
import 'imap_body_structure.dart';
import 'imap_failure.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';

/// What the user opens a message for, fetched on request: the text and the attachment list of a message, and one
/// attachment at a time. Nothing marks a message as read: `BODY.PEEK` only.
class ImapBodies(final ImapSession _session) {
  /// Bytes per FETCH of an attachment: short commands, and room for other commands between them.
  static const _chunk = 256 * 1024;

  /// The body of [messageId]: BODYSTRUCTURE first, then the text part alone (HTML, else plain text), never the
  /// attachments. [NotFoundFailure] when the message or its folder is gone.
  Future<MessageBody> body(String messageId) => _session.run((c) async {
    final id = await _open(c, messageId);
    return readBody(c, id.uid);
  });

  /// One attachment of [messageId] ([Attachment.id], the part number), decoded. A chunk per command and a command at
  /// a time, so the folder's other commands (a sync) go on between chunks; [cancel] stops it between two chunks with
  /// [CancelledFailure], the connection idle.
  Future<Uint8List> attachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    var cancelled = false;
    unawaited(cancel?.then((_) => cancelled = true));
    void checkCancelled() {
      if (cancelled) throw const ImapFailed(CancelledFailure());
    }

    final part = await _session.run((c) async {
      final id = await _open(c, messageId);
      final parts = structureParts(await _structure(c, id.uid));
      final part = parts.where((p) => p.id == attachmentId).firstOrNull;
      return part == null ? throw const ImapFailed(NotFoundFailure()) : (part, id);
    });
    final (info, id) = part;
    final bytes = BytesBuilder(copy: false);
    while (true) {
      checkCancelled();
      final got = await _session.run((c) async {
        await _open(c, messageId);
        final r = await c.uidFetchMessage(
          id.uid,
          '(UID BODY.PEEK[${info.id}]<${bytes.length}.$_chunk>)',
          responseTimeout: ImapSession.timeout,
        );
        final m = r.messages.firstOrNull ?? (throw const ImapFailed(NotFoundFailure()));
        return _raw(m.getPart(info.id));
      });
      bytes.add(got);
      if (got.length < _chunk || (info.wireSize > 0 && bytes.length >= info.wireSize)) break;
      if (info.wireSize > 0) onProgress?.call(min(0.99, bytes.length / info.wireSize));
    }
    checkCancelled();
    onProgress?.call(1);
    return _decode(bytes.takeBytes(), info.encoding);
  }

  /// Selects the folder of [messageId]; the UID is no longer ours when its UIDVALIDITY changed.
  Future<({String path, int uidValidity, int uid})> _open(ImapClient c, String messageId) async {
    final id = parseImapMessageId(messageId) ?? (throw const ImapFailed(NotFoundFailure()));
    final box = await selectFolder(c, id.path, condstore: _session.condstore);
    if ((box.uidValidity ?? 0) != id.uidValidity) throw const ImapFailed(NotFoundFailure());
    return id;
  }
}

/// The [MessageBody] of the message [uid] in the selected folder: its text (HTML if there is one, else plain; empty
/// with none) and its attachments.
Future<MessageBody> readBody(ImapClient c, int uid) async {
  final parts = structureParts(await _structure(c, uid));
  final attachments = imapAttachments(parts);
  final html = textPartOf(parts, 'text/html');
  final text = html ?? textPartOf(parts, 'text/plain');
  if (text == null) return MessageBody('', BodyKind.testo, attachments: attachments);
  final r = await c.uidFetchMessage(uid, '(UID BODY.PEEK[${text.id}])', responseTimeout: ImapSession.timeout);
  final raw = _raw((r.messages.firstOrNull ?? (throw const ImapFailed(NotFoundFailure()))).getPart(text.id));
  return MessageBody(
    MailCodec.decodeAsText(raw, text.encoding, text.charset),
    html == null ? BodyKind.testo : BodyKind.html,
    attachments: attachments,
  );
}

Future<BodyPart> _structure(ImapClient c, int uid) async {
  final r = await c.uidFetchMessage(uid, '(UID BODYSTRUCTURE)', responseTimeout: ImapSession.timeout);
  return r.messages.firstOrNull?.body ?? (throw const ImapFailed(NotFoundFailure()));
}

/// What the server sent for a part, as it is on the wire.
Uint8List _raw(MimePart? part) => switch (part?.mimeData) {
  BinaryMimeData(:final data) => data,
  TextMimeData(:final text) => Uint8List.fromList(utf8.encode(text)),
  _ => Uint8List(0),
};

/// [wire] undone by its [encoding]: base64 and quoted-printable are text on the wire; the others are the bytes.
Uint8List _decode(Uint8List wire, String? encoding) => switch (encoding) {
  'base64' || 'quoted-printable' => MailCodec.decodeBinary(latin1.decode(wire), encoding),
  _ => wire,
};
