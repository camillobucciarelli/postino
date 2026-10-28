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
  final String from;
  final List<String> to;
  final String subject;
  final String snippet;
  final DateTime date;
  final List<Attachment> attachments;
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
