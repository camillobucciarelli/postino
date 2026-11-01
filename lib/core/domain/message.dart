import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

class Attachment {
  const Attachment({required this.id, required this.name, required this.size});
  final String id;
  final String name;
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
    this.attachments = const [],
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
  final List<Attachment> attachments;
}

enum BodyKind { html, testo }

/// A downloaded message body, with whether it is HTML or plain text.
class MessageBody {
  const MessageBody(this.content, this.kind);
  final String content;
  final BodyKind kind;
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
