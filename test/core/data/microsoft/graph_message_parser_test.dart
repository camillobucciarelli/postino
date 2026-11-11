// A Graph message (test/fixtures/graph) as a Message and its body.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/json_objects.dart';
import 'package:postino/core/data/microsoft/graph_message_parser.dart';
import 'package:postino/core/domain/message.dart';

import '../../../support/graph_recorded.dart';

Map<String, dynamic> _fixtureMessage(String fixture, int i) {
  final j = jsonDecode(File('test/fixtures/graph/$fixture.json').readAsStringSync()) as Map<String, dynamic>;
  return jsonObjects((j['body'] as Map<String, dynamic>)['value'])[i];
}

void main() {
  test('the headers: addresses, Conversazione, Message-ID, date, read state', () {
    final m = parseGraphMessage(_fixtureMessage('messages_page1', 0), labelId: inboxLabelId);
    expect(m.id, messageIdOf('f1'));
    expect(m.messageId, '<f1@mail.example.com>');
    expect(m.conversationId, 'conv-c1');
    expect(m.labelIds, [inboxLabelId]);
    expect((m.from, m.fromName), ('bruno@example.com', 'Bruno Verdi'));
    expect(m.to, [
      'Ada Lovelace <ada@outlook.com>',
      'carla@example.org',
    ], reason: 'Outlook repeats the address as the name when there is none');
    expect(m.cc, ['"Rossi, Carla" <carla.rossi@example.org>']);
    expect(m.subject, 'Cena di venerdì');
    expect(m.snippet, 'Porto io il vino & il dolce.');
    expect(m.date, DateTime.utc(2026, 10, 26, 8, 15, 2));
    expect((m.isRead, m.isStarred), (false, false));
  });

  test('a flagged message has the Stella, in the folder it is in', () {
    final j = _fixtureMessage('delta_inbox_changes', 2);
    final m = parseGraphMessage(j, labelId: 'folder');
    expect((m.isRead, m.isStarred), (true, true));
    expect(m.labelIds, ['folder', starredLabelId]);
  });

  test('the body: HTML or text; with attachments, their list is not known yet', () {
    final html = graphBody(_fixtureMessage('messages_page1', 0))!;
    expect(html.kind, BodyKind.html);
    expect(html.content, contains('Porto io il vino'));
    expect(html.attachments, isEmpty);
    final text = graphBody(_fixtureMessage('messages_page1', 1))!;
    expect(text.kind, BodyKind.testo);
    expect(text.content, 'Il tuo biglietto è allegato.');
    expect(text.attachments, isNull, reason: 'hasAttachments: downloaded with the body on request (T3)');
  });

  test('no body selected, no body', () {
    expect(graphBody(_fixtureMessage('delta_viaggi_moved', 0)), isNull);
  });
}
