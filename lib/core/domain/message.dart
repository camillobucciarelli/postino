import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:equatable/equatable.dart';

/// A file attached to a message; [id] is the Provider's, stable for the message (Gmail: the MIME part id).
class Attachment extends Equatable {
  /// Crea un allegato.
  const Attachment({required this.id, required this.name, required this.size, this.mimeType});

  /// Id dell'allegato lato Provider.
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

  @override
  List<Object?> get props => [id, name, size, mimeType];
}

/// Tipo di Etichetta.
enum LabelKind {
  /// Etichetta: un messaggio può averne più d'una.
  etichetta,

  /// Cartella: un messaggio ne ha al massimo una.
  cartella,
}

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
class Label extends Equatable {
  /// Crea un'Etichetta.
  const Label({required this.id, required this.name, required this.kind});

  /// Id lato Provider.
  final String id;

  /// Nome mostrato.
  final String name;

  /// Se è un'Etichetta o una cartella.
  final LabelKind kind;

  @override
  List<Object?> get props => [id, name, kind];
}

/// Provider-side id of the INBOX label.
const inboxLabelId = 'INBOX';

/// Provider-side id of the Bozze label.
const draftLabelId = 'DRAFT';

/// Provider-side id of the Inviati label.
const sentLabelId = 'SENT';

/// Intestazioni di un messaggio ricevuto o sincronizzato; il corpo sta in [MessageBody].
class Message extends Equatable {
  /// Crea un messaggio; cc, bcc e references partono vuoti.
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
    this.replyTo,
    this.references = const [],
  });

  /// Provider-side id.
  final String id;

  /// RFC 5322 Message-ID header.
  final String messageId;

  /// Id della Conversazione a cui appartiene.
  final String conversationId;

  /// Id delle Etichette applicate.
  final List<String> labelIds;

  /// Se l'utente l'ha letto.
  final bool isRead;

  /// Se ha la Stella.
  final bool isStarred;

  /// The sender's address; [fromName] is its display name from the `From` header, if any.
  final String from;

  /// Nome del mittente dall'header `From`, se c'è.
  final String? fromName;

  /// `Name <address>` or a bare address each ([formatMailbox]).
  final List<String> to;

  /// Destinatari in copia, nello stesso formato di [to].
  final List<String> cc;

  /// Only the Bozze and the sent messages have one; a resumed Bozza keeps it.
  final List<String> bcc;

  /// Oggetto.
  final String subject;

  /// Anteprima del testo.
  final String snippet;

  /// Data d'invio.
  final DateTime date;

  /// The `Reply-To` mailbox ([formatMailbox]), if the header is there: a reply goes to it instead of [from] (#37).
  final String? replyTo;

  /// The Message-IDs of the `References` header, oldest first (#37).
  final List<String> references;

  @override
  List<Object?> get props => [
    id,
    messageId,
    conversationId,
    labelIds,
    isRead,
    isStarred,
    from,
    fromName,
    to,
    cc,
    bcc,
    subject,
    snippet,
    date,
    replyTo,
    references,
  ];
}

/// Formato del corpo di un messaggio.
enum BodyKind {
  /// Corpo HTML.
  html,

  /// Corpo in testo semplice.
  testo,
}

/// A downloaded message body, with whether it is HTML or plain text, and its attachments
/// (they come with the full message, as the body does).
class MessageBody extends Equatable {
  /// Crea un corpo; senza `attachments` la lista è vuota.
  const MessageBody(this.content, this.kind, {this.attachments = const []});

  /// Il contenuto, HTML o testo secondo [kind].
  final String content;

  /// Se [content] è HTML o testo semplice.
  final BodyKind kind;

  /// Null for a body stored before attachments were (database v8 and older): not known until downloaded again.
  final List<Attachment>? attachments;

  @override
  List<Object?> get props => [content, kind, attachments];
}

/// Always inside a single Account.
class Conversation extends Equatable {
  /// Crea una Conversazione.
  const Conversation({required this.id, required this.accountId, required this.messageIds});

  /// Id della Conversazione lato Provider.
  final String id;

  /// L'Account a cui appartiene.
  final String accountId;

  /// Id dei suoi messaggi.
  final List<String> messageIds;

  @override
  List<Object?> get props => [id, accountId, messageIds];
}

/// A message to send or to keep as a Bozza; [messageId] is generated on the device ([newMessageId]) and stays stable.
class OutgoingMessage extends Equatable {
  /// Crea un messaggio in uscita; cc, bcc, references e allegati partono vuoti.
  const OutgoingMessage({
    required this.messageId,
    required this.from,
    required this.to,
    required this.subject,
    required this.body,
    this.cc = const [],
    this.bcc = const [],
    this.inReplyTo,
    this.references = const [],
    this.conversationId,
    this.attachments = const [],
  });

  /// Message-ID RFC 5322 generato sul dispositivo.
  final String messageId;

  /// The address of the sending Account.
  final String from;

  /// Destinatari principali, `Name <address>` o indirizzo nudo.
  final List<String> to;

  /// Destinatari in copia.
  final List<String> cc;

  /// Destinatari in copia nascosta.
  final List<String> bcc;

  /// Oggetto.
  final String subject;

  /// HTML; the adapter derives the text/plain alternative (`htmlText`).
  final String body;

  /// A reply (#37): the Message-ID answered, the chain of `References`, and the Provider's id of the
  /// Conversazione it joins (Gmail threadId). Null and empty for a new message or a forward.
  final String? inReplyTo;

  /// Catena degli header `References`, dal più vecchio.
  final List<String> references;

  /// Id Provider della Conversazione a cui si unisce una risposta.
  final String? conversationId;

  /// Attachments taken over from another message (a forward, #37): the adapter fetches their bytes when it builds the MIME.
  final List<ForwardedAttachment> attachments;

  @override
  List<Object?> get props => [
    messageId,
    from,
    to,
    cc,
    bcc,
    subject,
    body,
    inReplyTo,
    references,
    conversationId,
    attachments,
  ];
}

/// An [Attachment] of the Provider message [sourceMessageId], re-attached to an [OutgoingMessage].
class ForwardedAttachment extends Equatable {
  /// Crea un allegato inoltrato.
  const ForwardedAttachment(this.sourceMessageId, this.attachment);

  /// Id Provider del messaggio da cui si prende l'allegato.
  final String sourceMessageId;

  /// L'allegato da rimettere nel messaggio.
  final Attachment attachment;

  @override
  List<Object?> get props => [sourceMessageId, attachment];
}

const _alphanumerics = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A fresh RFC 5322 Message-ID: `<24 random alphanumerics@domain of [address]>` (`postino.local` without one).
String newMessageId(String address) {
  final random = Random.secure();
  final local = [for (var i = 0; i < 24; i++) _alphanumerics[random.nextInt(_alphanumerics.length)]].join();
  final at = address.lastIndexOf('@');
  final domain = at < 0 ? 'postino.local' : address.substring(at + 1);
  return '<$local@$domain>';
}

/// I byte di un allegato scaricato.
typedef AttachmentBytes = Uint8List;
