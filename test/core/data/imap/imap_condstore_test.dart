// The incremental sync on servers with CONDSTORE and QRESYNC (RFC 7162), against recorded IMAP responses:
// GreenMail announces neither, so the suite on it covers only the UID/flag fallback.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/recorded_imap_server.dart';

const _account = 'icloud:ada@icloud.com';

String _header(int n) =>
    'From: bob@example.com\r\n'
    'To: ada@icloud.com\r\n'
    'Subject: Messaggio $n\r\n'
    'Date: Sun, 01 Nov 2026 10:00:00 +0000\r\n'
    'Message-ID: <m$n@example.com>\r\n'
    'Content-Type: text/plain; charset=utf-8\r\n'
    '\r\n';

String _fetch(int seq, int uid, String flags, String part, String text, int modSeq) =>
    '* $seq FETCH (UID $uid FLAGS ($flags) INTERNALDATE "01-Nov-2026 10:00:00 +0000" MODSEQ ($modSeq) '
    '$part ${literal(text)})';

/// One INBOX, first with UIDs 1 and 2 at HIGHESTMODSEQ 100; then 1 expunged, 2 read and starred, 3 new: 105.
class _Mailbox() {
  var modSeq = 100;
  var uidNext = 3;

  List<String> answer(String command, {required bool qresync}) {
    final caps = 'IMAP4rev1 IDLE ENABLE CONDSTORE${qresync ? ' QRESYNC' : ''}';
    if (basics(command, capabilities: caps) case final b?) return b;
    final upper = command.toUpperCase();
    if (upper.startsWith('SELECT')) {
      return [
        r'* FLAGS (\Seen \Flagged \Deleted \Draft \Answered)',
        '* ${uidNext - 1} EXISTS',
        '* OK [UIDVALIDITY 7] UIDs valid',
        '* OK [UIDNEXT $uidNext] next',
        '* OK [HIGHESTMODSEQ $modSeq] highest',
        'OK [READ-WRITE] SELECT completed',
      ];
    }
    if (upper.startsWith('UID SEARCH SINCE')) return ['* SEARCH 1 2'];
    if (upper.startsWith('UID SEARCH UID 3:*')) return ['* SEARCH 3'];
    if (upper.startsWith('UID SEARCH UID 1:2')) return ['* SEARCH 2'];
    // The third round: nothing changed since 105.
    if (upper.startsWith('UID SEARCH UID 2:3')) return ['* SEARCH 2 3'];
    if (upper.startsWith('UID SEARCH UID 4:*')) return ['* SEARCH 3'];
    if (upper.contains('CHANGEDSINCE 105')) return <String>[];
    if (upper.contains('CHANGEDSINCE 100 VANISHED')) {
      return ['* VANISHED (EARLIER) 1', r'* 1 FETCH (UID 2 FLAGS (\Seen \Flagged) MODSEQ (104))'];
    }
    if (upper.contains('CHANGEDSINCE 100')) return [r'* 1 FETCH (UID 2 FLAGS (\Seen \Flagged) MODSEQ (104))'];
    if (upper.startsWith('UID FETCH 2,1 ') || upper.startsWith('UID FETCH 1:2 ')) {
      return [
        _fetch(1, 1, '', 'BODY[]', '${_header(1)}Uno\r\n', 90),
        _fetch(2, 2, '', 'BODY[]', '${_header(2)}Due\r\n', 95),
      ];
    }
    if (upper.startsWith('UID FETCH 2 ')) {
      return [_fetch(1, 2, r'\Seen \Flagged', 'BODY[]', '${_header(2)}Due\r\n', 104)];
    }
    if (upper.startsWith('UID FETCH 3 ')) return [_fetch(2, 3, '', 'BODY[]', '${_header(3)}Tre\r\n', 105)];
    return ['BAD unexpected $command'];
  }
}

