// Microsoft adapter on a simulated Graph mailbox (GraphHarness): the contract and the folder moves. No network.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_harness.dart';
import '../../domain/mail_provider_contract.dart';
import '../../domain/mail_provider_search_contract.dart';

void main() {
  mailProviderAuthContract('MicrosoftProvider', GraphHarness.new);
  mailProviderSyncContract('MicrosoftProvider', GraphHarness.new);
  mailProviderLabelContract('MicrosoftProvider', GraphHarness.new);
  mailProviderAttachmentContract('MicrosoftProvider', GraphHarness.new);
  mailProviderActionContract('MicrosoftProvider', GraphHarness.new);
  mailProviderSearchContract('MicrosoftProvider', GraphHarness.new);

  test('a message moved to another folder comes once, in the new folder, with the same id', () async {
    final h = GraphHarness()..deliver(msg('a'));
    final first = okValue(await h.provider.initialSync());
    h.deliver(msg('a', labelIds: [h.viaggiId]));
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    expect(next.messages.single.id, 'a');
    expect(next.messages.single.labelIds, [h.viaggiId]);
    expect(next.removedMessageIds, isEmpty, reason: 'removed from the inbox, new in Viaggi: one message');
  });

  test('a move that lands between two folder rounds is not taken for a deletion at the next sync', () async {
    final h = GraphHarness()..deliver(msg('a'));
    final first = okValue(await h.provider.initialSync());
    var moved = false;
    // The inbox round is done; Viaggi's has not started yet.
    h.onRequest = (r) {
      if (!moved && r.url.path.contains('f-viaggi/messages/delta')) {
        moved = true;
        h.deliver(msg('a', labelIds: [h.viaggiId]));
      }
    };
    final second = okValue(await h.provider.incrementalSync(first.cursor));
    expect(second.messages.single.labelIds, [h.viaggiId]);
    final third = okValue(await h.provider.incrementalSync(second.cursor));
    expect(third.removedMessageIds, isEmpty, reason: 'the inbox reports it @removed, but it is in Viaggi');
  });

  test(
    'a message older than the window moved to a new folder takes its Etichetta: not gone, not left behind',
    () async {
      final h = GraphHarness();
      final first = okValue(await h.provider.initialSync());
      // Older than 90 days, in the cache all the same (its Conversazione opened, or the window moved on).
      h.deliver(msg('o', date: GraphHarness.now.subtract(const Duration(days: 200))));
      final cached = okValue(await h.provider.incrementalSync(first.cursor));
      expect(cached.messages.map((m) => m.id), ['o']);
      h
        ..createFolderElsewhere('f-archivio', 'Archivio')
        ..deliver(msg('o', date: GraphHarness.now.subtract(const Duration(days: 200)), labelIds: const ['f-archivio']));
      final next = okValue(await h.provider.incrementalSync(cached.cursor));
      expect(next.removedMessageIds, isEmpty);
      expect(next.messages.single.labelIds, ['f-archivio'], reason: 'the filtered first round of the folder omits it');
    },
  );

  test('a search folder is no Etichetta and leaves the Etichette of the messages it shows as they are', () async {
    final h = GraphHarness()
      ..createSearchFolderElsewhere('f-unread', 'Da leggere')
      ..deliver(msg('a'));
    final batch = okValue(await h.provider.initialSync());
    expect(batch.labels!.map((l) => l.id), [h.viaggiId]);
    expect(batch.messages.single.labelIds, [inboxLabelId]);
    expect(h.requests.where((r) => r.url.path.contains('f-unread')), isEmpty);
  });

  test('only the last 90 days are synced', () async {
    final h = GraphHarness()
      ..deliver(msg('old', date: GraphHarness.now.subtract(const Duration(days: 91))))
      ..deliver(msg('new', date: GraphHarness.now.subtract(const Duration(days: 89))));
    expect(okValue(await h.provider.initialSync()).messages.map((m) => m.id), ['new']);
  });

  test('nothing changed: an empty batch, the Etichette not read again, and the cursor stays valid', () async {
    final h = GraphHarness()..deliver(msg('a'));
    final first = okValue(await h.provider.initialSync());
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    expect(next.messages, isEmpty);
    expect(next.removedMessageIds, isEmpty);
    expect(next.labels, isNull);
    h.deliver(msg('b'));
    expect(okValue(await h.provider.incrementalSync(next.cursor)).messages.map((m) => m.id), ['b']);
  });

  test('a folder created elsewhere comes as an Etichetta, its messages with it', () async {
    final h = GraphHarness();
    final first = okValue(await h.provider.initialSync());
    h
      ..createFolderElsewhere('f-lavoro', 'Lavoro')
      ..createFolderElsewhere('f-progetti', 'Progetti', parent: 'f-lavoro')
      ..deliver(msg('p', labelIds: const ['f-progetti']));
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    expect(next.labels!.map((l) => (l.id, l.name, l.kind)), [
      ('f-viaggi', 'Viaggi', LabelKind.cartella),
      ('f-lavoro', 'Lavoro', LabelKind.cartella),
      ('f-progetti', 'Lavoro/Progetti', LabelKind.cartella),
    ]);
    expect(next.messages.single.labelIds, ['f-progetti']);
  });

  test('a folder deleted elsewhere is NotFound: the initial sync redone drops its messages', () async {
    final h = GraphHarness()
      ..createFolderElsewhere('f-lavoro', 'Lavoro')
      ..deliver(msg('p', labelIds: const ['f-lavoro']));
    final first = okValue(await h.provider.initialSync());
    h.deleteFolderElsewhere('f-lavoro');
    expect(await h.provider.incrementalSync(first.cursor), isErr<NotFoundFailure>());
    expect(okValue(await h.provider.initialSync()).messages, isEmpty);
  });

  test('Cestino, Spam and Posta in uscita are not synced', () async {
    final h = GraphHarness();
    for (final (key, label) in [('t', trashLabelId), ('j', spamLabelId), ('i', inboxLabelId)]) {
      h.deliver(msg(key, labelIds: [label]));
    }
    expect(okValue(await h.provider.initialSync()).messages.map((m) => m.id), ['i']);
    final deltas = h.requests.map((r) => r.url.path).where((p) => p.endsWith('/messages/delta'));
    expect(deltas.where((p) => p.contains('f-deleted') || p.contains('f-junk') || p.contains('f-outbox')), isEmpty);
  });

  test('no change signal: it is down, and the poll brings the changes (ADR 0008)', () async {
    expect(await GraphHarness().provider.changes.toList(), [ChangeSignal.down]);
  });

  test('a cursor that is not one is NotFound', () async {
    expect(await GraphHarness().provider.incrementalSync('4242'), isErr<NotFoundFailure>());
  });
}
