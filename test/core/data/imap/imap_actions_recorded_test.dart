// The Azioni on servers GreenMail is not (2.1.15 announces MOVE and UIDPLUS, no CONDSTORE): recorded responses.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_actions.dart' show MessageIdOf;
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/result.dart';

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
  var folders = _folders;

  /// What UID MOVE answers.
  var move = 'OK MOVE completed';

  /// Folders SELECT refuses.
  final unselectable = <String>{};

  /// What a SEARCH by Message-ID finds, when the destination holds no copy.
  var found = <String>[];
  var copies = 0;

  /// Whether the destination holds the message already (a COPY was done).
  var copied = false;

  List<String> answer(String command) {
    if (basics(command, capabilities: capabilities, folders: folders) case final b?) return b;
    final upper = command.toUpperCase();
    if (upper.startsWith('SELECT')) {
      if (unselectable.any((f) => upper.contains('"${f.toUpperCase()}"'))) return ['NO [NONEXISTENT] no such mailbox'];
      return [
        r'* FLAGS (\Seen \Flagged \Deleted)',
        '* 1 EXISTS',
        '* OK [UIDVALIDITY 7] UIDs valid',
        '* OK [UIDNEXT 6] next',
        if (capabilities.contains('CONDSTORE')) '* OK [HIGHESTMODSEQ $modSeq] highest',
        'OK [READ-WRITE] SELECT completed',
      ];
    }
    if (upper.startsWith('UID FETCH 9 ')) return <String>[];
    if (upper.startsWith('UID FETCH 5 (UID FLAGS')) return ['* 1 FETCH (UID 5 FLAGS ($flags) MODSEQ ($modSeq))'];
    if (upper.startsWith('UID FETCH 5 (UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])')) {
      return ['* 1 FETCH (UID 5 BODY[HEADER.FIELDS (MESSAGE-ID)] ${literal('Message-ID: <m5@example.com>\r\n\r\n')})'];
    }
    if (upper.startsWith('UID MOVE')) return [move];
    if (upper.startsWith('UID COPY')) {
      copies++;
      copied = true;
      return ['OK COPY completed'];
    }
    if (upper.startsWith('UID SEARCH HEADER MESSAGE-ID')) return copied ? ['* SEARCH 9'] : found;
    if (upper.startsWith('UID STORE')) {
      // RFC 7162 §3.1.3: the modifier follows the sequence set.
      if (upper.contains('UNCHANGEDSINCE') && !RegExp(r'^UID STORE \d+ \(UNCHANGEDSINCE \d+\) ').hasMatch(upper)) {
        return ['BAD Could not parse command'];
      }
      stores++;
      return onStore?.call(stores) ?? ['OK STORE completed'];
    }
    return ['OK done'];
  }
}

Future<(ImapProvider, RecordedImapServer)> _setUp(_Mailbox mailbox, {MessageIdOf? messageIdOf}) async {
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
    messageIdOf: messageIdOf,
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
    expect(_writes(server), [r'UID STORE 5 (UNCHANGEDSINCE 100) +FLAGS (\Seen)']);
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
      r'UID STORE 5 (UNCHANGEDSINCE 100) +FLAGS (\Seen)',
      r'UID STORE 5 (UNCHANGEDSINCE 101) +FLAGS (\Seen)',
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

  test('without MOVE a retry after a failed STORE does not COPY again: no duplicate in the destination', () async {
    late _Mailbox mailbox;
    mailbox = _Mailbox('IMAP4rev1 UIDPLUS', onStore: (n) => n == 1 ? ['NO store failed'] : ['OK STORE completed']);
    final (p, server) = await _setUp(mailbox);
    expect(await p.applyAction('INBOX/7/5', const Delete(), expected: Placement.inbox), isA<Err<ActionOutcome>>());
    expect(okValue(await p.applyAction('INBOX/7/5', const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
    expect(mailbox.copies, 1);
    expect(_writes(server).where((c) => c.startsWith('UID EXPUNGE')), ['UID EXPUNGE 5']);
  });

  test('a folder the server refuses does not hide the message in the next one', () async {
    final mailbox = _Mailbox('IMAP4rev1 MOVE')
      ..folders = const [('', 'Broken'), ('', 'INBOX')]
      ..unselectable.add('Broken')
      ..found = ['* SEARCH 5'];
    final (p, server) = await _setUp(mailbox, messageIdOf: (_) async => '<m5@example.com>');
    // UID 9 is gone from INBOX: found by Message-ID, past the folder SELECT refuses.
    expect(okValue(await p.applyAction('INBOX/7/9', const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(_writes(server), [r'UID STORE 5 +FLAGS (\Seen)']);
  });

  test('a refusal for now of the MOVE keeps the Azione queued; a final one rejects it', () async {
    final mailbox = _Mailbox('IMAP4rev1 MOVE')..move = 'NO [UNAVAILABLE] try again later';
    final (p, _) = await _setUp(mailbox);
    expect(
      await p.applyAction('INBOX/7/5', const Delete(), expected: Placement.inbox),
      isA<Err<ActionOutcome>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()),
    );
    mailbox.move = 'NO [TRYCREATE] no such mailbox';
    expect(
      await p.applyAction('INBOX/7/5', const Delete(), expected: Placement.inbox),
      isA<Err<ActionOutcome>>().having((e) => e.failure, 'failure', isA<RejectedFailure>()),
    );
  });
}
