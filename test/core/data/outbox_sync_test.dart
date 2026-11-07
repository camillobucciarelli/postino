// Invio (#36): Invia queues the message, it goes after the Annulla invio window (also offline, when the network
// returns, or after a restart), Annulla within the window keeps the Bozza, and a lost answer never sends it twice.
import 'dart:async';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/background_send.dart';
import 'package:postino/core/data/daos/outbox_dao.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/data/outbox_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/auto_labeler.dart';
import 'package:postino/core/data/sync/intent_replayer.dart';
import 'package:postino/core/data/sync/new_mail_notifier.dart';
import 'package:postino/core/data/sync/outbox_sender.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/attachment_repository.dart';
import 'package:postino/core/domain/error_log.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/outbox_repository.dart';
import 'package:postino/core/domain/platform_services.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

OutgoingMessage _message(String messageId, {String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(messageId: messageId, from: 'a@example.com', to: const ['b@example.com'], subject: 's', body: body);

Matcher _okAt(DateTime deadline) => isA<Ok<DateTime>>().having((r) => r.value, 'value', deadline);

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;
  const id = '<x@example.com>';

  Future<List<OutboxRow>> outbox() => GetIt.I<PostinoDatabase>().outboxDao.watch('a').first;
  Future<DraftRow?> draftRow() => GetIt.I<PostinoDatabase>().draftsDao.byId('a', id);
  Future<List<InboxEntry>> inviati() => GetIt.I<InboxRepository>().watchMessages('a', sentLabelId).first;

  setUp(() async {
    h = await Harness.create();
    a = await h.addAccount('a');
    engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
  });

  test('Android worker: a row still preparing re-holds the platform and sends nothing; a due row is sent with no extra hold', () async {
    await GetIt.I<OutboxStore>().enqueueOutgoing(
      'a',
      _message(id),
      version: 1,
      raw: '',
      sendAfter: OutboxDao.preparing,
    );
    expect(await runOutboxTask('a'), isTrue);
    expect(h.background.holds, ['a']);
    expect(a.sendCalls, 0);

    h.background.holds.clear();
    await engine.cancelSend('a', id);
    expect(await engine.send('a', _message(id)), isA<Ok<DateTime>>());
    h.background.holds.clear();
    h.clock.advance(sendWindow);
    await runOutboxTask('a');
    expect(a.sendCalls, 1);
    expect(h.background.holds, isEmpty);
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
    expect(await engine.cancelSend('a', id), id);
    h.clock.advance(const Duration(seconds: 10));
    await pumpEventQueue();
    expect(a.sent, isEmpty);
    expect(await outbox(), isEmpty);
    expect(await draftRow(), isNotNull);

    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(await engine.cancelSend('a', id), isNull);
  });

  test('offline the message stays queued and goes once when the network returns', () async {
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
  });

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

  test(
    'SMTP accepted but the copy failed (#175): the row remembers it and the replay only completes the send',
    () async {
      engine.start();
      addTearDown(engine.stop);
      await pumpEventQueue();
      a.failAfterSubmit = const OfflineFailure();
      await engine.send('a', _message(id));
      h.clock.advance(sendWindow);
      await pumpEventQueue();
      expect((await outbox()).single.smtpSentAt, isNotNull);

      a.failAfterSubmit = null;
      h.clock.advance(pollEvery);
      await pumpEventQueue();
      expect(a.sendSubmitted, [false, true]);
      expect(await outbox(), isEmpty);
    },
  );

  test('an entry still queued at restart goes at the next start', () async {
    await engine.send('a', _message(id));
    await engine.stop();
    h.clock.advance(const Duration(minutes: 1));
    expect(a.sent, isEmpty);

    final restarted = SyncEngine(
      GetIt.I<MailStore>(),
      GetIt.I<OutboxRepository>(),
      GetIt.I<Clock>(),
      GetIt.I<Connectivity>(),
      GetIt.I<BackgroundSender>(),
      GetIt.I<NewMailNotifier>(),
      GetIt.I<AutoLabeler>(),
      GetIt.I<ErrorLog>(),
    )..start();
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

  test(
    'offline, a forward whose attachment was opened here is queued from the cache; one never opened is OfflineFailure',
    () async {
      final opened = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
      final never = a.attach('m0', 'Altro.pdf', [4, 5]);
      expect(await GetIt.I<AttachmentRepository>().file('a', 'm0', opened), isA<Ok<String>>());
      a.goOffline();
      expect(await engine.send('a', forward(opened)), isA<Ok<DateTime>>());
      expect((await outbox()).single.raw, contains('Contratto.pdf'));

      await engine.cancelSend('a', id);
      expect(
        await engine.send('a', forward(never)),
        isA<Err<DateTime>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()),
      );
      expect((await outbox()).single.failed, isTrue);
    },
  );

  test('the Annulla window starts once the forwarded attachments are downloaded', () async {
    final att = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
    a.holdAttachment = Completer();
    final sending = engine.send('a', forward(att));
    await pumpEventQueue();
    h.clock.advance(const Duration(seconds: 7));
    a.holdAttachment!.complete();
    final deadline = h.clock.now().add(sendWindow);
    expect(await sending, _okAt(deadline));
    expect((await outbox()).single.sendAfter, deadline.millisecondsSinceEpoch);
  });

  test('an obsolete preparation cannot fill or drop the row of a newer Invia of the same Message-ID', () async {
    final att = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
    final old = a.holdAttachment = Completer();
    final first = engine.send('a', forward(att));
    await pumpEventQueue();
    expect(await engine.cancelSend('a', id), id);
    a.holdAttachment = null;
    final second = _message(id, body: '<p>Nuovo</p>');
    final deadline = h.clock.now().add(sendWindow);
    expect(await engine.send('a', second), _okAt(deadline));
    old.complete();
    expect(await first, isA<Err<DateTime>>().having((e) => e.failure, 'failure', isA<CancelledFailure>()));
    final row = (await outbox()).single;
    expect(row.raw, contains('Nuovo'));
    expect(row.raw, isNot(contains('Contratto.pdf')));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(await outbox(), isEmpty);
  });

  test(
    'Annulla while the forwarded attachments download: true, the row is gone, send is Cancelled, nothing goes',
    () async {
      final att = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
      a.holdAttachment = Completer();
      final sending = engine.send('a', forward(att));
      await pumpEventQueue();
      // Born at the start of the preparation: not in Bozze, shown in Inviati's outbox as waiting.
      expect((await outbox()).single.sendAfter, greaterThan(h.clock.now().millisecondsSinceEpoch));
      expect(await GetIt.I<InboxRepository>().watchDrafts('a').first, isEmpty);
      expect(await engine.cancelSend('a', id), id);
      expect(await outbox(), isEmpty);
      a.holdAttachment!.complete();
      expect(await sending, isA<Err<DateTime>>().having((e) => e.failure, 'failure', isA<CancelledFailure>()));
      h.clock.advance(sendWindow);
      await pumpEventQueue();
      expect(await outbox(), isEmpty);
      expect(a.sendCalls, 0);
    },
  );

  test('a replay blocked on a Bozza upload does not send a message cancelled meanwhile', () async {
    const other = '<o@example.com>';
    await engine.saveDraft('a', _message(other));
    a.holdDraft = Completer();
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    // The flush of the send is queued behind the upload; Annulla does not wait for the queue.
    await pumpEventQueue();
    expect(await engine.cancelSend('a', id), id);
    a.holdDraft!.complete();
    await flush;
    await pumpEventQueue();
    expect(a.sendCalls, 0);
    expect(await outbox(), isEmpty);
  });

  test('a 400 refusal of the send marks the row failed and is not retried', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.sendFailure = const RejectedFailure('x');
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect((await outbox()).single.failed, isTrue);
    expect((await GetIt.I<InboxRepository>().watchOutbox('a').first).single.failed, isTrue);
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
  });

  test('Annulla while the send is in flight waits for it: false, and the message is in Inviati', () async {
    a.holdSend = Completer();
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    final cancel = engine.cancelSend('a', id);
    await pumpEventQueue();
    a.holdSend!.complete();
    expect(await cancel, isNull);
    await pumpEventQueue(); // the send records its submission before it completes
    expect(await outbox(), isEmpty);
    expect((await inviati()).single.message.messageId, id);
  });

  test('a row cancelled and queued again while another send is in flight is not sent from the old snapshot', () async {
    const other = '<o@example.com>';
    await engine.send('a', _message(id));
    h.clock.advance(const Duration(seconds: 1));
    await engine.send('a', _message(other));
    h.clock.advance(sendWindow);
    a.holdSend = Completer();
    unawaited(engine.flushOutbox('a'));
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    // While the first send is held, the second row (already read as due) is cancelled and queued again.
    final db = GetIt.I<PostinoDatabase>();
    expect(await db.outboxDao.cancel('a', other, h.clock.now().millisecondsSinceEpoch), isTrue);
    await engine.send('a', _message(other, body: '<p>Nuovo</p>'));
    a.holdSend!.complete();
    a.holdSend = null;
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    expect(a.sent.map((e) => e.$1), [id]);
    expect((await outbox()).single.messageId, other);
    // The replacement goes by its own timer.
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent.map((e) => e.$1), [id, other]);
    expect(await outbox(), isEmpty);
  });

  test('a queued Bozza the Provider no longer lists survives the sync, and Annulla reopens it', () async {
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a');
    await engine.syncAll();
    await engine.send('a', _message(id));
    a.removeDraftRemotely(id);
    await engine.syncAll();
    expect(await draftRow(), isNotNull);
    expect(await engine.cancelSend('a', id), id);
    expect(await engine.openDraft('a', id), isA<Ok<OutgoingMessage>>());
  });

  test('a slow send does not leave the next claim already expired', () async {
    const other = '<o@example.com>';
    await engine.send('a', _message(id));
    await engine.send('a', _message(other));
    h.clock.advance(sendWindow);
    final first = a.holdSend = Completer();
    unawaited(engine.flushOutbox('a'));
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    h.clock.advance(sendClaim + const Duration(seconds: 1));
    a.holdSend = Completer();
    first.complete();
    await pumpEventQueue();
    expect(a.sendCalls, 2);
    final claimed = (await outbox()).where((r) => r.claimedUntil != null);
    expect(claimed.single.claimedUntil, greaterThan(h.clock.now().millisecondsSinceEpoch));
    a.holdSend!.complete();
    await pumpEventQueue();
  });

  test('flushOutbox sends the due outbox but leaves the pending Bozza to the next sync', () async {
    const other = '<o@example.com>';
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await engine.saveDraft('a', _message(other));
    h.clock.advance(draftDebounce);
    await engine.flushOutbox('a');
    expect(a.sendCalls, 1);
    expect(a.draftCalls, isEmpty);
    await engine.syncAll();
    expect(a.draftCalls.map((c) => c.$1), contains(other));
  });

  test('two engines on the same database (foreground and WorkManager) replaying at once send once', () async {
    await engine.send('a', _message(id));
    await engine.stop();
    h.clock.advance(sendWindow);
    final other = SyncEngine(
      GetIt.I<MailStore>(),
      GetIt.I<OutboxRepository>(),
      GetIt.I<Clock>(),
      GetIt.I<Connectivity>(),
      GetIt.I<BackgroundSender>(),
      GetIt.I<NewMailNotifier>(),
      GetIt.I<AutoLabeler>(),
      GetIt.I<ErrorLog>(),
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
    expect((await GetIt.I<InboxRepository>().watchOutbox('a').first).single.failed, isTrue);
    // Nothing left to send: the platform is let go.
    expect(h.background.releases, ['a']);

    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(a.sendCalls, 1);

    expect(await engine.cancelSend('a', id), id);
    expect(await outbox(), isEmpty);
  });

  test('a message over the Gmail limit is refused, kept as failed and replaced by the next Invia', () async {
    final r = await engine.send('a', _message(id, body: '<p>${'x' * (gmailSendLimitBytes + 1)}</p>'));
    expect(
      r,
      isA<Err<void>>().having(
        (e) => e.failure,
        'failure',
        isA<SizeLimitFailure>().having((f) => f.limitBytes, 'limitBytes', gmailSendLimitBytes),
      ),
    );
    // Kept as failed (the composer may be gone): Inviati shows it, and a new Invia replaces it.
    expect((await outbox()).single.failed, isTrue);
    expect((await GetIt.I<InboxRepository>().watchOutbox('a').first).single.failed, isTrue);
    final retry = await engine.send('a', _message(id));
    expect(retry, isA<Ok<DateTime>>());
    final rows = await outbox();
    expect(rows.single.failed, isFalse);
    expect(rows.single.raw, isNotEmpty);
  });

  test(
    'during the pause after a RateLimitFailure the flush waits; the message goes with the first sync after it',
    () async {
      engine.start();
      addTearDown(engine.stop);
      await pumpEventQueue();
      final until = h.clock.now().add(const Duration(minutes: 5));
      a
        ..rateLimit(retryAfter: until)
        ..deliver(msg('3'));
      await pumpEventQueue();
      a.rateLimit(on: false);

      await engine.send('a', _message(id));
      h.clock.advance(sendWindow);
      await pumpEventQueue();
      expect(a.sent, isEmpty);
      expect(await outbox(), hasLength(1));

      h.clock.advance(const Duration(minutes: 5));
      await pumpEventQueue();
      expect(a.sent, [(id, 's-1')]);
      expect(await outbox(), isEmpty);
    },
  );

  test('a queued message is not listed in Bozze (local row nor the Provider\'s), and is again after Annulla', () async {
    Future<List<String>> listed() async =>
        (await GetIt.I<InboxRepository>().watchDrafts('a').first).map((m) => m.messageId).toList();
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

  test('a remote-only Bozza with a queued Message-ID is not listed in Bozze, and is after Annulla', () async {
    const remote = '<r@example.com>';
    Future<List<String>> listed() async =>
        (await GetIt.I<InboxRepository>().watchDrafts('a').first).map((m) => m.messageId).toList();
    a.deliverDraft(_message(remote));
    await engine.syncAll();
    expect(await listed(), [remote]);
    expect(await GetIt.I<PostinoDatabase>().draftsDao.byId('a', remote), isNull);

    await engine.send('a', _message(remote));
    expect(await listed(), isEmpty);

    await engine.cancelSend('a', remote);
    expect(await listed(), [remote]);
  });

  test('a sync whose replay hits the send RateLimit makes no sync request until the deadline', () async {
    await engine.send('a', _message(id));
    await engine.stop(); // no timer: the replay is the sync's own
    h.clock.advance(sendWindow);
    a.sendFailure = RateLimitFailure(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    final before = a.syncCalls;
    await engine.syncAll();
    expect(a.sendCalls, 1);
    expect(a.syncCalls, before);

    a.sendFailure = null;
    h.clock.advance(const Duration(minutes: 5));
    await engine.syncAll();
    expect(a.sent, [(id, 's-1')]);
    expect(a.syncCalls, greaterThan(before));
  });

  test('a flushDrafts and a sync queued behind a send that is rate limited make no provider call', () async {
    const other = '<o@example.com>';
    a.holdSend = Completer();
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    await engine.saveDraft('a', _message(other));
    final before = a.syncCalls;
    final queued = [engine.flushDrafts('a'), engine.syncAll()];
    await pumpEventQueue();

    a.sendFailure = RateLimitFailure(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    a.holdSend!.complete();
    await Future.wait(queued);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    expect(a.draftCalls, isEmpty);
    expect(a.syncCalls, before);
  });

  test('a message queued while another Bozza uploads does not upload its own Bozza', () async {
    const other = '<o@example.com>';
    await engine.saveDraft('a', _message(id));
    await engine.saveDraft('a', _message(other));
    a.holdDraft = Completer();
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();
    final first = a.draftHeld;
    expect(first, isNotNull);
    final second = first == id ? other : id;

    await engine.send('a', _message(second));
    a.holdDraft!.complete();
    await flush;
    expect(a.draftCalls.map((c) => c.$1), [first]);
  });

  test('a Bozza upload that finds the remote copy gone after Invia keeps the local Bozza for Annulla', () async {
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a');
    await engine.saveDraft('a', _message(id, body: '<p>edited</p>'));
    a.holdDraft = Completer();
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();
    await engine.send('a', _message(id));
    a.removeDraftRemotely(id);
    a.holdDraft!.complete();
    await flush;
    expect(await draftRow(), isNotNull);
    expect(await engine.cancelSend('a', id), id);
    expect(await engine.openDraft('a', id), isA<Ok<OutgoingMessage>>());
  });

  test('a Bozza upload that ends after Invia deletes the late remote Bozza', () async {
    await engine.saveDraft('a', _message(id));
    a.holdDraft = Completer();
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();
    expect(a.draftHeld, id);
    await engine.send('a', _message(id));
    a.holdDraft!.complete();
    await flush;
    expect(a.drafts.containsKey(id), isFalse);
    expect(a.draftCalls.map((c) => c.$1), [id]);
  });

  test('Annulla after the late remote Bozza was deleted: the local Bozza uploads as new and survives', () async {
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a');
    await engine.saveDraft('a', _message(id));
    a.holdDraft = Completer();
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();
    await engine.send('a', _message(id));
    a.holdDraft!.complete();
    await flush;
    expect(a.drafts.containsKey(id), isFalse);
    expect(await engine.cancelSend('a', id), id);
    a.draftCalls.clear();
    await engine.flushDrafts('a');
    expect(a.draftCalls, [(id, true)]);
    expect(await draftRow(), isNotNull);
  });

  test('a Bozza upload that ends after another engine sent the row deletes the late remote Bozza', () async {
    await engine.saveDraft('a', _message(id));
    a.holdDraft = Completer();
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();
    final other = SyncEngine(
      GetIt.I<MailStore>(),
      GetIt.I<OutboxRepository>(),
      GetIt.I<Clock>(),
      GetIt.I<Connectivity>(),
      GetIt.I<BackgroundSender>(),
      GetIt.I<NewMailNotifier>(),
      GetIt.I<AutoLabeler>(),
      GetIt.I<ErrorLog>(),
    );
    await other.send('a', _message(id));
    h.clock.advance(sendWindow);
    other.start();
    addTearDown(other.stop);
    await pumpEventQueue();
    expect(await draftRow(), isNull);
    a.holdDraft!.complete();
    await flush;
    expect(a.drafts.containsKey(id), isFalse);
  });

  test(
    'a RateLimitFailure of the send pauses the Account: one call, the rest stays queued until the deadline',
    () async {
      engine.start();
      addTearDown(engine.stop);
      await pumpEventQueue();
      await engine.send('a', _message(id));
      await engine.send('a', _message('<y@example.com>'));
      a.sendFailure = RateLimitFailure(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
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
    },
  );

  test(
    'a RateLimitFailure of an Etichetta in the replay stops it: no Bozza upload nor send until the deadline',
    () async {
      a.deliver(msg('1'));
      await engine.syncAll();
      // Offline: the Etichetta, the Bozza and the message wait in the queue, the send due.
      a.goOffline();
      await engine.send('a', _message(id));
      await engine.saveDraft('a', _message('<d@example.com>'));
      await engine.setLabel('a', '1', 'Label_12', add: true);
      h.clock.advance(sendWindow);
      await pumpEventQueue();
      final (labels, drafts, sends) = (a.labelCalls.length, a.draftCalls.length, a.sendCalls);

      a
        ..goOnline()
        ..setLabelFailure = RateLimitFailure(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
      await engine.flushDrafts('a');
      expect(a.labelCalls, hasLength(labels + 1));
      expect(a.draftCalls, hasLength(drafts));
      expect(a.sendCalls, sends);

      a.setLabelFailure = null;
      h.clock.advance(const Duration(minutes: 5));
      await engine.flushDrafts('a');
      expect(a.sent.map((s) => s.$1), [id]);
      expect(a.draftCalls.map((c) => c.$1), contains('<d@example.com>'));
    },
  );

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

  test('Invia holds the platform; the send releases it once', () async {
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

  test('every Invia renews the hold while an older row is queued; one release after both are sent', () async {
    await engine.send('a', _message(id));
    await engine.send('a', _message('<y@example.com>'));
    await pumpEventQueue();
    expect(h.background.holds, ['a', 'a']);
    expect(h.background.releases, isEmpty);

    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(2));
    expect(h.background.releases, ['a']);
  });

  test('Annulla of the only queued message releases the platform', () async {
    await engine.send('a', _message(id));
    await engine.cancelSend('a', id);
    expect(h.background.holds, ['a']);
    expect(h.background.releases, ['a']);
  });

  test(
    'the platform is held before the forwarded attachments download; a failed or cancelled preparation releases it',
    () async {
      final att = a.attach('m0', 'Contratto.pdf', [1, 2, 3]);
      a.holdAttachment = Completer();
      final sending = engine.send('a', forward(att));
      await pumpEventQueue();
      expect(h.background.holds, ['a']);
      expect(h.background.releases, isEmpty);
      expect(await engine.cancelSend('a', id), id);
      expect(h.background.releases, ['a']);
      a.holdAttachment!.complete();
      expect(await sending, isA<Err<DateTime>>());

      a.goOffline();
      final never = a.attach('m0', 'Altro.pdf', [4, 5]);
      expect(await engine.send('a', forward(never)), isA<Err<DateTime>>());
      expect(h.background.holds, ['a', 'a']);
      expect(h.background.releases, ['a', 'a']);
    },
  );

  test('the sent copy does not replace the message a sync cached already: its INBOX label stays', () async {
    // A message to oneself, synced before the send completed (the Provider answers the send with the same id).
    a.deliver(
      Message(
        id: 's-1',
        messageId: id,
        conversationId: 's-1',
        labelIds: const [inboxLabelId, sentLabelId],
        isRead: true,
        isStarred: false,
        from: 'a@example.com',
        to: const ['a@example.com'],
        subject: 's',
        snippet: 'Ciao',
        date: DateTime.utc(2026),
      ),
    );
    await engine.syncAll();
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sendCalls, 1);
    expect(await outbox(), isEmpty);
    final inbox = await GetIt.I<InboxRepository>().watchMessages('a', inboxLabelId).first;
    expect(inbox.single.message.id, 's-1');
    expect((await inviati()).single.message.id, 's-1');
  });

  test('send for an unknown Account is NotFound', () async {
    expect(
      await engine.send('zzz', _message(id)),
      isA<Err<void>>().having((e) => e.failure, 'failure', isA<NotFoundFailure>()),
    );
  });

  test('after the send the cached Provider Bozza is gone at once, without a sync', () async {
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a');
    await engine.syncAll(); // the Provider's DRAFT copy is cached
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));
    expect(await GetIt.I<InboxRepository>().watchDrafts('a').first, isEmpty);
    // Only the Sent copy is left: no unlabelled DRAFT row in the Conversazione.
    final db = GetIt.I<PostinoDatabase>();
    final rows = await (db.select(db.messages)..where((m) => m.accountId.equals('a') & m.messageId.equals(id))).get();
    expect(rows, hasLength(1));
    final labels = await (db.select(
      db.messageLabels,
    )..where((l) => l.accountId.equals('a') & l.messageId.equals(rows.single.id))).get();
    expect(labels.map((l) => l.labelId), ['SENT']);
  });

  test('Annulla of a row already attempted reopens the Bozza under a new Message-ID, which then goes out', () async {
    a.loseSendResponse = true;
    await engine.saveDraft('a', _message(id));
    await engine.flushDrafts('a'); // no draft timer left to replay the outbox
    await engine.send('a', _message(id));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent, hasLength(1));

    final fresh = await engine.cancelSend('a', id);
    expect(fresh, isNotNull);
    expect(fresh, isNot(id));
    expect(await draftRow(), isNull);
    final moved = await GetIt.I<PostinoDatabase>().draftsDao.byId('a', fresh!);
    expect(moved!.body, '<p>Ciao</p>');

    await engine.send('a', _message(fresh));
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(a.sent.map((e) => e.$1), [id, fresh]);
  });

  test('Annulla of a row never attempted keeps the Message-ID', () async {
    await engine.saveDraft('a', _message(id));
    await engine.send('a', _message(id));
    expect(await engine.cancelSend('a', id), id);
    expect(await draftRow(), isNotNull);
  });
}
