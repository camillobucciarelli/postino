// Bodies, attachments and Conversazioni of the IMAP adapter on GreenMail (#164): MIME fixtures delivered as another
// client would, beyond the contract; recorded responses for what GreenMail never sends.
@Tags(['imap'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random, min;

import 'package:enough_mail/enough_mail.dart' show MessageFlags, MessageSequence;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';
import '../../../support/recorded_imap_server.dart';

const _head =
    'From: ada@example.com\r\nTo: me@example.com\r\nSubject: Prova\r\nDate: Thu, 01 Jan 2026 10:00:00 +0000\r\n';

/// A message with the headers [extra] and the body [body] (CRLF lines), as another client would APPEND it.
String _raw(String id, String extra, String body) => '${_head}Message-ID: <$id@example.com>\r\n$extra\r\n$body';

String _b64(List<int> bytes) => base64.encode(bytes).replaceAllMapped(RegExp('.{1,76}'), (m) => '${m[0]}\r\n');

const _alt = 'Content-Type: multipart/alternative; boundary="alt"\r\n';

String _alternative(String plain, String html) =>
    '--alt\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n$plain\r\n'
    '--alt\r\nContent-Type: text/html; charset=utf-8\r\n\r\n$html\r\n--alt--\r\n';

/// Bytes per FETCH of an attachment, as the adapter asks for them.
const _chunk = 256 * 1024;

/// The attachment `2` of the message INBOX/7/5, of [bytes] ASCII bytes, on a server whose BODYSTRUCTURE says it is
/// [declared] bytes: the size to download as the server reports it, 0 for a server that does not. Every partial FETCH
/// of it is in the list returned.
Future<(ImapProvider, List<String>)> _recorded(int bytes, {required int declared}) async {
  final payload = 'a' * bytes;
  final fetches = <String>[];
  final server = await RecordedImapServer.start((command) {
    if (basics(command, capabilities: 'IMAP4rev1') case final b?) return b;
    final upper = command.toUpperCase();
    if (upper.startsWith('SELECT')) return ['* 1 EXISTS', '* OK [UIDVALIDITY 7] UIDs valid', 'OK [READ-WRITE] done'];
    if (upper.startsWith('UID FETCH 5 (UID BODYSTRUCTURE)')) {
      const text = '("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "7BIT" 6 1 NIL NIL NIL)';
      final file =
          '("APPLICATION" "OCTET-STREAM" ("NAME" "dati.bin") NIL NIL "7BIT" $declared NIL '
          '("ATTACHMENT" ("FILENAME" "dati.bin")) NIL)';
      return ['* 1 FETCH (UID 5 BODYSTRUCTURE ($text$file "MIXED" ("BOUNDARY" "mix") NIL NIL))'];
    }
    if (RegExp(r'^UID FETCH 5 \(UID BODY\.PEEK\[2\]<(\d+)\.').firstMatch(upper) case final m?) {
      fetches.add(command);
      final from = int.parse(m[1]!);
      final part = payload.substring(min(from, bytes), min(from + _chunk, bytes));
      return ['* 1 FETCH (UID 5 BODY[2]<$from> ${literal(part)})'];
    }
    return ['OK done'];
  });
  addTearDown(server.stop);
  final keychain = FakeSecureStore();
  await server.remember(keychain, 'icloud:ada@icloud.com');
  final p = ImapProvider(
    'icloud:ada@icloud.com',
    'ada@icloud.com',
    keychain,
    FakeClock(DateTime.utc(2026, 11, 6)),
    connect: plainConnector,
  );
  addTearDown(p.close);
  return (p, fetches);
}

void main() {
  // Recorded responses: GreenMail always reports a part's size, and never one that is a whole number of chunks.
  group('attachment download, on recorded responses', () {
    test('a server that reports no size: the chunks go on until a short one, nothing is cut', () async {
      final (p, fetches) = await _recorded(_chunk + 10, declared: 0);
      expect(okValue(await p.fetchAttachment('INBOX/7/5', '2')), hasLength(_chunk + 10));
      expect(fetches, hasLength(2));
    });

    test('exactly the size reported, a whole chunk: one FETCH, and the progress goes straight to 1', () async {
      final (p, fetches) = await _recorded(_chunk, declared: _chunk);
      final progress = <double>[];
      expect(okValue(await p.fetchAttachment('INBOX/7/5', '2', onProgress: progress.add)), hasLength(_chunk));
      expect(fetches, hasLength(1), reason: 'nothing left to ask for');
      expect(progress, [1]);
    });
  });

  if (imapSkipReason case final reason?) {
    test('IMAP bodies', () {}, skip: reason);
    return;
  }
  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());
  tearDownAll(ImapHarness.stopServer);

  /// The Provider id of the only message of the inbox, after APPENDing [raw].
  Future<String> delivered(String raw) async {
    await h.appendBytes('INBOX', utf8.encode(raw));
    return okValue(await h.provider.initialSync()).messages.single.id;
  }

  MessageBody ok(Result<MessageBody> r) => okValue(r);

  group('body', () {
    test('plain text only', () async {
      final id = await delivered(_raw('p', 'Content-Type: text/plain; charset=utf-8\r\n', 'Solo testo\r\n'));
      final body = ok(await h.provider.fetchBody(id));
      expect((body.kind, body.content.trim()), (BodyKind.testo, 'Solo testo'));
      expect(body.attachments, isEmpty);
    });

    test('multipart/alternative: the HTML wins, the plain text is not fetched in its place', () async {
      final id = await delivered(_raw('a', _alt, _alternative('Testo', '<p>Html</p>')));
      final body = ok(await h.provider.fetchBody(id));
      expect((body.kind, body.content.trim()), (BodyKind.html, '<p>Html</p>'));
    });

    test('a PDF with an inline logo: the PDF is an attachment, the cid: image is body', () async {
      final raw = _raw(
        'm',
        'Content-Type: multipart/mixed; boundary="mix"\r\n',
        '--mix\r\nContent-Type: multipart/related; boundary="rel"\r\n\r\n'
            '--rel\r\n$_alt\r\n${_alternative('Testo', '<p>Ciao <img src="cid:logo"></p>')}'
            '--rel\r\nContent-Type: image/png; name="logo.png"\r\nContent-Transfer-Encoding: base64\r\n'
            'Content-ID: <logo>\r\nContent-Disposition: inline; filename="logo.png"\r\n\r\n${_b64([1, 2, 3, 4])}\r\n--rel--\r\n'
            '--mix\r\nContent-Type: application/pdf; name="Preventivo.pdf"\r\nContent-Transfer-Encoding: base64\r\n'
            'Content-Disposition: attachment; filename="Preventivo.pdf"\r\n\r\n${_b64(utf8.encode('%PDF-1.4 preventivo'))}\r\n'
            '--mix--\r\n',
      );
      final id = await delivered(raw);
      final body = ok(await h.provider.fetchBody(id));
      expect(body.kind, BodyKind.html);
      expect(body.attachments!.map((a) => (a.name, a.mimeType)), [('Preventivo.pdf', 'application/pdf')]);
      // The sync's own body (an inbox message is fetched whole) agrees with the one on request.
      final synced = okValue(await h.provider.initialSync()).bodies[id]!;
      expect(synced.attachments!.map((a) => (a.id, a.name)), body.attachments!.map((a) => (a.id, a.name)));
      expect(
        utf8.decode(okValue(await h.provider.fetchAttachment(id, body.attachments!.single.id))),
        '%PDF-1.4 preventivo',
      );
    });

    test('an attachment without a name, and an empty file', () async {
      final raw = _raw(
        'n',
        'Content-Type: multipart/mixed; boundary="mix"\r\n',
        '--mix\r\nContent-Type: text/plain\r\n\r\nVedi allegati\r\n'
            '--mix\r\nContent-Type: application/octet-stream\r\nContent-Transfer-Encoding: base64\r\n'
            'Content-Disposition: attachment\r\n\r\n${_b64([9, 8, 7])}\r\n'
            '--mix\r\nContent-Type: text/plain; name="vuoto.txt"\r\nContent-Transfer-Encoding: base64\r\n'
            'Content-Disposition: attachment; filename="vuoto.txt"\r\n\r\n\r\n'
            '--mix--\r\n',
      );
      final id = await delivered(raw);
      final attachments = ok(await h.provider.fetchBody(id)).attachments!;
      expect(attachments.map((a) => a.name), ['', 'vuoto.txt']);
      expect(okValue(await h.provider.fetchAttachment(id, attachments[0].id)), [9, 8, 7]);
      expect(okValue(await h.provider.fetchAttachment(id, attachments[1].id)), isEmpty);
    });

    test('a charset that is not UTF-8, quoted-printable', () async {
      final qp = await delivered(
        _raw(
          'q',
          'Content-Type: text/plain; charset=iso-8859-1\r\nContent-Transfer-Encoding: quoted-printable\r\n',
          'Caff=E8 =E0 Mil=E1n\r\n',
        ),
      );
      expect(ok(await h.provider.fetchBody(qp)).content.trim(), 'Caffè à Milán');
    });

    test('raw 8-bit windows-1252', () async {
      final head = _raw(
        'l',
        'Content-Type: text/plain; charset=windows-1252\r\nContent-Transfer-Encoding: 8bit\r\n',
        '',
      );
      await h.appendBytes('INBOX', [...latin1.encode(head), ...'Perch'.codeUnits, 0xE9, 0x20, 0x80, 0x0D, 0x0A]);
      final id = okValue(await h.provider.initialSync()).messages.single.id;
      expect(ok(await h.provider.fetchBody(id)).content.trim(), 'Perché €');
    });

    test('opening a body does not mark the message read', () async {
      final id = await delivered(_raw('s', 'Content-Type: text/plain\r\n', 'Corpo\r\n'));
      ok(await h.provider.fetchBody(id));
      final flags = await h.withClient((c) async {
        await c.selectMailboxByPath('INBOX');
        final r = await c.uidFetchMessages(MessageSequence.fromAll(), '(UID FLAGS)');
        return r.messages.single.flags;
      });
      expect(flags, isNot(contains(MessageFlags.seen)));
      expect(okValue(await h.provider.initialSync()).messages.single.isRead, isFalse);
    });

    test('a message gone, or from another UIDVALIDITY, is NotFound', () async {
      final id = await delivered(_raw('g', 'Content-Type: text/plain\r\n', 'Corpo\r\n'));
      expect(await h.provider.fetchBody(id.replaceFirst(RegExp(r'/\d+/(\d+)$'), r'/1/$1')), isErr<NotFoundFailure>());
      expect(await h.provider.fetchBody(id.replaceFirst(RegExp(r'\d+$'), '999')), isErr<NotFoundFailure>());
      expect(await h.provider.fetchBody('Cartella/Inesistente/1/1'), isErr<NotFoundFailure>());
    });
  });

  group('attachment download', () {
    final big = List.generate(700 * 1024, (i) => Random(7).nextInt(256));
    Future<(String, String)> withBig() async {
      final id = await delivered(
        _raw(
          'b',
          'Content-Type: multipart/mixed; boundary="mix"\r\n',
          '--mix\r\nContent-Type: text/plain\r\n\r\nGrande\r\n'
              '--mix\r\nContent-Type: application/octet-stream; name="grande.bin"\r\nContent-Transfer-Encoding: base64\r\n'
              'Content-Disposition: attachment; filename="grande.bin"\r\n\r\n${_b64(big)}\r\n--mix--\r\n',
        ),
      );
      return (id, ok(await h.provider.fetchBody(id)).attachments!.single.id);
    }

    test('arrives whole in chunks, with a progress that only grows', () async {
      final (id, part) = await withBig();
      final progress = <double>[];
      expect(okValue(await h.provider.fetchAttachment(id, part, onProgress: progress.add)), big);
      expect(progress.length, greaterThan(2));
      expect(progress, orderedEquals([...progress]..sort()));
      expect(progress.last, 1);
    });

    test('cancelled halfway: CancelledFailure, and the connection is still good', () async {
      final (id, part) = await withBig();
      final cancel = Completer<void>();
      final r = await h.provider.fetchAttachment(
        id,
        part,
        cancel: cancel.future,
        onProgress: (done) {
          if (!cancel.isCompleted) cancel.complete();
        },
      );
      expect(r, isErr<CancelledFailure>());
      expect(ok(await h.provider.fetchBody(id)).attachments, hasLength(1));
      expect(okValue(await h.provider.initialSync()).messages, hasLength(1));
    });
  });
}
