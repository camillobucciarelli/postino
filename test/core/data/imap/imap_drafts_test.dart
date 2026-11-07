// Bozze on IMAP (#166): against GreenMail a Bozza is replaced at every save and its Conflitto (#149) reads the
// server's copy; against a recorded server without UIDPLUS the old copy goes with a plain EXPUNGE.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/draft_content.dart';
import 'package:postino/core/domain/draft_outcome.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';
import '../../../support/recorded_imap_server.dart';

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

Matcher _err<F>() => isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<F>());

OutgoingMessage _draft({String to = 'b@example.com', String subject = 's', String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(messageId: '<x@example.com>', from: 'me@example.com', to: [to], subject: subject, body: body);

void main() {
  test('without UIDPLUS the old Bozza goes with a plain EXPUNGE', () async {
    final server = await RecordedImapServer.start((c) {
      if (basics(c, capabilities: 'IMAP4rev1', folders: [('', 'INBOX'), ('', 'Drafts')]) case final b?) return b;
      final upper = c.toUpperCase();
      if (upper.startsWith('SELECT')) return ['* 1 EXISTS', '* OK [UIDVALIDITY 7] UIDs valid', 'OK [READ-WRITE] done'];
      if (upper.startsWith('UID SEARCH')) return ['* SEARCH 4'];
      return <String>[];
    });
    addTearDown(server.stop);
    final keychain = FakeSecureStore();
    await server.remember(keychain, 'imap:a');
    final p = ImapProvider('imap:a', 'a@example.com', keychain, FakeClock(DateTime.utc(2026)), connect: plainConnector);
    addTearDown(p.close);
    _ok(await p.deleteDraft('<x@example.com>'));
    expect(server.commands, contains(startsWith('UID STORE 4 ')));
    expect(server.commands, contains('EXPUNGE'));
    expect(server.commands.where((c) => c.startsWith('UID EXPUNGE')), isEmpty);
  });

  group('GreenMail', () {
    if (imapSkipReason case final reason?) {
      test('IMAP Bozze', () {}, skip: reason);
      return;
    }
    tearDownAll(ImapHarness.stopServer);

    late ImapHarness h;
    setUp(() async => h = await ImapHarness.create());
    tearDown(() => h.dispose());

    Future<int> copies(String path) => h.copies(path, '<x@example.com>');

    group('Bozze', () {
      test('three saves leave one Bozza, with the same Message-ID and the last content', () async {
        _ok(await h.provider.saveDraft(_draft(), isNew: true));
        _ok(await h.provider.saveDraft(_draft(subject: 's2'), isNew: false));
        _ok(await h.provider.saveDraft(_draft(subject: 's3'), isNew: false));
        expect(await copies('Drafts'), 1);
        final m = _ok(await h.provider.initialSync()).messages.single;
        expect((m.messageId, m.subject), ('<x@example.com>', 's3'));
        expect(m.labelIds, [draftLabelId]);
      });

      test('a save whose answer was lost, sent again as new, still leaves one Bozza', () async {
        _ok(await h.provider.saveDraft(_draft(), isNew: true));
        _ok(await h.provider.saveDraft(_draft(), isNew: true));
        expect(await copies('Drafts'), 1);
      });

      test('deleted by another client: the next save is NotFound', () async {
        _ok(await h.provider.saveDraft(_draft(), isNew: true));
        await h.removeRemotely('x');
        expect(await h.provider.saveDraft(_draft(subject: 's2'), isNew: false), _err<NotFoundFailure>());
        expect(await copies('Drafts'), 0);
      });

      group('with the expected impronta (#149)', () {
        final expected = DraftContent.of(_draft()).fingerprint;
        final edit = _draft(body: '<p>Ciao, modificata qui</p>');

        test('the Bozza as uploaded (read back from the server): written', () async {
          _ok(await h.provider.saveDraft(_draft(), isNew: true));
          expect(_ok(await h.provider.saveDraft(edit, isNew: false, expected: expected)), isA<DraftSaved>());
          expect(await copies('Drafts'), 1);
        });

        test('edited elsewhere: a Conflitto with the server\'s version, nothing written', () async {
          _ok(await h.provider.saveDraft(_draft(), isNew: true));
          await h.removeRemotely('x');
          await h.deliverDraft(_draft(to: 'carla@example.com', subject: 'Altrove', body: '<p>Da Mail.app</p>'));
          expect(
            _ok(await h.provider.saveDraft(edit, isNew: false, expected: expected)),
            isA<DraftDiverged>().having(
              (d) => d.provider.fingerprint,
              'provider',
              DraftContent.of(_draft(to: 'carla@example.com', subject: 'Altrove', body: '<p>Da Mail.app</p>'))
                  .fingerprint,
            ),
          );
          final m = _ok(await h.provider.initialSync()).messages.single;
          expect(m.subject, 'Altrove');
        });

        test('sent or deleted elsewhere: NotFound, nothing written', () async {
          _ok(await h.provider.saveDraft(_draft(), isNew: true));
          await h.removeRemotely('x');
          expect(await h.provider.saveDraft(edit, isNew: false, expected: expected), _err<NotFoundFailure>());
          expect(await copies('Drafts'), 0);
        });

        test('already the wanted version elsewhere: written, no Conflitto', () async {
          _ok(await h.provider.saveDraft(edit, isNew: true));
          expect(_ok(await h.provider.saveDraft(edit, isNew: false, expected: 'other')), isA<DraftSaved>());
        });
      });
    });
  });
}
