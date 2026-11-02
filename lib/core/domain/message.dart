import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

/// A file attached to a message; [id] is the Provider's, stable for the message (Gmail: the MIME part id).
class Attachment {
  const Attachment({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
  });
  final String id;

  /// Empty when the message gives none.
  final String name;

  /// Bytes, as the Provider reports it.
  final int size;

  /// `application/pdf`…, if the Provider says it.
  final String? mimeType;

  /// `.pdf` for a nameless attachment of a well-known type, else empty: its file still opens in the right app.
  String get fallbackExtension => _extensions[mimeType?.toLowerCase()] ?? '';

  // ponytail: the common types only; add one when a nameless attachment of another type shows up.
  static const _extensions = {
    'application/pdf': '.pdf',
    'text/plain': '.txt',
    'text/html': '.html',
    'text/calendar': '.ics',
    'text/csv': '.csv',
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'application/zip': '.zip',
    'message/rfc822': '.eml',
  };
}

enum LabelKind { etichetta, cartella }

/// Whether [name] is something the OS would run rather than show (#75): its last extension (case-insensitive,
/// after Windows' trailing dots and spaces) names a script, an executable, an installer (`.msix`, `.appinstaller`),
/// a disk image (every type DiskImageMounter registers) or a launcher of URLs and commands (`.url`, `.webloc`, `.desktop`, `.terminal`).
/// `.py`/`.rb`/`.pl` left out on purpose (they open in an editor).
bool isExecutableName(String name) {
  final s = name.replaceAll(RegExp(r'[. ]+$'), '');
  final dot = s.lastIndexOf('.');
  return dot >= 0 && _executable.contains(s.substring(dot + 1).toLowerCase());
}

const _executable = {
  'exe',
  'com',
  'bat',
  'cmd',
  'scr',
  'pif',
  'msi',
  'msp',
  'dll',
  'cpl',
  'lnk',
  'reg',
  'ps1',
  'psm1',
  'vbs',
  'vbe',
  'js',
  'jse',
  'wsf',
  'wsh',
  'hta',
  'jar',
  'sh',
  'bash',
  'zsh',
  'command',
  'tool',
  'app',
  'action',
  'workflow',
  'scpt',
  'applescript',
  'dmg',
  'sparseimage',
  'sparsebundle',
  'cdr',
  'udif',
  'dvdr',
  'asif',
  'toast',
  'dmgpart',
  'backupbundle',
  'pkg',
  'mpkg',
  'iso',
  'img',
  'deb',
  'rpm',
  'run',
  'apk',
  'ipa',
  'msix',
  'appx',
  'msixbundle',
  'appxbundle',
  'appinstaller',
  'application',
  'appref-ms',
  'chm',
  'msc',
  'sct',
  'wsc',
  'terminal',
  'desktop',
  'url',
  'webloc',
  'inetloc',
};

/// Per Account; on folder-based Providers a message has at most one.
class Label {
  const Label({required this.id, required this.name, required this.kind});
  final String id;
  final String name;
  final LabelKind kind;
}

/// Provider-side id of the INBOX label.
const inboxLabelId = 'INBOX';

/// Provider-side id of the Bozze label.
const draftLabelId = 'DRAFT';

class Message {
  const Message({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.labelIds,
    required this.isRead,
    required this.isStarred,
    required this.from,
    required this.to,
    required this.subject,
    required this.snippet,
    required this.date,
    this.fromName,
    this.cc = const [],
    this.bcc = const [],
  });

  /// Provider-side id.
  final String id;

  /// RFC 5322 Message-ID header.
  final String messageId;
  final String conversationId;
  final List<String> labelIds;
  final bool isRead;
  final bool isStarred;

  /// The sender's address; [fromName] is its display name from the `From` header, if any.
  final String from;
  final String? fromName;

  /// `Name <address>` or a bare address each ([formatMailbox]).
  final List<String> to;
  final List<String> cc;

  /// Only the Bozze and the sent messages have one; a resumed Bozza keeps it.
  final List<String> bcc;
  final String subject;
  final String snippet;
  final DateTime date;
}

enum BodyKind { html, testo }

/// A downloaded message body, with whether it is HTML or plain text, and its attachments
/// (they come with the full message, as the body does).
class MessageBody {
  const MessageBody(this.content, this.kind, {this.attachments = const []});
  final String content;
  final BodyKind kind;

  /// Null for a body stored before attachments were (database v8 and older): not known until downloaded again.
  final List<Attachment>? attachments;
}

/// Always inside a single Account.
class Conversation {
  const Conversation({
    required this.id,
    required this.accountId,
    required this.messageIds,
  });
  final String id;
  final String accountId;
  final List<String> messageIds;
}

/// A message to send or to keep as a Bozza; [messageId] is generated on the device ([newMessageId]) and stays stable.
class OutgoingMessage {
  const OutgoingMessage({
    required this.messageId,
    required this.from,
    required this.to,
    required this.subject,
    required this.body,
    this.cc = const [],
    this.bcc = const [],
  });
  final String messageId;

  /// The address of the sending Account.
  final String from;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;

  /// HTML; the adapter derives the text/plain alternative (`htmlText`).
  final String body;
}

const _alphanumerics =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A fresh RFC 5322 Message-ID: `<24 random alphanumerics@domain of [address]>` (`postino.local` without one).
String newMessageId(String address) {
  final random = Random.secure();
  final local = [
    for (var i = 0; i < 24; i++)
      _alphanumerics[random.nextInt(_alphanumerics.length)],
  ].join();
  final at = address.lastIndexOf('@');
  final domain = at < 0 ? 'postino.local' : address.substring(at + 1);
  return '<$local@$domain>';
}

typedef AttachmentBytes = Uint8List;
