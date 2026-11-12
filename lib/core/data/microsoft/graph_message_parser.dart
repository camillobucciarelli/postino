import '../../domain/mailbox.dart';
import '../../domain/message.dart';
import '../json_objects.dart';

/// The message properties a sync asks for: no body, which only the inbox adds ([graphBodySelect]).
const graphMessageSelect =
    'id,internetMessageId,conversationId,parentFolderId,isRead,flag,from,replyTo,toRecipients,ccRecipients,'
    'bccRecipients,subject,bodyPreview,receivedDateTime,hasAttachments';

/// [graphMessageSelect] with the body: the inbox ones come with the sync (ADR 0003).
const graphBodySelect = '$graphMessageSelect,body';

/// A Graph message as a [Message] in the folder whose Etichetta is [labelId]; the Stella is a flagged message.
Message parseGraphMessage(Map<String, dynamic> j, {required String labelId}) {
  final from = _mailbox(j['from']);
  final starred = (j['flag'] as Map<String, dynamic>?)?['flagStatus'] == 'flagged';
  return Message(
    id: j['id'] as String,
    messageId: j['internetMessageId'] as String? ?? '',
    conversationId: j['conversationId'] as String? ?? j['id'] as String,
    labelIds: [labelId, if (starred) starredLabelId],
    isRead: j['isRead'] as bool? ?? false,
    isStarred: starred,
    from: from?.address ?? '',
    fromName: from?.name,
    to: _recipients(j['toRecipients']),
    cc: _recipients(j['ccRecipients']),
    bcc: _recipients(j['bccRecipients']),
    replyTo: _recipients(j['replyTo']).firstOrNull,
    subject: j['subject'] as String? ?? '',
    snippet: j['bodyPreview'] as String? ?? '',
    date: DateTime.parse(j['receivedDateTime'] as String).toUtc(),
    hasAttachments: j['hasAttachments'] as bool?,
  );
}

/// The body of a message fetched with [graphBodySelect]; null without one. Its attachments are not listed by the
/// sync: a message that has some keeps them unknown (null) until its body is downloaded again.
MessageBody? graphBody(Map<String, dynamic> j) {
  final body = j['body'] as Map<String, dynamic>?;
  if (body == null) return null;
  return MessageBody(
    body['content'] as String? ?? '',
    body['contentType'] == 'html' ? BodyKind.html : BodyKind.testo,
    attachments: j['hasAttachments'] == true ? null : const [],
  );
}

List<String> _recipients(Object? json) => [for (final r in jsonObjects(json)) ?_mailbox(r)].map(formatMailbox).toList();

/// A Graph `recipient` (`{emailAddress: {name, address}}`); Outlook repeats the address as the name when there is none.
Mailbox? _mailbox(Object? json) {
  final e = (json as Map<String, dynamic>?)?['emailAddress'] as Map<String, dynamic>?;
  final address = (e?['address'] as String?)?.trim();
  if (address == null || address.isEmpty) return null;
  final name = (e?['name'] as String?)?.trim();
  return (name: name == null || name.isEmpty || name == address ? null : name, address: address);
}
