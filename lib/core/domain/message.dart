import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:equatable/equatable.dart';

/// A file attached to a message; [id] is the Provider's, stable for the message (Gmail: the MIME part id).
class const Attachment({
  /// Id dell'allegato lato Provider.
  required final String id,

  /// Empty when the message gives none.
  required final String name,

  /// Bytes, as the Provider reports it.
  required final int size,

  /// `application/pdf`…, if the Provider says it.
  final String? mimeType,
}) extends Equatable {
  /// Crea un allegato.
  this;

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
enum LabelKind() {
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
class const Label({
  /// Id lato Provider.
  required final String id,

  /// Nome mostrato.
  required final String name,

  /// Se è un'Etichetta o una cartella.
  required final LabelKind kind,
}) extends Equatable {
  /// Crea un'Etichetta.
  this;

  @override
  List<Object?> get props => [id, name, kind];
}

/// Provider-side id of the INBOX label.
const inboxLabelId = 'INBOX';

/// Provider-side id of the Bozze label.
const draftLabelId = 'DRAFT';

/// Provider-side id of the Inviati label.
const sentLabelId = 'SENT';

/// Provider-side id of the label of the messages with the Stella.
const starredLabelId = 'STARRED';

/// Provider-side id of the Cestino label: where Elimina puts a message.
const trashLabelId = 'TRASH';

/// Provider-side id of the Spam label: a message there is in no view (no Spam view yet), not in the inbox.
const spamLabelId = 'SPAM';

/// Intestazioni di un messaggio ricevuto o sincronizzato; il corpo sta in [MessageBody].
class const Message({
  /// Provider-side id.
  required final String id,

  /// RFC 5322 Message-ID header.
  required final String messageId,

  /// Id della Conversazione a cui appartiene.
  required final String conversationId,

  /// Id delle Etichette applicate.
  required final List<String> labelIds,

  /// Se l'utente l'ha letto.
  required final bool isRead,

  /// Se ha la Stella.
  required final bool isStarred,

  /// The sender's address; [fromName] is its display name from the `From` header, if any.
  required final String from,

  /// `Name <address>` or a bare address each (`formatMailbox`).
  required final List<String> to,

  /// Oggetto.
  required final String subject,

  /// Anteprima del testo.
  required final String snippet,

  /// Data d'invio.
  required final DateTime date,

  /// Nome del mittente dall'header `From`, se c'è.
  final String? fromName,

  /// Destinatari in copia, nello stesso formato di [to].
  final List<String> cc = const [],

  /// Only the Bozze and the sent messages have one; a resumed Bozza keeps it.
  final List<String> bcc = const [],

  /// The `Reply-To` mailbox (`formatMailbox`), if the header is there: a reply goes to it instead of [from] (#37).
  final String? replyTo,

  /// The Message-IDs of the `References` header, oldest first (#37).
  final List<String> references = const [],
}) extends Equatable {
  /// Crea un messaggio; cc, bcc e references partono vuoti.
  this;

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
enum BodyKind() {
  /// Corpo HTML.
  html,

  /// Corpo in testo semplice.
  testo,
}

/// A downloaded message body, with whether it is HTML or plain text, and its attachments
/// (they come with the full message, as the body does).
class const MessageBody(
  /// Il contenuto, HTML o testo secondo [kind].
  final String content,

  /// Se [content] è HTML o testo semplice.
  final BodyKind kind, {

  /// Null for a body stored before attachments were (database v8 and older): not known until downloaded again.
  final List<Attachment>? attachments = const [],
}) extends Equatable {
  /// Crea un corpo; senza `attachments` la lista è vuota.
  this;

  @override
  List<Object?> get props => [content, kind, attachments];
}

/// Always inside a single Account.
class const Conversation({
  /// Id della Conversazione lato Provider.
  required final String id,

  /// L'Account a cui appartiene.
  required final String accountId,

  /// Id dei suoi messaggi.
  required final List<String> messageIds,
}) extends Equatable {
  /// Crea una Conversazione.
  this;

  @override
  List<Object?> get props => [id, accountId, messageIds];
}

/// A message to send or to keep as a Bozza; [messageId] is generated on the device ([newMessageId]) and stays stable.
class const OutgoingMessage({
  /// Message-ID RFC 5322 generato sul dispositivo.
  required final String messageId,

  /// The address of the sending Account.
  required final String from,

  /// Destinatari principali, `Name <address>` o indirizzo nudo.
  required final List<String> to,

  /// Oggetto.
  required final String subject,

  /// HTML; the adapter derives the text/plain alternative (`htmlText`).
  required final String body,

  /// Destinatari in copia.
  final List<String> cc = const [],

  /// Destinatari in copia nascosta.
  final List<String> bcc = const [],

  /// A reply (#37): the Message-ID answered, the chain of `References`, and the Provider's id of the
  /// Conversazione it joins (Gmail threadId). Null and empty for a new message or a forward.
  final String? inReplyTo,

  /// Catena degli header `References`, dal più vecchio.
  final List<String> references = const [],

  /// Id Provider della Conversazione a cui si unisce una risposta.
  final String? conversationId,

  /// Attachments taken over from another message (a forward, #37): the adapter fetches their bytes when it builds the MIME.
  final List<ForwardedAttachment> attachments = const [],
}) extends Equatable {
  /// Crea un messaggio in uscita; cc, bcc, references e allegati partono vuoti.
  this;

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
class const ForwardedAttachment(
  /// Id Provider del messaggio da cui si prende l'allegato.
  final String sourceMessageId,

  /// L'allegato da rimettere nel messaggio.
  final Attachment attachment,
) extends Equatable {
  /// Crea un allegato inoltrato.
  this;

  @override
  List<Object?> get props => [sourceMessageId, attachment];
}

const _alphanumerics = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A fresh RFC 5322 Message-ID: `<24 random alphanumerics@domain of [address]>` (`postino.local` without one, or
/// with a domain that is not ASCII).
String newMessageId(String address) {
  final random = Random.secure();
  final local = [for (var i = 0; i < 24; i++) _alphanumerics[random.nextInt(_alphanumerics.length)]].join();
  final at = address.lastIndexOf('@');
  final domain = at < 0 ? '' : address.substring(at + 1);
  // ASCII only (RFC 5322 msg-id): an IMAP SEARCH must find it again; an IDN domain is not punycoded here.
  if (!RegExp(r'^[\x21-\x7e]+$').hasMatch(domain)) return '<$local@postino.local>';
  return '<$local@$domain>';
}

/// I byte di un allegato scaricato.
typedef AttachmentBytes = Uint8List;
