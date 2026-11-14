// The search on the Provider on servers GreenMail is not (#208): PARTIAL (RFC 9394) and not, a folder that never
// answers, the folders asked. Recorded responses; the commands are what is checked.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/recorded_imap_server.dart';

const _account = 'icloud:ada@icloud.com';
const _folders = [
  (r'\HasNoChildren', 'INBOX'),
  (r'\HasNoChildren \Archive', 'Archive'),
  (r'\HasNoChildren \Sent', 'Sent'),
  (r'\HasNoChildren \Drafts', 'Drafts'),
  (r'\HasNoChildren \Trash', 'Trash'),
  (r'\HasNoChildren \Junk', 'Junk'),
  (r'\HasNoChildren', 'Work'),
];

/// The UIDs of each folder, all of them matches whatever the SEARCH says: the Date of UID n is the n-th of October,
/// so a higher UID is a later message.
class _Mailbox(
  final String capabilities,
  final Map<String, List<int>> uids, {

  /// Folders whose SEARCH is never answered.
  final Set<String> slow = const {},

  /// INBOX's UID 1 answers a message that is not here: its parent is looked up.
  final bool reply = false,

  /// After a SEARCH that never answers, the next connection's CAPABILITY does not either.
  final bool stuckAfterwards = false,

  /// Called on every LIST.
  final void Function()? onList,
}) {
  var _hung = false;

  var _selected = '';

  List<String> answer(String command) {
    if (command.toUpperCase().startsWith('LIST')) onList?.call();
    if (_hung && command.toUpperCase().startsWith('CAPABILITY')) return hang;
    if (basics(command, capabilities: capabilities, folders: _folders) case final b?) return b;
    final upper = command.toUpperCase();
    if (upper.startsWith('SELECT')) {
      _selected = RegExp('SELECT "?([^" ]+)').firstMatch(command)![1]!;
      return ['* 1 EXISTS', '* OK [UIDVALIDITY 7] valid', '* OK [UIDNEXT 999] next', 'OK [READ-WRITE] done'];
    }
    if (upper.startsWith('UID SEARCH')) {
      if (slow.contains(_selected)) {
        _hung = stuckAfterwards;
        return hang;
      }
      final below = int.tryParse(RegExp(r'UID 1:(\d+)').firstMatch(command)?[1] ?? '');
      final found = [
        for (final u in uids[_selected] ?? const <int>[])
          if (below == null || u <= below) u,
      ]..sort();
      if (command.contains('RETURN (PARTIAL -1:-51)')) {
        final last = found.skip(found.length > 51 ? found.length - 51 : 0).join(',');
        return ['* ESEARCH (TAG "x") UID PARTIAL (-1:-51 ${found.isEmpty ? 'NIL' : last})'];
      }
      return found.isEmpty ? ['* SEARCH'] : ['* SEARCH ${found.join(' ')}'];
    }
    if (upper.startsWith('UID FETCH')) {
      final wanted = RegExp(r'UID FETCH ([\d,]+) ').firstMatch(command)![1]!.split(',').map(int.parse);
      return [
        for (final (i, u) in wanted.indexed)
          '* ${i + 1} FETCH (UID $u FLAGS () INTERNALDATE "01-Nov-2026 10:00:00 +0000" BODY[HEADER] ${literal(_header(u))})',
      ];
    }
    return ['OK done'];
  }

  String _header(int u) =>
      'From: Ada <ada@example.com>\r\nSubject: Fattura $u\r\nDate: ${u.clamp(1, 28)} Oct 2026 10:00:00 +0000\r\n'
      'Message-ID: <$_selected-$u@example.com>\r\n${reply && _selected == 'INBOX' && u == 1 ? 'In-Reply-To: <parent@example.com>\r\n' : ''}\r\n';
}

Future<(ImapProvider, RecordedImapServer)> _setUp(_Mailbox mailbox, {FakeClock? clock}) async {
  final server = await RecordedImapServer.start(mailbox.answer);
  addTearDown(server.stop);
  final keychain = FakeSecureStore();
  await server.remember(keychain, _account);
  final p = ImapProvider(
    _account,
    'ada@icloud.com',
    keychain,
    clock ?? FakeClock(DateTime.utc(2026, 11, 6)),
    connect: plainConnector,
    searchTimeout: const Duration(milliseconds: 400),
  );
  addTearDown(p.close);
  return (p, server);
}

Iterable<String> _searches(RecordedImapServer s) => s.commands.where((c) => c.startsWith('UID SEARCH'));

const _query = SearchQuery(terms: ['fattura']);

