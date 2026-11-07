// IMAP Conversazioni rebuilt from References, In-Reply-To and the normalized subject (#28 «Thread»).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_threads.dart';
import 'package:postino/core/domain/message.dart';

import '../../../support/fake_mail_provider.dart' show msg;

const _me = 'me@example.com';

ThreadInput _t(Message m, [String? inReplyTo]) => (message: m, inReplyTo: inReplyTo);

Map<String, String> _threads(List<ThreadInput> all) => {
  for (final m in threadMessages(all, known: all, address: _me)) m.id: m.conversationId,
};

void main() {
  test('the subject loses its reply and forward prefixes, in English, Italian and German', () {
    for (final s in [
      'Pranzo',
      'Re: Pranzo',
      'RE: R: Fwd: pranzo',
      'I: Pranzo',
      'AW:  Pranzo',
      'Re[2]: Pranzo',
      'Fw: Pranzo',
    ]) {
      expect(normalizedSubject(s), 'pranzo', reason: s);
    }
    expect(hasReplyPrefix('Pranzo'), isFalse);
    expect(hasReplyPrefix('Ricevuta'), isFalse);
  });

  test('a reply with References joins the root, whatever came in between', () {
    final root = msg('a', date: DateTime.utc(2026, 10));
    final reply = msg('b', subject: 'Re: Oggetto', references: const ['<a@example.com>', '<x@example.com>']);
    expect(_threads([_t(reply), _t(root)]), {'a': '<a@example.com>', 'b': '<a@example.com>'});
  });

  test('a reply with only In-Reply-To joins its parent, also one with References of its own', () {
    final parent = msg('p', references: const ['<root@example.com>'], date: DateTime.utc(2026, 10));
    final reply = msg('r', subject: 'Re: Oggetto', date: DateTime.utc(2026, 10, 2));
    expect(_threads([_t(parent), _t(reply, '<p@example.com>')])['r'], '<root@example.com>');
    // Its parent unknown: the parent's Message-ID, as the parent's own root would be.
    expect(_threads([_t(reply, '<p@example.com>')])['r'], '<p@example.com>');
  });

  test('a reply without references joins the same subject within the window, with a participant in common', () {
    final first = msg('a', subject: 'Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10));
    final reply = msg(
      'b',
      subject: 'Re: Pranzo',
      from: _me,
      to: const ['Bob <bob@example.com>'],
      date: DateTime.utc(2026, 10, 2),
    );
    final again = msg('c', subject: 'R: Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10, 3));
    expect(_threads([_t(first), _t(reply), _t(again)]), {
      'a': '<a@example.com>',
      'b': '<a@example.com>',
      'c': '<a@example.com>',
    });
  });

  test('two exchanges with the same subject and other people stay apart; the Account itself does not count', () {
    final bob = msg('a', subject: 'Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10));
    final carla = msg('c', subject: 'Pranzo', from: 'carla@example.com', date: DateTime.utc(2026, 10, 2));
    final toCarla = msg(
      'd',
      subject: 'Re: Pranzo',
      from: _me,
      to: const ['carla@example.com'],
      date: DateTime.utc(2026, 10, 3),
    );
    expect(_threads([_t(bob), _t(carla), _t(toCarla)]), {
      'a': '<a@example.com>',
      'c': '<c@example.com>',
      'd': '<c@example.com>',
    });
  });

  test('outside the window, or without a reply prefix, the same subject is a new Conversazione', () {
    final old = msg('a', subject: 'Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 8));
    final late = msg('b', subject: 'Re: Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10));
    final plain = msg('c', subject: 'Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10, 2));
    expect(_threads([_t(old), _t(late), _t(plain)]), {
      'a': '<a@example.com>',
      'b': '<b@example.com>',
      'c': '<c@example.com>',
    });
  });

  test('the id is the same from one sync to the next: a later batch with the root only known', () {
    final root = msg('a', subject: 'Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10));
    final reply = msg('b', subject: 'Re: Pranzo', from: 'bob@example.com', date: DateTime.utc(2026, 10, 2));
    final first = _threads([_t(root), _t(reply)]);
    final later = threadMessages([_t(reply)], known: [_t(reply), _t(root)], address: _me).single;
    expect(later.conversationId, first['b']);
  });

  test('a loop of In-Reply-To ends; a message without Message-ID is its own Conversazione', () {
    final a = msg('a');
    final b = msg('b');
    expect(_threads([_t(a, '<b@example.com>'), _t(b, '<a@example.com>')]).values, everyElement(isNotEmpty));
    final bare = Message(
      id: 'INBOX/1/9',
      messageId: '',
      conversationId: '',
      labelIds: const [inboxLabelId],
      isRead: false,
      isStarred: false,
      from: 'x@example.com',
      to: const [],
      subject: 's',
      snippet: '',
      date: DateTime.utc(2026),
    );
    expect(_threads([_t(bare)]), {'INBOX/1/9': 'INBOX/1/9'});
  });
}
