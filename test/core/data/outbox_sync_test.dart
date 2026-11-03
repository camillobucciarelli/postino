// Invio (#36): Invia queues the message, it goes after the Annulla invio window (also offline, when the network
// returns, or after a restart), Annulla within the window keeps the Bozza, and a lost answer never sends it twice.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/attachment_repository.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/platform_services.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

OutgoingMessage _message(String messageId, {String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(
      messageId: messageId,
      from: 'a@example.com',
      to: const ['b@example.com'],
      subject: 's',
      body: body,
    );

Matcher _okAt(DateTime deadline) =>
    isA<Ok<DateTime>>().having((r) => r.value, 'value', deadline);

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;
  const id = '<x@example.com>';

  Future<List<OutboxRow>> outbox() =>
      GetIt.I<PostinoDatabase>().outboxDao.watch('a').first;
  Future<DraftRow?> draftRow() =>
      GetIt.I<PostinoDatabase>().draftsDao.byId('a', id);
  Future<List<InboxEntry>> inviati() =>
      GetIt.I<InboxRepository>().watchMessages('a', sentLabelId).first;

  setUp(() async {
    h = await Harness.create();
    a = await h.addAccount('a');
    engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
  });

  test('Invia queues the message and nothing goes before 10 s; at 10 s one send, the Bozza goes, Inviati shows it, the Provider Bozza too', () async {
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a');
    expect(a.drafts.keys, [id]);
    final deadline = h.clock.now().add(sendWindow);
    expect(await engine.send('a', _message(id)), _okAt(deadline));
    final entries = await GetIt.I<InboxRepository>().watchOutbox('a').first;
    expect(entries.single.message.to, ['b@example.com']);
    expect(entries.single.message.from, 'a@example.com');
    expect(entries.single.sendAfter, deadline.millisecondsSinceEpoch);
    expect(entries.single.failed, isFalse);

    h.clock.advance(const Duration(seconds: 9));
    await pumpEventQueue();
    expect(a.sent, isEmpty);
    expect(await draftRow(), isNotNull);

    h.clock.advance(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(a.sent, [(id, 's-1')]);
    expect(await outbox(), isEmpty);
    expect(await draftRow(), isNull);
    expect(a.drafts, isEmpty);
    final sent = (await inviati()).single.message;
    expect((sent.id, sent.messageId, sent.from), ('s-1', id, 'a@example.com'));
    expect(sent.snippet, 'Ciao');
    expect(sent.isRead, isTrue);

    // The next sync upserts the same id: still one message in Inviati.
    await engine.syncAll();
    expect((await inviati()).single.message.id, 's-1');
  });

  test('Annulla within the window: nothing sent, outbox empty, the Bozza stays; after the send it is false', () async {
    await engine.saveDraft('a', _message(id));
    await engine.send('a', _message(id));
    h.clock.advance(const Duration(seconds: 5));
    expect(await engine.cancelSend('a', id), isTrue);
    h.clock.advance(const Duration(seconds: 10));
    await pumpEventQueue();
    expect(a.sent, isEmpty);
    expect(await outbox(), isEmpty);
    expect(await draftRow(), isNotNull);

    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(await engine.cancelSend('a', id), isFalse);
  });

  test(
    'offline the message stays queued and goes once when the network returns',
    () async {
      engine.start();
      addTearDown(engine.stop);
      await pumpEventQueue();
      a.goOffline();
      await engine.send('a', _message(id));
      h.clock.advance(sendWindow);
      await pumpEventQueue();
      expect(a.sent, isEmpty);
      expect(await outbox(), hasLength(1));

      a.goOnline();
      h.connectivity.online = true;
      await pumpEventQueue();
      expect(a.sent, [(id, 's-1')]);
      expect(await outbox(), isEmpty);
    },
  );

  test('a lost answer: the row stays, the next poll finds the message in Inviati and does not send it again', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.loseSendResponse = true;
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(await outbox(), hasLength(1));

    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(await outbox(), isEmpty);
    expect((await inviati()).single.message.id, 's-1');
  });

  test('an entry still queued at restart goes at the next start', () async {
    await engine.send('a', _message(id));
    await engine.stop();
    h.clock.advance(const Duration(minutes: 1));
    expect(a.sent, isEmpty);

    final restarted = SyncEngine(
      GetIt.I<MailStore>(),
      GetIt.I<Clock>(),
      GetIt.I<Connectivity>(),
      GetIt.I<BackgroundSender>(),
    );
    restarted.start();
    addTearDown(restarted.stop);
    await pumpEventQueue();
    expect(a.sent, [(id, 's-1')]);
    expect(await outbox(), isEmpty);
  });

  test('a forward goes with its attachments, downloaded at Invia, and in its Conversazione', () async {
    final att = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
    final m = _message(id);
    expect(
      await engine.send(
        'a',
        OutgoingMessage(
          messageId: m.messageId,
          from: m.from,
          to: m.to,
          subject: m.subject,
          body: m.body,
          conversationId: 't-0',
          attachments: [ForwardedAttachment('m0', att)],
        ),
      ),
      isA<Ok<void>>(),
    );
    expect((await outbox()).single.raw, contains('Contratto.pdf'));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect((await inviati()).single.message.conversationId, 't-0');
  });

  OutgoingMessage forward(Attachment att) => OutgoingMessage(
    messageId: id,
    from: 'a@example.com',
    to: const ['b@example.com'],
    subject: 's',
    body: '<p>Ciao</p>',
    attachments: [ForwardedAttachment('m0', att)],
  );

  test('offline, a forward whose attachment was opened here is queued from the cache; one never opened is OfflineFailure', () async {
    final opened = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
    final never = a.attach('m0', 'Altro.pdf', [4, 5]);
    expect(
      await GetIt.I<AttachmentRepository>().file('a', 'm0', opened),
      isA<Ok<String>>(),
    );
    a.goOffline();
    expect(await engine.send('a', forward(opened)), isA<Ok<DateTime>>());
    expect((await outbox()).single.raw, contains('Contratto.pdf'));

    await engine.cancelSend('a', id);
    expect(
      await engine.send('a', forward(never)),
      isA<Err<DateTime>>().having(
        (e) => e.failure,
        'failure',
        isA<OfflineFailure>(),
      ),
    );
    expect(await outbox(), isEmpty);
  });

  test(
    'the Annulla window starts once the forwarded attachments are downloaded',
    () async {
      final att = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
      a.holdAttachment = Completer();
      final sending = engine.send('a', forward(att));
      await pumpEventQueue();
      h.clock.advance(const Duration(seconds: 7));
      a.holdAttachment!.complete();
      final deadline = h.clock.now().add(sendWindow);
      expect(await sending, _okAt(deadline));
      expect(
        (await outbox()).single.sendAfter,
        deadline.millisecondsSinceEpoch,
      );
    },
  );

  test('Annulla while the send is in flight waits for it: false, and the message is in Inviati', () async {
    a.holdSend = Completer();
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    final cancel = engine.cancelSend('a', id);
    await pumpEventQueue();
    a.holdSend!.complete();
    expect(await cancel, isFalse);
    expect(await outbox(), isEmpty);
    expect((await inviati()).single.message.messageId, id);
  });

  test('two engines on the same database (foreground and WorkManager) replaying at once send once', () async {
    await engine.send('a', _message(id));
    await engine.stop();
    h.clock.advance(sendWindow);
    final other = SyncEngine(
      GetIt.I<MailStore>(),
      GetIt.I<Clock>(),
      GetIt.I<Connectivity>(),
      GetIt.I<BackgroundSender>(),
    );
    await Future.wait([engine.flushOutbox('a'), other.flushOutbox('a')]);
    expect(a.sendCalls, 1);
    expect(a.sent, hasLength(1));
    expect(await outbox(), isEmpty);
  });

  test('a send refused for good is marked failed, not retried, shown failed; Annulla then removes it', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.sendFailure = const SizeLimitFailure(gmailSendLimitBytes);
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    expect((await outbox()).single.failed, isTrue);
    expect(
      (await GetIt.I<InboxRepository>().watchOutbox('a').first).single.failed,
      isTrue,
    );
    // Nothing left to send: the platform is let go.
    expect(h.background.releases, ['a']);

    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(a.sendCalls, 1);

    expect(await engine.cancelSend('a', id), isTrue);
    expect(await outbox(), isEmpty);
  });

  test('a message over the Gmail limit is refused and not queued', () async {
    final r = await engine.send(
      'a',
      _message(id, body: '<p>${'x' * (gmailSendLimitBytes + 1)}</p>'),
    );
    expect(
      r,
      isA<Err<void>>().having(
        (e) => e.failure,
        'failure',
        isA<SizeLimitFailure>().having(
          (f) => f.limitBytes,
          'limitBytes',
          gmailSendLimitBytes,
        ),
      ),
    );
    expect(await outbox(), isEmpty);
  });

  test('during the pause after a RateLimitFailure the flush waits; the message goes with the first sync after it', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    final until = h.clock.now().add(const Duration(minutes: 5));
    a.rateLimit(true, until);
    a.deliver(msg('3'));
    await pumpEventQueue();
    a.rateLimit(false);

    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, isEmpty);
    expect(await outbox(), hasLength(1));

    h.clock.advance(const Duration(minutes: 5));
    await pumpEventQueue();
    expect(a.sent, [(id, 's-1')]);
    expect(await outbox(), isEmpty);
  });

  test('a queued message is not listed in Bozze (local row nor the Provider\'s), and is again after Annulla', () async {
    Future<List<String>> listed() async =>
        (await GetIt.I<InboxRepository>().watchDrafts('a').first)
            .map((m) => m.messageId)
            .toList();
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a');
    await engine.syncAll(); // the Provider lists it as DRAFT too
    expect(await listed(), [id]);

    await engine.send('a', _message(id));
    expect(await draftRow(), isNotNull);
    expect(await listed(), isEmpty);

    await engine.cancelSend('a', id);
    expect(await listed(), [id]);
  });

  test('a RateLimitFailure of the send pauses the Account: one call, the rest stays queued until the deadline', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    await engine.send('a', _message(id));
    await engine.send('a', _message('<y@example.com>'));
    a.sendFailure = RateLimitFailure(
      retryAfter: h.clock.now().add(const Duration(minutes: 5)),
    );
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    expect(await outbox(), hasLength(2));

    a.sendFailure = null;
    h.clock.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(a.sendCalls, 1);

    h.clock.advance(const Duration(minutes: 5));
    await pumpEventQueue();
    expect(a.sent.map((s) => s.$1), unorderedEquals([id, '<y@example.com>']));
    expect(await outbox(), isEmpty);
  });

  test('a queued message does not upload its Bozza: the send goes at 10 s without a draft PUT', () async {
    engine.start();
    addTearDown(engine.stop);
    await engine.saveDraft('a', _message(id));
    await engine.send('a', _message(id));
    await engine.flushDrafts('a'); // the composer disposing
    expect(a.drafts, isEmpty);

    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, [(id, 's-1')]);
    expect(a.drafts, isEmpty);
  });

  test('Invia holds the platform once; the send releases it once', () async {
    await engine.send('a', _message(id));
    await pumpEventQueue();
    expect(h.background.holds, ['a']);
    expect(h.background.releases, isEmpty);

    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(h.background.holds, ['a']);
    expect(h.background.releases, ['a']);

    // A later replay with an empty outbox does not release again.
    await engine.syncAll();
    expect(h.background.releases, ['a']);
  });

  test('Annulla of the only queued message releases the platform', () async {
    await engine.send('a', _message(id));
    await engine.cancelSend('a', id);
    expect(h.background.holds, ['a']);
    expect(h.background.releases, ['a']);
  });

  test('send for an unknown Account is NotFound', () async {
    expect(
      await engine.send('zzz', _message(id)),
      isA<Err<void>>().having(
        (e) => e.failure,
        'failure',
        isA<NotFoundFailure>(),
      ),
    );
  });
}
