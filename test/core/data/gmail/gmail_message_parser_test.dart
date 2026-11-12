// Gmail message resources (test/fixtures/gmail) parsed into domain entities: no HTTP.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/gmail/gmail_message_parser.dart';
import 'package:postino/core/domain/message.dart';

Map<String, dynamic> _message(String name) =>
    (jsonDecode(File('test/fixtures/gmail/$name.json').readAsStringSync()) as Map<String, dynamic>)['body']
        as Map<String, dynamic>;

Map<String, dynamic> _payload(String name) => _message(name)['payload'] as Map<String, dynamic>;

void main() {
  test('headers, labels and snippet become a Message', () {
    final m = parseGmailMessage(_message('message_f1'));
    expect((m.id, m.conversationId), ('18f3a2b4c5d6e7f1', '18f3a2b4c5d6e7f1'));
    expect((m.from, m.fromName), ('bruno@example.com', 'Bruno Verdi'));
    expect(m.to, ['ada@gmail.com', 'carla@example.org']);
    expect(m.cc, ['"Rossi, Carla" <carla.rossi@example.org>', 'Nicolò Neri <nicolo@example.com>']);
    expect(m.subject, 'Cena di venerdì');
    expect((m.isRead, m.isStarred), (false, false));
    expect(m.snippet, endsWith('Porto io il vino & il dolce.'));
    expect(m.date, DateTime.fromMillisecondsSinceEpoch(1793002502000, isUtc: true));
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
    final big = gmailBodyPart(_payload('message_f5_attachment_body'), 'text/plain');
    expect((big?['body'] as Map<String, dynamic>)['attachmentId'], isNotNull);
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

  test('the body: HTML over text, attachments only, or none', () {
    final f1 = _payload('message_f1');
    final html = gmailTextPart(f1);
    expect(html?['partId'], '1');
    final body = gmailBody(f1, html, 'PGI-Y2lhbzwvYj4');
    expect((body?.kind, body?.content), (BodyKind.html, '<b>ciao</b>'));
    final plain = gmailTextPart(_payload('message_f6_html_attachment'));
    expect(gmailBody(_payload('message_f6_html_attachment'), plain, 'Y2lhbw')?.kind, BodyKind.testo);
    // Attachments and no text part: an empty body; nothing at all: none.
    final f7 = _payload('message_f7_attachments');
    expect(gmailBody(f7, null, null)?.attachments, hasLength(3));
    expect(gmailBody(const {}, null, null), isNull);
  });

  test('has attachments: exact from the parts, a guess from the top-level type alone, unknown with neither (#206)', () {
    expect(parseGmailMessage(_message('message_f7_attachments')).hasAttachments, isTrue);
    expect(parseGmailMessage(_message('message_f1')).hasAttachments, isFalse);
    // `format=metadata`: no parts, only the type of the whole.
    Map<String, dynamic> metadata(Map<String, dynamic> payload) => {
      ..._message('message_f1'),
      'payload': {'headers': (_payload('message_f1')['headers'] as List), ...payload},
    };
    expect(parseGmailMessage(metadata({'mimeType': 'multipart/mixed'})).hasAttachments, isTrue);
    expect(parseGmailMessage(metadata({'mimeType': 'multipart/alternative'})).hasAttachments, isFalse);
    expect(parseGmailMessage(metadata(const {})).hasAttachments, isNull);
  });
}
