// Gmail message resources (test/fixtures/gmail) parsed into domain entities: no HTTP.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/gmail/gmail_message_parser.dart';

Map<String, dynamic> _message(String name) =>
    jsonDecode(
          File('test/fixtures/gmail/$name.json').readAsStringSync(),
        )['body']
        as Map<String, dynamic>;

Map<String, dynamic> _payload(String name) =>
    _message(name)['payload'] as Map<String, dynamic>;

void main() {
  test('headers, labels and snippet become a Message', () {
    final m = parseGmailMessage(_message('message_f1'));
    expect((m.id, m.conversationId), ('18f3a2b4c5d6e7f1', '18f3a2b4c5d6e7f1'));
    expect((m.from, m.fromName), ('bruno@example.com', 'Bruno Verdi'));
    expect(m.to, ['ada@gmail.com', 'carla@example.org']);
    expect(m.cc, [
      '"Rossi, Carla" <carla.rossi@example.org>',
      'Nicolò Neri <nicolo@example.com>',
    ]);
    expect(m.subject, 'Cena di venerdì');
    expect((m.isRead, m.isStarred), (false, false));
    expect(m.snippet, endsWith('Porto io il vino & il dolce.'));
    expect(
      m.date,
      DateTime.fromMillisecondsSinceEpoch(1793002502000, isUtc: true),
    );
  });

  test('the body part: HTML first, else plain text, never an attachment', () {
    final f1 = _payload('message_f1');
    expect(gmailBodyPart(f1, 'text/html')?['partId'], '1');
    expect(gmailBodyPart(f1, 'text/plain')?['partId'], '0');
    // The HTML of f6 is an attached file, not the body.
    final f6 = _payload('message_f6_html_attachment');
    expect(gmailBodyPart(f6, 'text/html'), isNull);
    expect(gmailBodyPart(f6, 'text/plain')?['partId'], '0');
    // A big body comes by attachmentId.
    expect(
      gmailBodyPart(
        _payload('message_f5_attachment_body'),
        'text/plain',
      )?['body']['attachmentId'],
      isNotNull,
    );
  });

  test('attachments: named, unnamed, empty; a cid: image is body', () {
    final a = gmailAttachments(_payload('message_f7_attachments'));
    expect(
      [for (final x in a) (x.id, x.name, x.size, x.mimeType)],
      [
        ('1', 'Preventivo 2027.pdf', 49, 'application/pdf'),
        ('2', '', 3, 'text/plain'),
        ('3', 'vuoto.txt', 0, 'text/plain'),
      ],
    );
  });

  test('base64url data decodes with or without padding', () {
    expect(utf8.decode(decodeGmailData('Y2lhbw')), 'ciao');
    expect(utf8.decode(decodeGmailData('Y2lhbw==')), 'ciao');
  });
}
