// The Azioni on servers GreenMail is not (2.1.15 announces MOVE and UIDPLUS, no CONDSTORE): recorded responses.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show okValue;
import '../../../support/recorded_imap_server.dart';

const _account = 'icloud:ada@icloud.com';
const _folders = [('', 'INBOX'), ('', 'Trash')];

/// One INBOX message, UID 5, with [flags] and [modSeq]; [onStore] answers the n-th UID STORE.
class _Mailbox(final String capabilities, {final List<String> Function(int n)? onStore}) {
  String flags = '';
  var modSeq = 100;
  var stores = 0;

  List<String> answer(String command) {
    if (basics(command, capabilities: capabilities, folders: _folders) case final b?) return b;
    final upper = command.toUpperCase();
    if (upper.startsWith('SELECT')) {
      return [
        r'* FLAGS (\Seen \Flagged \Deleted)',
        '* 1 EXISTS',
        '* OK [UIDVALIDITY 7] UIDs valid',
        '* OK [UIDNEXT 6] next',
        if (capabilities.contains('CONDSTORE')) '* OK [HIGHESTMODSEQ $modSeq] highest',
        'OK [READ-WRITE] SELECT completed',
      ];
    }
    if (upper.startsWith('UID FETCH 5 ')) return ['* 1 FETCH (UID 5 FLAGS ($flags) MODSEQ ($modSeq))'];
    if (upper.startsWith('UID STORE')) {
      stores++;
      return onStore?.call(stores) ?? ['OK STORE completed'];
    }
    return ['OK done'];
  }
}

Future<(ImapProvider, RecordedImapServer)> _setUp(_Mailbox mailbox) async {
  final server = await RecordedImapServer.start(mailbox.answer);
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
  return (p, server);
}

Iterable<String> _writes(RecordedImapServer s) =>
    s.commands.where((c) => c.startsWith('UID ') && !c.startsWith('UID FETCH') && !c.startsWith('UID SEARCH'));

void main() {
  test('without MOVE: COPY, \\Deleted and EXPUNGE of that UID only', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1 UIDPLUS'));
    final r = okValue(await p.applyAction('INBOX/7/5', const Delete(), expected: Placement.inbox));
    expect(r, isA<ActionApplied>());
    expect(_writes(server), ['UID COPY 5 Trash', r'UID STORE 5 +FLAGS (\Deleted)', 'UID EXPUNGE 5']);
  });

  test('with MOVE: one UID MOVE', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1 MOVE UIDPLUS'));
    okValue(await p.applyAction('INBOX/7/5', const Delete(), expected: Placement.inbox));
    expect(_writes(server), ['UID MOVE 5 Trash']);
  });

  test('CONDSTORE: the flag is written UNCHANGEDSINCE the MODSEQ read', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1 CONDSTORE'));
    okValue(await p.applyAction('INBOX/7/5', const MarkRead(), expected: false));
    expect(_writes(server), [r'UID STORE (UNCHANGEDSINCE 100) 5 +FLAGS (\Seen)']);
  });

  test('CONDSTORE: MODIFIED reads and compares again, then writes with the new MODSEQ', () async {
    late _Mailbox mailbox;
    mailbox = _Mailbox(
      'IMAP4rev1 CONDSTORE',
      onStore: (n) {
        if (n > 1) return ['OK STORE completed'];
        mailbox.modSeq = 101;
        return ['OK [MODIFIED 5] Conditional STORE failed'];
      },
    );
    final (p, server) = await _setUp(mailbox);
    expect(okValue(await p.applyAction('INBOX/7/5', const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(_writes(server), [
      r'UID STORE (UNCHANGEDSINCE 100) 5 +FLAGS (\Seen)',
      r'UID STORE (UNCHANGEDSINCE 101) 5 +FLAGS (\Seen)',
    ]);
  });

  test('CONDSTORE: MODIFIED because it was read elsewhere meanwhile: already as wanted, no second write', () async {
    late _Mailbox mailbox;
    mailbox = _Mailbox(
      'IMAP4rev1 CONDSTORE',
      onStore: (n) {
        mailbox
          ..modSeq = 101
          ..flags = r'\Seen';
        return ['OK [MODIFIED 5] Conditional STORE failed'];
      },
    );
    final (p, server) = await _setUp(mailbox);
    expect(okValue(await p.applyAction('INBOX/7/5', const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(_writes(server), hasLength(1));
  });

  test('already the wanted value: one read, no write', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1 MOVE')..flags = r'\Seen \Flagged');
    expect(okValue(await p.applyAction('INBOX/7/5', const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(okValue(await p.applyAction('INBOX/7/5', const Star(), expected: false)), isA<ActionApplied>());
    expect(_writes(server), isEmpty);
  });

  test('another flag changed elsewhere is not a Conflitto', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1')..flags = r'\Flagged');
    expect(okValue(await p.applyAction('INBOX/7/5', const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(_writes(server), [r'UID STORE 5 +FLAGS (\Seen)']);
  });

  test('the same flag changed elsewhere to another value: a Conflitto with it, nothing written', () async {
    final (p, server) = await _setUp(_Mailbox('IMAP4rev1')..flags = r'\Flagged');
    final r = okValue(await p.applyAction('INBOX/7/5', const Unstar(), expected: false));
    expect(r, isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', true));
    expect(_writes(server), isEmpty);
  });
}
