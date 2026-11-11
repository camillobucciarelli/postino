// Sending, Posta inviata and Bozze on a simulated Graph mailbox (#183): the contract, the retry after a lost answer
// and the limit. No network.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/microsoft/graph_sender.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/draft_content.dart';
import 'package:postino/core/domain/draft_outcome.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/send_limit.dart';

import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_harness.dart';
import '../../../support/graph_recorded.dart';
import '../../domain/mail_provider_contract.dart';

OutgoingMessage _draft(String body) => OutgoingMessage(
  messageId: '<x@example.com>',
  from: 'me@example.com',
  to: const ['b@example.com'],
  subject: 's',
  body: body,
);

final _d = _draft('<p>Ciao</p>');
final _raw = renderMime(_d, DateTime.utc(2026));

void main() {
  mailProviderSendContract('MicrosoftProvider', GraphHarness.new);
  mailProviderDraftContract('MicrosoftProvider', GraphHarness.new);

  group('send', () {
    test('the MIME goes once as base64 text/plain; Graph files the copy, nothing is appended', () async {
      final h = GraphHarness();
      okValue(await h.provider.send(_d.messageId, _raw));
      final call = h.requests.singleWhere((r) => graphPath(r) == 'sendMail');
      expect(call.headers['content-type'], startsWith('text/plain'));
      expect(call.body, isNot(contains('From:')), reason: 'base64, not the text');
      expect(h.inFolder('sentitems').map((m) => m.messageId), [_d.messageId]);
      expect(h.requests.where((r) => r.method == 'POST').map(graphPath), ['sendMail'], reason: 'no APPEND, no draft');
    });

    test('a retry after a lost answer finds the message in Posta inviata: no second sendMail', () async {
      final h = GraphHarness()..loseNextSendAnswer = true;
      await h.provider.send(_d.messageId, _raw);
      expect(h.sendMailCalls, 1);
      final retry = okValue(await h.provider.send(_d.messageId, _raw));
      expect(h.sendMailCalls, 1);
      expect(h.inFolder('sentitems').map((m) => m.id), [retry]);
    });

    test('not visible right after the 202: the retry waits, looks again, and does not send twice', () async {
      final h = GraphHarness()
        ..sentVisibleAfter = 2
        ..loseNextSendAnswer = true;
      await h.provider.send(_d.messageId, _raw);
      final retry = okValue(await h.provider.send(_d.messageId, _raw));
      expect(h.sendMailCalls, 1);
      expect(h.sleeps, [GraphSender.sentLag]);
      expect(h.inFolder('sentitems').map((m) => m.id), [retry]);
    });

    test('Graph files the copy a moment after the 202: one wait, and the real id comes back', () async {
      final h = GraphHarness()..sentVisibleAfter = 2;
      final id = okValue(await h.provider.send(_d.messageId, _raw));
      expect(h.sleeps, [GraphSender.sentLag]);
      expect(h.inFolder('sentitems').map((m) => m.id), [id]);
    });

    test('a retry that still does not see it after the wait sends again', () async {
      final h = GraphHarness()
        ..sentVisibleAfter = 9
        ..loseNextSendAnswer = true;
      await h.provider.send(_d.messageId, _raw);
      okValue(await h.provider.send(_d.messageId, _raw));
      expect(h.sendMailCalls, 2);
      expect(h.sleeps, [GraphSender.sentLag, GraphSender.sentLag], reason: 'before the resend, and after it');
    });

    test('after a recorded 202 (submitted) it never sends again, even if Graph has not filed it', () async {
      final h = GraphHarness()..sentVisibleAfter = 9;
      var recorded = 0;
      okValue(await h.provider.send(_d.messageId, _raw, onSubmitted: () async => recorded++));
      expect(recorded, 1);
      final id = okValue(await h.provider.send(_d.messageId, _raw, submitted: true));
      expect(id, _d.messageId, reason: "stand-in until the sync brings Graph's copy");
      expect(h.sendMailCalls, 1);
    });

    test('a 413 and ErrorMessageSizeExceeded are SizeLimitFailure with the Provider limit', () async {
      for (final fixture in ['send_too_large', 'send_size_exceeded']) {
        final h = GraphHarness()..sendRefusal = graphFixture(fixture);
        expect(
          await h.provider.send(_d.messageId, _raw),
          isA<Err<String>>().having((e) => e.failure, 'failure', const SizeLimitFailure(microsoftSendLimitBytes)),
          reason: fixture,
        );
      }
    });

    test('the Bozza with the same Message-ID is deleted after the send', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      okValue(await h.provider.send(_d.messageId, _raw));
      expect(h.draftMessageIds, isEmpty);
    });

    test('the token never reaches the log', () async {
      final lines = <String>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => lines.add(m ?? '');
      addTearDown(() => debugPrint = old);
      // Throttled: the adapter logs the request, which must carry the path and the status, never the token.
      final h = GraphHarness()..sendRefusal = graphFixture('rate_limited');
      await h.provider.send(_d.messageId, _raw);
      expect(lines.join(), contains('[graph] throttled'));
      expect(lines.join(), isNot(contains('EwB.')));
    });
  });

  group('Bozze', () {
    test('three saves leave one Bozza, with the same Message-ID', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      okValue(await h.provider.saveDraft(_draft('<p>Due</p>'), isNew: false));
      okValue(await h.provider.saveDraft(_draft('<p>Tre</p>'), isNew: false));
      expect(h.draftMessageIds, [_d.messageId]);
    });

    test('a creation whose answer was lost is replaced, not doubled', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      okValue(await h.provider.saveDraft(_d, isNew: true));
      expect(h.draftMessageIds, [_d.messageId]);
    });

    test('deleted from another client: the next save is NotFound', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      h.removeRemotely('draft-1');
      expect(await h.provider.saveDraft(_d, isNew: false), isErr<NotFoundFailure>());
    });

    test('changed elsewhere, saved with `expected`: DraftDiverged, nothing written', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      final mine = DraftContent.of(_d).fingerprint;
      h
        ..removeRemotely('draft-1')
        ..deliverDraft(_draft('<p>Da altrove</p>'));
      final before = h.requests.length;
      final r = okValue(await h.provider.saveDraft(_draft('<p>Mio</p>'), isNew: false, expected: mine));
      expect(r, isA<DraftDiverged>().having((o) => o.provider.body, 'body', '<p>Da altrove</p>'));
      expect(h.requests.skip(before).where((q) => q.method == 'POST'), isEmpty);
    });

    test('a half-finished save left two copies, one is the expected: saved, not diverged', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      final expected = DraftContent.of(_d).fingerprint;
      h.deliverDraft(_draft('<p>Altra copia</p>'));
      final r = okValue(await h.provider.saveDraft(_draft('<p>Mio</p>'), isNew: false, expected: expected));
      expect(r, isA<DraftSaved>());
      expect(h.draftMessageIds, [_d.messageId]);
    });

    test('a Bozza over the limit is refused before any upload', () async {
      final h = GraphHarness();
      final big = _draft('<p>${'x' * microsoftSendLimitBytes}</p>');
      expect(await h.provider.saveDraft(big, isNew: true), isA<Err<DraftOutcome>>());
      expect(h.requests.where((q) => q.method == 'POST'), isEmpty);
    });

    test('unchanged since the expected one: saved', () async {
      final h = GraphHarness();
      okValue(await h.provider.saveDraft(_d, isNew: true));
      final r = okValue(
        await h.provider.saveDraft(_draft('<p>Mio</p>'), isNew: false, expected: DraftContent.of(_d).fingerprint),
      );
      expect(r, isA<DraftSaved>());
    });
  });
}
