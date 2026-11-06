// Conflitti delle Bozze (#149): a Bozza edited here and elsewhere since its last upload waits for the user's choice;
// one sent or deleted elsewhere is still dropped in silence; one edited only here goes as before.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/intent_replayer.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/draft_conflict.dart';
import 'package:postino/core/domain/draft_content.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

OutgoingMessage _draft(String body, {String subject = 's'}) =>
    OutgoingMessage(messageId: _id, from: 'a@example.com', to: const ['b@example.com'], subject: subject, body: body);

const _id = '<x@example.com>';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;

  Future<List<DraftConflict>> conflicts() => GetIt.I<InboxRepository>().watchDraftConflicts().first;
  Future<DraftRow?> row() => GetIt.I<PostinoDatabase>().draftsDao.byId('a', _id);

  setUp(() async {
    h = await Harness.create();
    a = await h.addAccount('a');
    engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
    // On the Provider once: the next upload expects this version.
    await engine.saveDraft('a', _draft('<p>1</p>'));
    await engine.flushDrafts('a');
  });

  /// Edited «on two devices»: elsewhere to [theirs], then here to `<p>mia</p>`, then uploaded.
  Future<void> editedTwice({String theirs = '<p>loro</p>'}) async {
    a.deliverDraft(_draft(theirs, subject: 'loro'));
    await engine.saveDraft('a', _draft('<p>mia</p>'));
    await engine.flushDrafts('a');
  }

  test('edited here and elsewhere: a Conflitto, the Provider untouched and the version here kept', () async {
    await editedTwice();
    expect(await conflicts(), [
      const DraftConflict(
        accountId: 'a',
        messageId: _id,
        mine: DraftContent(to: ['b@example.com'], subject: 's', body: '<p>mia</p>'),
        provider: DraftContent(to: ['b@example.com'], subject: 'loro', body: '<p>loro</p>'),
      ),
    ]);
    expect(a.drafts[_id]!.body, '<p>loro</p>');
    expect(
      await engine.openDraft('a', _id),
      isA<Ok<OutgoingMessage>>().having((r) => r.value.body, 'body', '<p>mia</p>'),
    );

    // Not replayed while open: the user chooses first.
    final calls = a.draftCalls.length;
    h.clock.advance(draftDebounce);
    await engine.flushDrafts('a');
    expect(a.draftCalls, hasLength(calls));
  });

  test('«La tua» uploads the version here over the Provider\'s', () async {
    await editedTwice();
    await engine.resolveDraftConflict((await conflicts()).single, keepMine: true);
    expect(await conflicts(), isEmpty);
    expect(a.drafts[_id]!.body, '<p>mia</p>');
    expect((await row())!.pending, isFalse);
  });

  test('«Del Provider» takes the Provider\'s version here, nothing uploaded', () async {
    await editedTwice();
    final calls = a.draftCalls.length;
    await engine.resolveDraftConflict((await conflicts()).single, keepMine: false);
    expect(await conflicts(), isEmpty);
    expect(a.draftCalls, hasLength(calls));
    final r = (await row())!;
    expect((r.subject, r.body, r.pending), ('loro', '<p>loro</p>', false));

    // The Provider's is now the expected version: the next edit here goes without a Conflitto.
    await engine.saveDraft('a', _draft('<p>dopo</p>'));
    await engine.flushDrafts('a');
    expect(await conflicts(), isEmpty);
    expect(a.drafts[_id]!.body, '<p>dopo</p>');
  });

  test('changed elsewhere to what is wanted here: no Conflitto', () async {
    a.deliverDraft(_draft('<p>uguale</p>'));
    await engine.saveDraft('a', _draft('<p>uguale</p>'));
    await engine.flushDrafts('a');
    expect(await conflicts(), isEmpty);
    expect((await row())!.pending, isFalse);
  });

  test('a Bozza in Conflitto then sent or deleted elsewhere goes at the next sync, its edit here dropped', () async {
    await editedTwice();
    expect(await conflicts(), hasLength(1));
    a.removeDraftRemotely(_id);
    await engine.syncAll();
    expect(await row(), isNull);
    expect(await conflicts(), isEmpty);
  });

  test('the Conflitti of one Account only', () async {
    await editedTwice();
    final repo = GetIt.I<InboxRepository>();
    expect(await repo.watchDraftConflicts(accountId: 'a').first, hasLength(1));
    expect(await repo.watchDraftConflicts(accountId: 'b').first, isEmpty);
  });

  test('sent or deleted elsewhere: the edit here is dropped in silence, no Conflitto', () async {
    a.removeDraftRemotely(_id);
    await engine.saveDraft('a', _draft('<p>mia</p>'));
    await engine.flushDrafts('a');
    expect(await row(), isNull);
    expect(await conflicts(), isEmpty);
  });

  test('edited only here: no Conflitto, still after the 5 s pause', () async {
    await engine.saveDraft('a', _draft('<p>2</p>'));
    h.clock.advance(draftDebounce - const Duration(seconds: 1));
    await pumpEventQueue();
    expect(a.drafts[_id]!.body, '<p>1</p>');
    h.clock.advance(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(a.drafts[_id]!.body, '<p>2</p>');
    expect(await conflicts(), isEmpty);
  });
}
