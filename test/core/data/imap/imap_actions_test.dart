// The Azioni on IMAP against GreenMail (#165): what the contract does not cover.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/gmail_recorded.dart' show okValue;
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP actions', () {}, skip: reason);
    return;
  }
  tearDownAll(ImapHarness.stopServer);

  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());

  /// The folders and flags of the message `key` after a full sync.
  Future<Message> now(String key) async =>
      okValue(await h.provider.initialSync()).messages.singleWhere((m) => m.messageId == '<$key@example.com>');

  test('moved to another folder while «Segna come letto» was queued: applied there, found by Message-ID', () async {
    await h.deliver(msg('a'));
    final queued = h.idOf('a');
    await h.deliver(msg('a', labelIds: [h.viaggiId]));
    expect(h.idOf('a'), isNot(queued));
    expect(okValue(await h.provider.applyAction(queued, const MarkRead(), expected: false)), isA<ActionApplied>());
    final m = await now('a');
    expect(m.isRead, isTrue);
    expect(m.labelIds, [h.viaggiId]);
  });

  test('«Archivia» of a message that went to the Cestino meanwhile: a Conflitto on the placement', () async {
    await h.deliver(msg('a'));
    final queued = h.idOf('a');
    await h.deliver(msg('a', labelIds: const [trashLabelId]));
    expect(
      okValue(await h.provider.applyAction(queued, const Archive(), expected: Placement.inbox)),
      isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', Placement.trash),
    );
    expect((await now('a')).labelIds, contains(trashLabelId));
  });

  test('«Archivia» of a message already in a folder of its own: nothing written, it stays there', () async {
    await h.deliver(msg('a', labelIds: [h.viaggiId]));
    final id = h.idOf('a');
    expect(okValue(await h.provider.applyAction(id, const Archive(), expected: Placement.inbox)), isA<ActionApplied>());
    expect(h.idOf('a'), id);
    expect((await now('a')).labelIds, [h.viaggiId]);
  });

  test('«Archivia» without an Archive folder creates «Archivio» once, even for two close Archivia', () async {
    await h.deliver(msg('a'));
    await h.deliver(msg('b'));
    final results = await Future.wait([
      h.provider.applyAction(h.idOf('a'), const Archive(), expected: Placement.inbox),
      h.provider.applyAction(h.idOf('b'), const Archive(), expected: Placement.inbox),
    ]);
    expect(results.map(okValue), everyElement(isA<ActionApplied>()));
    final names = await h.withClient((c) async => [for (final b in await c.listMailboxes(recursive: true)) b.path]);
    expect(names.where((n) => n == 'Archivio'), hasLength(1));
    final synced = okValue(await h.provider.initialSync());
    expect(synced.labels!.map((l) => l.name), contains('Archivio'));
    expect(
      {for (final m in synced.messages) m.messageId: m.labelIds.single},
      {'<a@example.com>': 'cartella:Archivio', '<b@example.com>': 'cartella:Archivio'},
    );
  });

  test('«Elimina» moves to the Cestino, and there it is already as wanted', () async {
    await h.deliver(msg('a'));
    final id = h.idOf('a');
    expect(okValue(await h.provider.applyAction(id, const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
    expect((await now('a')).labelIds, [trashLabelId]);
    // The id it had is gone, found again by Message-ID in the Cestino: nothing to do.
    expect(okValue(await h.provider.applyAction(id, const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
    expect((await now('a')).labelIds, [trashLabelId]);
  });

  test('a message expunged elsewhere is messaggioSparito, nothing found by Message-ID', () async {
    await h.deliver(msg('a'));
    final id = h.idOf('a');
    await h.removeRemotely('a');
    expect(okValue(await h.provider.applyAction(id, const MarkRead(), expected: false)), isA<ActionMessageGone>());
  });
}
