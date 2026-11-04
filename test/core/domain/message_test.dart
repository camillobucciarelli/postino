import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/file_name.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/value_equality.dart';

void main() {
  test('newMessageId is <24 alphanumerics@domain of the address>', () {
    final id = newMessageId('ada@example.com');
    expect(id, matches(r'^<[A-Za-z0-9]{24}@example\.com>$'));
  });

  test('newMessageId falls back to postino.local without a domain', () {
    expect(newMessageId('ada'), endsWith('@postino.local>'));
  });

  test('newMessageId never repeats', () {
    final ids = {for (var i = 0; i < 1000; i++) newMessageId('a@b.it')};
    expect(ids, hasLength(1000));
  });

  test('isExecutableName goes by the last extension only (#75)', () {
    expect(isExecutableName('fattura.pdf.exe'), isTrue);
    expect(isExecutableName('Fattura.PDF'), isFalse);
    expect(isExecutableName('setup.Exe'), isTrue);
    // macOS disk images beyond .dmg (Copilot on #77).
    expect(isExecutableName('invoice.sparseimage'), isTrue);
    expect(isExecutableName('invoice.cdr'), isTrue);
    expect(isExecutableName('invoice.sparsebundle'), isTrue);
    expect(isExecutableName('invoice.toast'), isTrue);
    expect(isExecutableName('invoice.asif'), isTrue);
    expect(isExecutableName('README'), isFalse);
    expect(isExecutableName('archivio.zip'), isFalse);
    expect(isExecutableName('run.command'), isTrue);
    expect(isExecutableName('setup.exe. '), isTrue);
    expect(isExecutableName('fattura\u202Efdp.exe'), isTrue);
    expect(isExecutableName(safeFileName('fattura\u202Efdp.exe')), isTrue);
    expect(isExecutableName(safeFileName('setup.exe\u200B')), isTrue);
    expect(isExecutableName('setup.msix'), isTrue);
    expect(isExecutableName('setup.appinstaller'), isTrue);
    expect(isExecutableName('link.webloc'), isTrue);
  });

  group('value equality (#94)', () {
    test('Attachment', () {
      expectValueEquality(_attachment, [
        _attachment(id: 'p2'),
        _attachment(name: 'b.pdf'),
        _attachment(size: 4),
        _attachment(mimeType: 'application/pdf'),
      ]);
    });

    test('Label', () {
      const label = Label(id: 'L1', name: 'Lavoro', kind: LabelKind.etichetta);
      expectValueEquality(() => label, [
        const Label(id: 'L2', name: 'Lavoro', kind: LabelKind.etichetta),
        const Label(id: 'L1', name: 'Casa', kind: LabelKind.etichetta),
        const Label(id: 'L1', name: 'Lavoro', kind: LabelKind.cartella),
      ]);
    });

    test('Message', () {
      expectValueEquality(_message, [
        _message(id: '2'),
        _message(messageId: '<2@x.it>'),
        _message(conversationId: 'c2'),
        _message(labelIds: ['INBOX', 'L1']),
        _message(isRead: true),
        _message(isStarred: true),
        _message(from: 'z@x.it'),
        _message(fromName: 'Ada'),
        _message(to: ['c@x.it']),
        _message(cc: ['c@x.it']),
        _message(bcc: ['c@x.it']),
        _message(subject: 'Salve'),
        _message(snippet: 't'),
        _message(date: DateTime.utc(2026, 11, 5)),
        _message(replyTo: 'r@x.it'),
        _message(references: ['<9@x.it>']),
      ]);
    });

    test('MessageBody', () {
      MessageBody body({
        String content = 'x',
        BodyKind kind = BodyKind.html,
        List<Attachment>? attachments = const [],
      }) => MessageBody(
        content,
        kind,
        attachments: attachments == null
            ? null
            : [_attachment(), ...attachments],
      );
      expectValueEquality(body, [
        body(content: 'y'),
        body(kind: BodyKind.testo),
        body(attachments: [_attachment(id: 'p2')]),
        const MessageBody('x', BodyKind.html, attachments: null),
      ]);
    });

    test('Conversation', () {
      Conversation c({
        String id = 'c1',
        String accountId = 'a1',
        List<String> ids = const ['1', '2'],
      }) => Conversation(id: id, accountId: accountId, messageIds: [...ids]);
      expectValueEquality(c, [
        c(id: 'c2'),
        c(accountId: 'a2'),
        c(ids: ['1', '3']),
      ]);
    });

    test('OutgoingMessage', () {
      expectValueEquality(_outgoing, [
        _outgoing(messageId: '<3@x.it>'),
        _outgoing(from: 'z@x.it'),
        _outgoing(to: ['c@x.it']),
        _outgoing(cc: ['c@x.it']),
        _outgoing(bcc: ['c@x.it']),
        _outgoing(subject: 'Fwd: Ciao'),
        _outgoing(body: '<p>no</p>'),
        _outgoing(inReplyTo: '<0@x.it>'),
        _outgoing(references: ['<0@x.it>']),
        _outgoing(conversationId: 'c9'),
        _outgoing(
          attachments: [ForwardedAttachment('1', _attachment(id: 'p2'))],
        ),
      ]);
    });

    test('ForwardedAttachment', () {
      expectValueEquality(() => ForwardedAttachment('1', _attachment()), [
        ForwardedAttachment('2', _attachment()),
        ForwardedAttachment('1', _attachment(size: 9)),
      ]);
    });
  });
}

Message _message({
  String id = '1',
  String messageId = '<1@x.it>',
  String conversationId = 'c1',
  List<String> labelIds = const ['INBOX'],
  bool isRead = false,
  bool isStarred = false,
  String from = 'a@x.it',
  String? fromName,
  List<String> to = const ['b@x.it'],
  List<String> cc = const [],
  List<String> bcc = const [],
  String subject = 'Ciao',
  String snippet = 's',
  DateTime? date,
  String? replyTo,
  List<String> references = const [],
}) => Message(
  id: id,
  messageId: messageId,
  conversationId: conversationId,
  labelIds: [...labelIds],
  isRead: isRead,
  isStarred: isStarred,
  from: from,
  fromName: fromName,
  to: [...to],
  cc: [...cc],
  bcc: [...bcc],
  subject: subject,
  snippet: snippet,
  date: date ?? DateTime.utc(2026, 11, 4),
  replyTo: replyTo,
  references: [...references],
);

OutgoingMessage _outgoing({
  String messageId = '<2@x.it>',
  String from = 'a@x.it',
  List<String> to = const ['b@x.it'],
  List<String> cc = const [],
  List<String> bcc = const [],
  String subject = 'Re: Ciao',
  String body = '<p>ok</p>',
  String? inReplyTo,
  List<String> references = const [],
  String? conversationId,
  List<ForwardedAttachment>? attachments,
}) => OutgoingMessage(
  messageId: messageId,
  from: from,
  to: [...to],
  cc: [...cc],
  bcc: [...bcc],
  subject: subject,
  body: body,
  inReplyTo: inReplyTo,
  references: [...references],
  conversationId: conversationId,
  attachments: attachments ?? [ForwardedAttachment('1', _attachment())],
);

Attachment _attachment({
  String id = 'p1',
  String name = 'a.pdf',
  int size = 3,
  String? mimeType,
}) => Attachment(id: id, name: name, size: size, mimeType: mimeType);
