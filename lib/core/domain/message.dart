import 'dart:typed_data' show Uint8List;

/// A file attached to a message; [id] is the Provider's, stable for the message (Gmail: the MIME part id).
class Attachment {
  const Attachment({required this.id, required this.name, required this.size});
  final String id;
  final String name;

  /// Bytes, as the Provider reports it.
  final int size;
}

enum LabelKind { etichetta, cartella }

/// Per Account; on folder-based Providers a message has at most one.
class Label {
  const Label({required this.id, required this.name, required this.kind});
  final String id;
  final String name;
  final LabelKind kind;
}

/// Provider-side id of the INBOX label.
const inboxLabelId = 'INBOX';

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

/// A message to send or to keep as a draft; [messageId] is generated on the device and stays stable.
class OutgoingMessage {
  const OutgoingMessage({
    required this.messageId,
    required this.to,
    required this.subject,
    required this.body,
  });
  final String messageId;
  final List<String> to;
  final String subject;
  final String body;
}

typedef AttachmentBytes = Uint8List;
