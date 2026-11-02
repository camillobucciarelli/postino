// Invio (#36): Invia queues the message, it goes after the Annulla invio window (also offline, when the network
// returns, or after a restart), Annulla within the window keeps the Bozza, and a lost answer never sends it twice.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
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
    expect(await engine.send('a', _message(id)), isA<Ok<void>>());
    final entries = await GetIt.I<InboxRepository>().watchOutbox('a').first;
    expect(entries.single.message.to, ['b@example.com']);
    expect(entries.single.message.from, 'a@example.com');
    expect(
      entries.single.sendAfter,
      h.clock.now().add(sendWindow).millisecondsSinceEpoch,
    );

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
      expect((await outbox()).single.attempts, 1);

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
    );
    restarted.start();
    addTearDown(restarted.stop);
    await pumpEventQueue();
    expect(a.sent, [(id, 's-1')]);
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
