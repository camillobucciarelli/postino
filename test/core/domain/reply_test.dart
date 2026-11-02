// The pure reply builder (#37): subjects, recipients, the quoted original, the threading headers.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/html_text.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/reply.dart';

import '../../support/fake_mail_provider.dart';

const _self = 'me@example.com';

void main() {
  group('subject', () {
    test('Re: and Fwd: on a bare subject, trimmed when empty', () {
      expect(replySubject('Caffè'), 'Re: Caffè');
      expect(forwardSubject('Caffè'), 'Fwd: Caffè');
      expect(replySubject(''), 'Re:');
      expect(forwardSubject('  '), 'Fwd:');
    });

    test(
      'every leading prefix of the five kinds goes, any case, also repeated',
      () {
        for (final s in [
          'Re: x',
          'RE:x',
          'R: x',
          'Fwd: x',
          'FW: x',
          'I: x',
          'RE: R: Fwd:  x',
          ' re:x',
        ]) {
          expect(replySubject(s), 'Re: x', reason: s);
          expect(forwardSubject(s), 'Fwd: x', reason: s);
        }
      },
    );

    test('a prefix inside the subject stays', () {
      expect(replySubject('Report: x'), 'Re: Report: x');
      expect(replySubject('x Re: y'), 'Re: x Re: y');
    });
  });

  group('recipients', () {
    test('a reply goes to the sender with its name, Reply-To wins', () {
      final m = msg('m', from: 'ada@example.com', fromName: 'Ada');
      expect(replyRecipients(m, self: _self), ['Ada <ada@example.com>']);
      final r = msg(
        'm',
        from: 'ada@example.com',
        fromName: 'Ada',
        replyTo: 'list@example.com',
      );
      expect(replyRecipients(r, self: _self), ['list@example.com']);
    });

    test('a reply to all keeps the sender and the To in to, the Cc in cc, without self', () {
      final m = msg(
        'm',
        from: 'ada@example.com',
        to: ['Me <ME@example.com>', 'bruno@example.com'],
        cc: ['carla@example.com', _self],
      );
      final r = replyAllRecipients(m, self: _self);
      expect(r.to, ['ada@example.com', 'bruno@example.com']);
      expect(r.cc, ['carla@example.com']);
    });

    test('a reply to all keeps both the Reply-To and the sender in to, Reply-To first', () {
      final m = msg(
        'm',
        from: 'ada@example.com',
        replyTo: 'list@example.com',
        to: ['bruno@example.com'],
      );
      expect(replyAllRecipients(m, self: _self).to, [
        'list@example.com',
        'ada@example.com',
        'bruno@example.com',
      ]);
    });

    test('duplicates by address go, first occurrence wins, to before cc', () {
      final m = msg(
        'm',
        from: 'ada@example.com',
        fromName: 'Ada',
        to: [
          'Ada Okafor <ada@example.com>',
          'bruno@example.com',
          'Bruno <BRUNO@example.com>',
        ],
        cc: ['bruno@example.com', 'carla@example.com'],
      );
      final r = replyAllRecipients(m, self: _self);
      expect(r.to, ['Ada <ada@example.com>', 'bruno@example.com']);
      expect(r.cc, ['carla@example.com']);
    });

    test('a reply to all of one\'s own message goes to its recipients', () {
      final m = msg(
        'm',
        from: _self,
        to: ['bruno@example.com'],
        cc: ['carla@example.com'],
      );
      final r = replyAllRecipients(m, self: _self);
      expect(r.to, ['bruno@example.com']);
      expect(r.cc, ['carla@example.com']);
      expect(replyRecipients(m, self: _self), ['bruno@example.com']);
      final toSelf = msg('m', from: _self, to: [_self]);
      expect(replyAllRecipients(toSelf, self: _self).to, [_self]);
    });
  });

  group('quote', () {
    test('attribution line with name and address escaped, the HTML in a blockquote', () {
      final m = msg('m', from: 'ada@example.com', fromName: 'Ada & C. <x>');
      expect(
        quoteHtml(
          m,
          dateLabel: '1 gen 2026, 10:00',
          bodyHtml: '<p>Ciao <b>tu</b></p>',
        ),
        '<div class="postino-quote"><p>Il giorno 1 gen 2026, 10:00, '
        'Ada &amp; C. &lt;x&gt; &lt;ada@example.com&gt; ha scritto:</p>'
        '<blockquote><p>Ciao <b>tu</b></p></blockquote></div>',
      );
    });

    test('a nameless sender is just the address', () {
      final m = msg('m', from: 'ada@example.com');
      expect(
        quoteHtml(m, dateLabel: 'd', bodyHtml: ''),
        contains(', ada@example.com ha scritto:'),
      );
    });

    test('a plain-text original is converted before being quoted', () {
      final m = msg('m');
      final html = quoteHtml(
        m,
        dateLabel: 'd',
        bodyHtml: plainToHtml('a < b\n\nc'),
      );
      expect(
        html,
        contains('<blockquote><p>a &lt; b</p><p>c</p></blockquote>'),
      );
    });
  });

  test('the forward header lists Da, Data, Oggetto, A and Cc, then the HTML unquoted', () {
    final m = msg(
      'm',
      from: 'ada@example.com',
      fromName: 'Ada',
      to: ['Me <me@example.com>'],
      cc: ['carla@example.com'],
      subject: 'Oggetto <1>',
    );
    expect(
      forwardHeaderHtml(m, dateLabel: 'd', bodyHtml: '<p>x</p>'),
      '<div class="postino-forward"><p>---------- Messaggio inoltrato ----------'
      '<br>Da: Ada &lt;ada@example.com&gt;<br>Data: d<br>Oggetto: Oggetto &lt;1&gt;'
      '<br>A: Me &lt;me@example.com&gt;<br>Cc: carla@example.com</p><p>x</p></div>',
    );
    expect(
      forwardHeaderHtml(msg('m'), dateLabel: 'd', bodyHtml: ''),
      isNot(contains('Cc:')),
    );
  });

  group('buildReply', () {
    final original = msg(
      'm',
      from: 'ada@example.com',
      to: [_self, 'bruno@example.com'],
      cc: ['carla@example.com'],
      subject: 'Re: Caffè',
      references: ['<a@example.com>', '<m@example.com>'],
      conversationId: 't-1',
    );

    test('threads by In-Reply-To, References chained without duplicates, and the Conversazione', () {
      final r = buildReply(
        original: original,
        originalHtml: '<p>x</p>',
        self: _self,
        messageId: '<new@example.com>',
        all: false,
        dateLabel: 'd',
      );
      expect(r.messageId, '<new@example.com>');
      expect(r.from, _self);
      expect(r.to, ['ada@example.com']);
      expect(r.cc, isEmpty);
      expect(r.bcc, isEmpty);
      expect(r.subject, 'Re: Caffè');
      expect(r.body, startsWith('<p><br></p><div class="postino-quote">'));
      expect(r.body, contains('<blockquote><p>x</p></blockquote>'));
      expect(r.inReplyTo, '<m@example.com>');
      expect(r.references, ['<a@example.com>', '<m@example.com>']);
      expect(r.conversationId, 't-1');
      expect(r.attachments, isEmpty);
    });

    test('to all: to and cc as replyAllRecipients', () {
      final r = buildReply(
        original: original,
        originalHtml: '',
        self: _self,
        messageId: '<new@example.com>',
        all: true,
        dateLabel: 'd',
      );
      expect(r.to, ['ada@example.com', 'bruno@example.com']);
      expect(r.cc, ['carla@example.com']);
    });

    test('an original without Message-ID is not threaded by headers', () {
      final r = buildReply(
        original: Message(
          id: 'm',
          messageId: '',
          conversationId: 't',
          labelIds: const [],
          isRead: true,
          isStarred: false,
          from: 'ada@example.com',
          to: const [],
          subject: 's',
          snippet: '',
          date: DateTime.utc(2026),
        ),
        originalHtml: '',
        self: _self,
        messageId: '<new@example.com>',
        all: false,
        dateLabel: 'd',
      );
      expect(r.inReplyTo, isNull);
      expect(r.references, isEmpty);
      expect(r.conversationId, 't');
    });
  });

  test('buildForward: no recipients, Fwd: subject, header block, attachments taken over, not threaded', () {
    const pdf = Attachment(
      id: '1',
      name: 'a.pdf',
      size: 3,
      mimeType: 'application/pdf',
    );
    final f = buildForward(
      original: msg(
        'm',
        subject: 'Fwd: Caffè',
        references: ['<a@example.com>'],
      ),
      originalHtml: '<p>x</p>',
      self: _self,
      messageId: '<new@example.com>',
      dateLabel: 'd',
      attachments: const [pdf],
    );
    expect(f.to, isEmpty);
    expect(f.cc, isEmpty);
    expect(f.subject, 'Fwd: Caffè');
    expect(f.body, startsWith('<p><br></p><div class="postino-forward">'));
    expect(f.body, endsWith('<p>x</p></div>'));
    expect(f.inReplyTo, isNull);
    expect(f.references, isEmpty);
    expect(f.conversationId, isNull);
    expect(f.attachments.single.sourceMessageId, 'm');
    expect(f.attachments.single.attachment, same(pdf));
  });
}
