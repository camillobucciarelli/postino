// Contatti (#216): the suggestions from the addresses seen in the mail, by prefix, merged by address,
// ranked by a score of frequency and recency where writing to someone weighs more.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/contact_ranking.dart';

final _now = DateTime.utc(2026, 11, 12, 12);

ContactSighting _seen({
  String sender = 'me@example.com',
  String? senderName,
  List<String> to = const [],
  List<String> cc = const [],
  List<String> bcc = const [],
  int daysAgo = 0,
  bool sent = false,
}) => (
  sender: sender,
  senderName: senderName,
  recipients: [...to, ...cc, ...bcc],
  date: _now.subtract(Duration(days: daysAgo)),
  sent: sent,
);

List<String> _rank(List<ContactSighting> rows, String prefix, {int limit = 6}) => [
  for (final c in rankContacts(rows, prefix: prefix, own: const {'me@example.com'}, now: _now, limit: limit))
    c.name == null ? c.address : '${c.name} <${c.address}>',
];

void main() {
  test('a prefix matches the start of the address or of any word of the name, ignoring case', () {
    final rows = [
      _seen(sender: 'maria@example.com', senderName: 'Maria Rossi'),
      _seen(sender: 'luca@example.com', senderName: 'Luca Marini'),
      _seen(sender: 'anna@example.com', senderName: 'Anna Bianchi'),
      _seen(sender: 'xmar@example.com'),
    ];
    expect(_rank(rows, 'MAR'), unorderedEquals(['Maria Rossi <maria@example.com>', 'Luca Marini <luca@example.com>']));
    expect(_rank(rows, 'luca@ex'), ['Luca Marini <luca@example.com>']);
    expect(_rank(rows, 'maria ro'), ['Maria Rossi <maria@example.com>']);
    expect(_rank(rows, ''), isEmpty);
    expect(_rank(rows, '  '), isEmpty);
  });

  test('an address seen with different case is one Contatto, with its most recent name', () {
    final rows = [
      _seen(sender: 'Maria@Example.com', senderName: 'M. Rossi', daysAgo: 10),
      _seen(to: ['Maria Rossi <maria@example.COM>'], daysAgo: 1, sent: true),
      _seen(sender: 'maria@example.com'),
    ];
    expect(_rank(rows, 'mar'), ['Maria Rossi <maria@example.com>']);
  });

  test('someone written to yesterday comes before a newsletter received every day for a year', () {
    final rows = [
      for (var d = 0; d < 365; d++) _seen(sender: 'marketing@example.com', senderName: 'Market', daysAgo: d),
      _seen(to: ['Mario <mario@example.com>'], daysAgo: 1, sent: true),
    ];
    expect(_rank(rows, 'mar'), ['Mario <mario@example.com>', 'Market <marketing@example.com>']);
  });

  test('recency decays: the same exchanges a year ago weigh less than last week', () {
    final rows = [
      for (var i = 0; i < 3; i++) _seen(to: ['old@example.com'], daysAgo: 365 + i, sent: true),
      _seen(to: ['olga@example.com'], daysAgo: 7, sent: true),
    ];
    expect(_rank(rows, 'ol'), ['olga@example.com', 'old@example.com']);
  });

  test('the recipients of a received message are Contatti too; Cc and Ccn count', () {
    final rows = [
      _seen(sender: 'ada@example.com', to: ['me@example.com', 'bo@example.com'], cc: ['cy@example.com']),
      _seen(bcc: ['dee@example.com'], sent: true),
    ];
    expect(_rank(rows, 'bo'), ['bo@example.com']);
    expect(_rank(rows, 'cy'), ['cy@example.com']);
    expect(_rank(rows, 'dee'), ['dee@example.com']);
  });

  test('the Accounts\' own addresses and the automatic ones are never suggested', () {
    final rows = [
      _seen(sender: 'ME@example.com', to: ['me@example.com']),
      for (final a in [
        'noreply@example.com',
        'no-reply@example.com',
        'notifications-noreply@example.com',
        'no_reply@example.com',
        'donotreply@example.com',
        'do-not-reply@example.com',
        'MAILER-DAEMON@example.com',
      ])
        _seen(sender: a),
      _seen(sender: 'not-an-address'),
    ];
    for (final p in ['me', 'no', 'do', 'mailer']) {
      expect(_rank(rows, p), isEmpty, reason: p);
    }
  });

  test('at most limit suggestions, best first', () {
    final rows = [for (var i = 0; i < 10; i++) _seen(sender: 'a$i@example.com', daysAgo: i)];
    expect(_rank(rows, 'a', limit: 3), ['a0@example.com', 'a1@example.com', 'a2@example.com']);
  });
}