void main() {
  test('with PARTIAL: the newest 51 of each folder, merged by date; never Cestino, Spam nor Bozze', () async {
    final (p, server) = await _setUp(
      _Mailbox('IMAP4rev1 ESEARCH PARTIAL', {
        'INBOX': [1, 5],
        'Archive': [3],
        'Sent': [4],
        'Work': [2],
        'Trash': [9],
        'Junk': [9],
        'Drafts': [9],
      }),
    );
    final page = okValue(await p.search(_query));
    expect(page.messages.map((m) => m.subject), ['Fattura 5', 'Fattura 4', 'Fattura 3', 'Fattura 2', 'Fattura 1']);
    expect(page.nextPageToken, isNull);
    expect(_searches(server).toSet(), {'UID SEARCH RETURN (PARTIAL -1:-51) CHARSET UTF-8 NOT DELETED TEXT "fattura"'});
    expect(_searches(server), hasLength(4), reason: 'INBOX, Archive, Sent and Work only');
    final selected = server.commands.where((c) => c.startsWith('SELECT')).join(' ');
    expect(selected, isNot(anyOf(contains('Trash'), contains('Junk'), contains('Drafts'))));
  });

  test('a message of the page that is stored is not returned, its Conversazione is', () async {
    final (p, _) = await _setUp(
      _Mailbox('IMAP4rev1', {
        'INBOX': [1, 2],
      }),
    );
    final page = okValue(await p.search(_query, stored: {'INBOX/7/2'}));
    expect(page.messages.map((m) => m.id), ['INBOX/7/1']);
    expect(page.conversationIds, {'<INBOX-1@example.com>', '<INBOX-2@example.com>'});
  });

  for (final partial in [true, false]) {
    test('${partial ? 'with' : 'without'} PARTIAL: 50 a folder a page, the token goes on below the last UID', () async {
      final (p, server) = await _setUp(
        _Mailbox(partial ? 'IMAP4rev1 ESEARCH PARTIAL' : 'IMAP4rev1', {
          'INBOX': [for (var i = 1; i <= 120; i++) i],
          'Work': [1000, 1001],
        }),
      );
      final ids = <String>[];
      String? token;
      var pages = 0;
      do {
        final page = okValue(await p.search(_query, pageToken: token));
        ids.addAll(page.messages.map((m) => m.id));
        token = page.nextPageToken;
        pages++;
      } while (token != null && pages < 10);
      expect(pages, 3, reason: '50, 50 and 20 of the inbox');
      expect(ids, hasLength(122));
      expect(ids.toSet(), hasLength(122), reason: 'each match once');
      expect(_searches(server).where((c) => c.contains('UID 1:70')), isNotEmpty);
      expect(_searches(server).where((c) => c.contains('UID 1:20')), isNotEmpty);
      expect(
        server.commands.where((c) => c.startsWith('SELECT')).where((c) => c.contains('Work')),
        hasLength(1),
        reason: 'a folder with nothing more is not asked again',
      );
    });
  }

  test('a folder that never answers is left out; the others answer', () async {
    final (p, _) = await _setUp(
      _Mailbox(
        'IMAP4rev1',
        {
          'INBOX': [1],
          'Archive': [2],
          'Sent': [3],
        },
        slow: {'Archive'},
      ),
    );
    final page = okValue(await p.search(_query));
    expect(page.messages.map((m) => m.subject), ['Fattura 3', 'Fattura 1']);
  });

  test('the parent of a reply is not looked for in a folder that just timed out, nor in Cestino', () async {
    final (p, server) = await _setUp(
      _Mailbox(
        'IMAP4rev1',
        {
          'INBOX': [1],
          'Archive': [2],
          'Trash': [5],
        },
        slow: {'Archive'},
        reply: true,
      ),
    );
    okValue(await p.search(_query));
    final selected = server.commands.where((c) => c.startsWith('SELECT')).join(' ');
    expect('Archive'.allMatches(selected), hasLength(1), reason: 'the search itself, not the lookup');
    expect(selected, isNot(contains('Trash')));
    expect(server.commands.where((c) => c.contains('Message-ID "<parent@example.com>"')), isNotEmpty);
  });

  test('a new connection that does not log in in time costs its folders, not the results already found', () async {
    final (p, _) = await _setUp(
      _Mailbox(
        'IMAP4rev1',
        {
          'INBOX': [1],
          'Archive': [2],
          'Sent': [3],
        },
        slow: {'Archive'},
        stuckAfterwards: true,
      ),
    );
    final page = okValue(await p.search(_query));
    expect(page.messages.map((m) => m.subject), ['Fattura 1']);
  });

  test('every folder slower than the timeout: not "no results" but OfflineFailure', () async {
    final (p, _) = await _setUp(
      _Mailbox(
        'IMAP4rev1',
        {
          'INBOX': [1],
        },
        slow: {'INBOX', 'Archive', 'Sent', 'Work'},
      ),
    );
    expect(await p.search(_query), isErr<OfflineFailure>());
  });

  test(
    'the 13 s budget runs on the Provider\'s clock: spent during the LIST, every folder is the next page\'s',
    () async {
      final clock = FakeClock(DateTime.utc(2026, 11, 6));
      final (p, server) = await _setUp(
        _Mailbox('IMAP4rev1', {
          'INBOX': [1],
        }, onList: () => clock.current = clock.current.add(const Duration(seconds: 14))),
        clock: clock,
      );
      final page = okValue(await p.search(_query));
      expect(page.messages, isEmpty);
      expect(page.nextPageToken, isNotNull);
      expect(_searches(server), isEmpty);
    },
  );

  test('a page token that is not ours is NotFound', () async {
    final (p, _) = await _setUp(_Mailbox('IMAP4rev1', const {}));
    expect(await p.search(_query, pageToken: 'nope'), isErr<NotFoundFailure>());
  });

  test('nothing to look for: no command at all', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1', const {}));
    expect(okValue(await p.search(const SearchQuery())).messages, isEmpty);
    expect(server.commands, isEmpty);
  });
}