void main() {
  for (final qresync in [true, false]) {
    final name = qresync ? 'QRESYNC' : 'CONDSTORE without QRESYNC';

    test('$name: only what changed since HIGHESTMODSEQ, the UIDs gone, the new ones; then nothing', () async {
      final mailbox = _Mailbox();
      final server = await RecordedImapServer.start((c) => mailbox.answer(c, qresync: qresync));
      addTearDown(server.stop);
      final keychain = FakeSecureStore();
      await server.remember(keychain, _account);
      final p = ImapProvider(
        _account,
        'ada@icloud.com',
        keychain,
        FakeClock(DateTime.utc(2026, 11, 6)),
        connect: plainConnector,
      );
      addTearDown(p.close);

      final first = okValue(await p.initialSync());
      expect(first.messages.map((m) => m.id), ['INBOX/7/2', 'INBOX/7/1']);
      expect(first.bodies.keys, unorderedEquals(['INBOX/7/1', 'INBOX/7/2']));
      expect(server.commands, contains(startsWith('SELECT "INBOX" (CONDSTORE)')));
      expect(server.commands.contains('ENABLE QRESYNC'), qresync);

      mailbox
        ..modSeq = 105
        ..uidNext = 4;
      server.commands.clear();
      final next = okValue(await p.incrementalSync(first.cursor));
      expect(next.removedMessageIds, ['INBOX/7/1']);
      final byId = {for (final m in next.messages) m.id: m};
      expect(byId.keys, ['INBOX/7/2', 'INBOX/7/3']);
      expect((byId['INBOX/7/2']!.isRead, byId['INBOX/7/2']!.isStarred), (true, true));
      expect(byId['INBOX/7/2']!.labelIds, [inboxLabelId, starredLabelId]);
      // The changed one comes whole too, as on Gmail: its snippet stays.
      expect(next.bodies.keys, ['INBOX/7/2', 'INBOX/7/3']);
      expect(byId['INBOX/7/2']!.snippet, 'Due');
      expect(
        server.commands,
        contains(
          qresync ? 'UID FETCH 1:2 (FLAGS) (CHANGEDSINCE 100 VANISHED)' : 'UID FETCH 1:2 (FLAGS) (CHANGEDSINCE 100)',
        ),
      );
      // Never the flags of every known message: that is the fallback's.
      expect(server.commands, isNot(contains('UID FETCH 1:2 (UID FLAGS)')));

      server.commands.clear();
      final again = okValue(await p.incrementalSync(next.cursor));
      expect(again.messages, isEmpty);
      expect(again.removedMessageIds, isEmpty);
      expect(again.cursor, next.cursor);
      // QRESYNC: HIGHESTMODSEQ and UIDNEXT as they were, nothing else asked. CONDSTORE alone may expunge without
      // raising HIGHESTMODSEQ: the UIDs are checked again, no message fetched.
      expect(
        server.commands.where((c) => c.startsWith('UID ')),
        qresync ? isEmpty : everyElement(isNot(contains('BODY'))),
      );
    });
  }

  for (final qresync in [true, false]) {
    final name = qresync ? 'QRESYNC' : 'CONDSTORE without QRESYNC';

    test('$name: a stored message older than the window gets its flags, though CHANGEDSINCE leaves it out '
        '(#185)', () async {
      // UID 1, read before HIGHESTMODSEQ 100, out of the window: in the cache from a Conversazione opened.
      var modSeq = 100;
      var flags = r'\Seen';
      final server = await RecordedImapServer.start((c) {
        final caps = 'IMAP4rev1 IDLE ENABLE CONDSTORE${qresync ? ' QRESYNC' : ''}';
        if (basics(c, capabilities: caps) case final b?) return b;
        final upper = c.toUpperCase();
        if (upper.startsWith('SELECT')) {
          return [
            r'* FLAGS (\Seen \Flagged \Deleted)',
            '* 1 EXISTS',
            '* OK [UIDVALIDITY 7] UIDs valid',
            '* OK [UIDNEXT 2] next',
            '* OK [HIGHESTMODSEQ $modSeq] highest',
            'OK [READ-WRITE] SELECT completed',
          ];
        }
        if (upper.startsWith('UID SEARCH SINCE') || upper.startsWith('UID SEARCH UID 2:*')) return ['* SEARCH'];
        if (upper.startsWith('UID SEARCH UID 1')) return ['* SEARCH 1'];
        // Only what changed after the cursor's HIGHESTMODSEQ: nothing in round two.
        if (upper.contains('CHANGEDSINCE')) {
          return modSeq > 100 && upper.contains('CHANGEDSINCE 100')
              ? ['* 1 FETCH (UID 1 FLAGS ($flags) MODSEQ ($modSeq))']
              : [];
        }
        if (upper.startsWith('UID FETCH 1 (UID FLAGS)')) return ['* 1 FETCH (UID 1 FLAGS ($flags))'];
        if (upper.startsWith('UID FETCH 1 ')) return [_fetch(1, 1, flags, 'BODY[]', '${_header(1)}Uno\r\n', modSeq)];
        return ['BAD unexpected $c'];
      });
      addTearDown(server.stop);
      final keychain = FakeSecureStore();
      await server.remember(keychain, _account);
      final p = ImapProvider(
        _account,
        'ada@icloud.com',
        keychain,
        FakeClock(DateTime.utc(2026, 11, 6)),
        connect: plainConnector,
        storedIds: () async => ['INBOX/7/1'],
      );
      addTearDown(p.close);

      final first = okValue(await p.initialSync());
      expect(first.messages, isEmpty);
      final next = okValue(await p.incrementalSync(first.cursor));
      expect(next.messages.map((m) => (m.id, m.isRead)), [('INBOX/7/1', true)]);
      expect(server.commands, contains('UID FETCH 1 (UID FLAGS)'));

      // Unread elsewhere: CHANGEDSINCE brings it, against the read state the cursor now holds.
      modSeq = 101;
      flags = '';
      final last = okValue(await p.incrementalSync(next.cursor));
      expect(last.messages.map((m) => (m.id, m.isRead)), [('INBOX/7/1', false)]);
    });
  }

  test('with SPECIAL-USE announced, LIST asks for the roles: a localized Sent is SENT, not an Etichetta', () async {
    final mailbox = _Mailbox();
    final server = await RecordedImapServer.start((c) {
      const caps = 'IMAP4rev1 SPECIAL-USE';
      if (c.toUpperCase().startsWith('LIST')) {
        // A plain LIST without the roles, as RFC 6154 §2 allows.
        final sent = c.contains('RETURN (SPECIAL-USE)') ? r'\HasNoChildren \Sent' : r'\HasNoChildren';
        return basics(c, capabilities: caps, folders: [('', 'INBOX'), (sent, 'Elementi inviati')])!;
      }
      return basics(c, capabilities: caps) ?? mailbox.answer(c, qresync: false);
    });
    addTearDown(server.stop);
    final keychain = FakeSecureStore();
    await server.remember(keychain, _account);
    final p = ImapProvider(
      _account,
      'ada@icloud.com',
      keychain,
      FakeClock(DateTime.utc(2026, 11, 6)),
      connect: plainConnector,
    );
    addTearDown(p.close);
    final batch = okValue(await p.initialSync());
    expect(server.commands, contains(contains('RETURN (SPECIAL-USE)')));
    expect(batch.labels, isEmpty);
    expect(batch.messages.where((m) => m.id.startsWith('Elementi inviati/')).map((m) => m.labelIds.first).toSet(), {
      sentLabelId,
    });
  });

  test('a folder LIST shows but SELECT refuses is skipped, as it was: not an expired cursor', () async {
    final mailbox = _Mailbox();
    final server = await RecordedImapServer.start((c) {
      final folders = [('', 'INBOX'), ('', 'Privata')];
      if (c.toUpperCase().startsWith('LIST')) return basics(c, capabilities: '', folders: folders)!;
      if (c.contains('"Privata"')) return ['NO [NOPERM] not allowed'];
      return mailbox.answer(c, qresync: true);
    });
    addTearDown(server.stop);
    final keychain = FakeSecureStore();
    await server.remember(keychain, _account);
    final p = ImapProvider(
      _account,
      'ada@icloud.com',
      keychain,
      FakeClock(DateTime.utc(2026, 11, 6)),
      connect: plainConnector,
    );
    addTearDown(p.close);
    final first = okValue(await p.initialSync());
    expect(first.messages, hasLength(2));
    final next = okValue(await p.incrementalSync(first.cursor));
    expect(next.removedMessageIds, isEmpty);
  });

  test('a refused login after the greeting is an AuthFailure; a server without IDLE leaves the signal down', () async {
    final server = await RecordedImapServer.start(
      (c) => c.startsWith('LOGIN')
          ? ['NO [AUTHENTICATIONFAILED] Invalid credentials']
          : basics(c, capabilities: 'IMAP4rev1')!,
    );
    addTearDown(server.stop);
    final keychain = FakeSecureStore();
    await server.remember(keychain, _account);
    final p = ImapProvider(
      _account,
      'ada@icloud.com',
      keychain,
      FakeClock(DateTime.utc(2026, 11, 6)),
      connect: plainConnector,
    );
    expect(await p.initialSync(), isErr<AuthFailure>());

    final open = await RecordedImapServer.start((c) => basics(c, capabilities: 'IMAP4rev1')!);
    addTearDown(open.stop);
    await open.remember(keychain, _account);
    expect(await p.changes.take(1).toList(), [ChangeSignal.down]);
  });
}
