// A FETCHed MimeMessage as a Message: headers, flags, body, and the `cartella/UIDVALIDITY/UID` id.
import 'package:enough_mail/enough_mail.dart' show MessageFlags, MimeMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_message_parser.dart';
import 'package:postino/core/domain/message.dart';

const _raw =
    'From: =?UTF-8?Q?Ada_Okafor?= <ada@example.com>\r\n'
    'To: me@example.com, "Lenti, Marco" <marco@example.com>\r\n'
    'Cc: carla@example.org\r\n'
    'Reply-To: Uffici <uffici@example.com>\r\n'
    'Subject: =?UTF-8?Q?Re:_Novit=C3=A0?=\r\n'
    'Date: Thu, 01 Jan 2026 00:00:00 +0000\r\n'
    'Message-ID: <b@example.com>\r\n'
    'In-Reply-To: <a@example.com>\r\n'
    'References: <root@example.com>\r\n <a@example.com>\r\n'
    'MIME-Version: 1.0\r\n'
    'Content-Type: text/html; charset=utf-8\r\n'
    '\r\n'
    '<p>Ciao <b>Marco</b></p>\r\n';

void main() {
  test('the id holds the folder path, slashes too', () {
    final id = imapMessageId('Viaggi/2026', 7, 42);
    expect(id, 'Viaggi/2026/7/42');
    expect(parseImapMessageId(id), (path: 'Viaggi/2026', uidValidity: 7, uid: 42));
    for (final bad in ['a', 'INBOX/x/1', 'INBOX/1', '/1/2']) {
      expect(parseImapMessageId(bad), isNull, reason: bad);
    }
  });

  test('headers, flags and the inbox body', () {
    final mime = MimeMessage.parseFromText(_raw)
      ..flags = [MessageFlags.seen, MessageFlags.flagged]
      ..uid = 42;
    final p = parseImapMessage(mime, id: 'INBOX/7/42', labelId: inboxLabelId, withBody: true);
    final m = p.message;
    expect((m.id, m.messageId, m.conversationId), ('INBOX/7/42', '<b@example.com>', ''));
    expect(m.labelIds, [inboxLabelId, starredLabelId]);
    expect((m.isRead, m.isStarred), (true, true));
    expect((m.from, m.fromName), ('ada@example.com', 'Ada Okafor'));
    expect(m.to, ['me@example.com', '"Lenti, Marco" <marco@example.com>']);
    expect(m.cc, ['carla@example.org']);
    expect(m.replyTo, 'Uffici <uffici@example.com>');
    expect(m.subject, 'Re: Novità');
    expect(m.date, DateTime.utc(2026));
    expect(m.references, ['<root@example.com>', '<a@example.com>']);
    expect(m.snippet, 'Ciao Marco');
    expect(p.inReplyTo, '<a@example.com>');
    expect((p.body!.content.trim(), p.body!.kind), ('<p>Ciao <b>Marco</b></p>', BodyKind.html));
  });

  test('headers only: no body, no snippet; unread without the Stella', () {
    final mime = MimeMessage.parseFromText(_raw)..flags = [];
    final p = parseImapMessage(mime, id: 'Sent/7/1', labelId: sentLabelId);
    expect((p.body, p.message.snippet), (null, ''));
    expect(p.message.labelIds, [sentLabelId]);
    expect((p.message.isRead, p.message.isStarred), (false, false));
  });
}
