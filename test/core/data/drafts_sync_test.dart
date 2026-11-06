// Bozze (#35): local save on every edit, the Provider hears it after the debounce or at once on leaving,
// nothing is lost offline or while Da ricollegare, and what was sent or deleted elsewhere is dropped in silence.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/intent_replayer.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

OutgoingMessage _draft(String messageId, {String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(messageId: messageId, from: 'a@example.com', to: const ['b@example.com'], subject: 's', body: body);

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;
  const id = '<x@example.com>';

  Future<List<Message>> drafts() => GetIt.I<InboxRepository>().watchDrafts('a').first;
  Future<DraftRow?> row([String messageId = id]) => GetIt.I<PostinoDatabase>().draftsDao.byId('a', messageId);

  setUp(() async {
    h = await Harness.create();
    a = await h.addAccount('a');
    engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
  });

  test('each edit restarts the 5 s pause; then one save with the last content; a later one updates', () async {
    await engine.saveDraft('a', _draft(id, body: '<p>1</p>'));
    h.clock.advance(const Duration(seconds: 3));
    await engine.saveDraft('a', _draft(id, body: '<p>2</p>'));
    h.clock.advance(const Duration(seconds: 4));
    await pumpEventQueue();
    expect(a.draftCalls, isEmpty);
    expect((await row())!.pending, isTrue);

    h.clock.advance(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(a.draftCalls, [(id, true)]);
    expect(a.drafts[id]!.body, '<p>2</p>');
    expect((await row())!.pending, isFalse);

    await engine.saveDraft('a', _draft(id, body: '<p>3</p>'));
    h.clock.advance(const Duration(seconds: 5));
    await pumpEventQueue();
    expect(a.draftCalls, [(id, true), (id, false)]);
    expect(a.drafts[id]!.body, '<p>3</p>');
  });

  test('flushDrafts sends at once and stops the pause; a new edit starts its own', () async {
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    expect(a.draftCalls, [(id, true)]);
    h.clock.advance(const Duration(seconds: 3));
    await engine.saveDraft('a', _draft(id, body: '<p>2</p>'));
    h.clock.advance(const Duration(seconds: 2));
    await pumpEventQueue();
    expect(a.draftCalls, [(id, true)]);
    h.clock.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(a.draftCalls, [(id, true), (id, false)]);
  });

  test('offline the Bozza stays queued and goes when the network returns', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.goOffline();
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    expect(a.draftCalls, isEmpty);
    expect((await row())!.pending, isTrue);

    h.clock.advance(draftDebounce);
    a.goOnline();
    h.connectivity.online = true;
    await pumpEventQueue();
    expect(a.draftCalls, [(id, true)]);
    expect((await row())!.pending, isFalse);
  });

  test(
    'during the pause after a RateLimitFailure the flush waits; the Bozza goes with the first sync after it',
    () async {
      engine.start();
      addTearDown(engine.stop);
      await pumpEventQueue();
      final until = h.clock.now().add(const Duration(minutes: 5));
      a
        ..rateLimit(retryAfter: until)
        ..deliver(msg('3')); // signal -> sync -> RateLimitFailure with retryAfter
      await pumpEventQueue();
      a.rateLimit(on: false);

      await engine.saveDraft('a', _draft(id));
      await engine.flushDrafts('a');
      expect(a.draftCalls, isEmpty);
      expect((await row())!.pending, isTrue);

      h.clock.advance(const Duration(minutes: 5));
      await pumpEventQueue();
      expect(a.draftCalls, [(id, true)]);
      expect((await row())!.pending, isFalse);
    },
  );

  test('a local edit of a Bozza sent or deleted elsewhere is dropped in silence', () async {
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    a.removeDraftRemotely(id);
    await engine.saveDraft('a', _draft(id, body: '<p>2</p>'));
    await engine.flushDrafts('a');
    expect(a.draftCalls, [(id, true), (id, false)]);
    expect(await row(), isNull);
    expect(await drafts(), isEmpty);
  });

  test('while Da ricollegare the Bozza waits; it goes after the reconnection', () async {
    final store = GetIt.I<MailStore>();
    a.breakAuth();
    await engine.syncAll();
    expect((await store.accounts()).single.status, AccountStatus.daRicollegare);
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    expect(a.draftCalls, isEmpty);

    // What AccountsService.connectGmail does once the user consents again.
    h.clock.advance(draftDebounce);
    a.restoreAuth();
    await store.setStatus('a', AccountStatus.attivo);
    await engine.syncAll();
    expect(a.draftCalls, [(id, true)]);
    expect((await row())!.pending, isFalse);
  });

  test('a synced Bozza gone from the Bozze folder disappears after a sync', () async {
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    await engine.syncAll();
    expect((await row())!.remoteKnown, isTrue);
    a.removeDraftRemotely(id);
    await engine.syncAll();
    expect(await row(), isNull);
  });

  test('an acknowledged Bozza never listed by a sync, gone elsewhere, disappears after a sync', () async {
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    a.removeDraftRemotely(id);
    await engine.syncAll();
    expect(await row(), isNull);
  });

  test('an acknowledged Bozza that a sync lists is kept', () async {
    await engine.saveDraft('a', _draft(id));
    await engine.flushDrafts('a');
    await engine.syncAll();
    expect(await row(), isNotNull);
    expect((await drafts()).map((m) => m.messageId), [id]);
  });

  test('watchDrafts lists local Bozze and those of other clients, each once', () async {
    a.deliverDraft(_draft('<y@example.com>', body: '<p>Da altrove</p>'));
    await engine.syncAll();
    await engine.saveDraft('a', _draft(id, body: '<p>Ciao <b>mondo</b></p>'));
    await engine.flushDrafts('a');
    await engine.syncAll(); // the Provider now lists <x> too
    final list = await drafts();
    expect(list.map((m) => m.messageId), [id, '<y@example.com>']);
    final x = list.first;
    expect((x.id, x.conversationId, x.from), (id, id, 'a@example.com'));
    expect(x.labelIds, ['DRAFT']);
    expect(x.snippet, 'Ciao mondo');
    expect(x.date, h.clock.now());
  });

  test('openDraft of a Bozza of another client downloads its body and keeps it here', () async {
    a.deliverDraft(_draft('<y@example.com>', body: '<p>Da altrove</p>'));
    await engine.syncAll();
    final opened = await engine.openDraft('a', '<y@example.com>');
    expect(opened, isA<Ok<OutgoingMessage>>().having((r) => r.value.body, 'body', '<p>Da altrove</p>'));
    final r = (await row('<y@example.com>'))!;
    expect((r.pending, r.synced, r.remoteKnown), (false, true, true));
    expect(await engine.openDraft('a', '<nope>'), isA<Err<Object?>>());
  });

  test('a Bozza written or deleted by another client shows up on the poll, with the change signal up', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.deliverDraft(_draft('<y@example.com>', body: '<p>Da altrove</p>'));
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect((await drafts()).map((m) => m.messageId), ['<y@example.com>']);
    a.removeDraftRemotely('<y@example.com>');
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(await drafts(), isEmpty);
  });

  test('a background replay leaves a Bozza edited within the pause to its timer; the flush sends it', () async {
    await engine.saveDraft('a', _draft(id));
    await engine.syncAll();
    expect(a.draftCalls, isEmpty);
    h.clock.advance(draftDebounce);
    await pumpEventQueue();
    expect(a.draftCalls, [(id, true)]);
  });

  test(
    'openDraft of a Bozza whose Account is removed during the body download is not found, and keeps nothing',
    () async {
      a.deliverDraft(_draft('<y@example.com>', body: '<p>Da altrove</p>'));
      await engine.syncAll();
      final hold = a.holdBody = Completer<void>();
      final opening = engine.openDraft('a', '<y@example.com>');
      await pumpEventQueue();
      await GetIt.I<PostinoDatabase>().accountsDao.remove('a');
      a.holdBody = null;
      hold.complete();

      expect((await opening as Err).failure, isA<NotFoundFailure>());
      expect(await GetIt.I<PostinoDatabase>().select(GetIt.I<PostinoDatabase>().drafts).get(), isEmpty);
    },
  );

  test('openDraft of a plain-text Bozza keeps its line breaks and paragraphs, escaped', () async {
    a.deliverDraft(_draft('<y@example.com>'));
    a.bodies['d-1'] = const MessageBody('Prima\nSeconda\n\nTerza <b> & co', BodyKind.testo);
    await engine.syncAll();
    final opened = await engine.openDraft('a', '<y@example.com>');
    expect((opened as Ok<OutgoingMessage>).value.body, '<p>Prima<br>Seconda</p><p>Terza &lt;b&gt; &amp; co</p>');
  });

  test('openDraft of a Bozza of another client with attachments is refused: saving would drop them', () async {
    a
      ..deliverDraft(_draft('<y@example.com>'))
      ..attach('d-1', 'contratto.pdf', [1, 2, 3]);
    await engine.syncAll();
    expect(
      await engine.openDraft('a', '<y@example.com>'),
      isA<Err<OutgoingMessage>>().having((r) => r.failure, 'failure', isA<DraftWithAttachmentsFailure>()),
    );
    expect(await row('<y@example.com>'), isNull);
  });

  test('a Bozza with attachments is refused again once its body is in the cache', () async {
    a
      ..deliverDraft(_draft('<y@example.com>'))
      ..attach('d-1', 'contratto.pdf', [1, 2, 3]);
    await engine.syncAll();
    for (var i = 0; i < 2; i++) {
      expect(
        await engine.openDraft('a', '<y@example.com>'),
        isA<Err<OutgoingMessage>>().having((r) => r.failure, 'failure', isA<DraftWithAttachmentsFailure>()),
      );
    }
    expect(await row('<y@example.com>'), isNull);
  });

  test('openDraft of a reply written elsewhere is refused; a Bozza alone in its Conversazione opens', () async {
    a
      ..deliver(msg('m-1', conversationId: 't-1'))
      ..deliverDraft(_draft('<r@example.com>'), conversationId: 't-1')
      ..deliverDraft(_draft('<y@example.com>'));
    await engine.syncAll();
    expect(
      await engine.openDraft('a', '<r@example.com>'),
      isA<Err<OutgoingMessage>>().having((r) => r.failure, 'failure', isA<DraftReplyFailure>()),
    );
    expect(await row('<r@example.com>'), isNull);
    expect(await engine.openDraft('a', '<y@example.com>'), isA<Ok<Object?>>());
  });

  test('openDraft wraps a plain text Bozza in a paragraph', () async {
    a.deliverDraft(_draft('<y@example.com>', body: 'Ciao <mondo>'));
    a.bodies['d-1'] = const MessageBody('Ciao <mondo>', BodyKind.testo);
    await engine.syncAll();
    final opened = await engine.openDraft('a', '<y@example.com>') as Ok<OutgoingMessage>;
    expect(opened.value.body, '<p>Ciao &lt;mondo&gt;</p>');
  });

  test('openDraft of a Bozza of another client keeps its Ccn', () async {
    a.deliverDraft(
      const OutgoingMessage(
        messageId: '<y@example.com>',
        from: 'a@example.com',
        to: ['b@example.com'],
        bcc: ['Dee <dee@example.com>'],
        subject: 's',
        body: '<p>x</p>',
      ),
    );
    await engine.syncAll();
    final opened = await engine.openDraft('a', '<y@example.com>') as Ok<OutgoingMessage>;
    expect(opened.value.bcc, ['Dee <dee@example.com>']);
  });

  test('openDraft takes the newer version edited elsewhere, unless an edit here is waiting', () async {
    await engine.saveDraft('a', _draft(id, body: '<p>Qui</p>'));
    await engine.flushDrafts('a');
    final later = h.clock.now().add(const Duration(minutes: 1));
    a.deliverDraft(_draft(id, body: '<p>Altrove</p>'), date: later);
    await engine.syncAll();
    final opened = await engine.openDraft('a', id) as Ok<OutgoingMessage>;
    expect(opened.value.body, '<p>Altrove</p>');
    expect((await row())!.body, '<p>Altrove</p>');

    // An edit here not yet on the Provider wins (the Conflitto is passo 3).
    await engine.saveDraft('a', _draft(id, body: '<p>Di nuovo qui</p>'));
    a.deliverDraft(_draft(id, body: '<p>Ancora altrove</p>'), date: later.add(const Duration(minutes: 1)));
    await engine.syncAll();
    final again = await engine.openDraft('a', id) as Ok<OutgoingMessage>;
    expect(again.value.body, '<p>Di nuovo qui</p>');
  });

  test('a forwarded attachment gone from the Provider never deletes the Bozza: it stays pending', () async {
    await engine.saveDraft('a', _draft(id, body: '<p>Il mio testo</p>'));
    // What the adapter reports when the attachment cannot be fetched (never NotFound).
    a.saveDraftFailure = const UnexpectedFailure('forwarded attachment gone');
    await engine.flushDrafts('a');
    final kept = await row();
    expect(kept, isNotNull);
    expect(kept!.body, '<p>Il mio testo</p>');
    expect(kept.pending, isTrue);
  });

  test('a reply created here stays openable after the Provider returns it with a later date', () async {
    a.deliver(msg('m-1', conversationId: 't-1'));
    await engine.syncAll();
    const reply = OutgoingMessage(
      messageId: id,
      from: 'a@example.com',
      to: ['b@example.com'],
      subject: 'Re: s',
      body: '<p>Risposta</p>',
      inReplyTo: '<m-1@example.com>',
      references: ['<m-1@example.com>'],
      conversationId: 't-1',
    );
    await engine.saveDraft('a', reply);
    h.clock.advance(draftDebounce);
    await pumpEventQueue();
    expect((await row())!.pending, isFalse);
    // The Provider dates it at upload time, after the local edit.
    a.deliverDraft(reply, date: h.clock.now().add(const Duration(seconds: 30)), conversationId: 't-1');
    await engine.syncAll();
    final opened = await engine.openDraft('a', id) as Ok<OutgoingMessage>;
    expect(opened.value, reply);
  });

  test('a forward with attachments created here stays openable after the Provider returns it', () async {
    const fwd = OutgoingMessage(
      messageId: id,
      from: 'a@example.com',
      to: ['b@example.com'],
      subject: 'Fwd: s',
      body: '<p>Inoltro</p>',
      attachments: [ForwardedAttachment('m-1', Attachment(id: '1', name: 'c.pdf', size: 3))],
    );
    await engine.saveDraft('a', fwd);
    h.clock.advance(draftDebounce);
    await pumpEventQueue();
    a
      ..deliverDraft(fwd, date: h.clock.now().add(const Duration(seconds: 30)))
      ..attach('d-1', 'c.pdf', [1, 2, 3]);
    await engine.syncAll();
    final opened = await engine.openDraft('a', id) as Ok<OutgoingMessage>;
    expect(opened.value.attachments, hasLength(1));
  });
}
