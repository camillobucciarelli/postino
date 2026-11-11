// Microsoft adapter on a simulated Graph mailbox (GraphHarness): the contract and the folder moves. No network.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_harness.dart';
import '../../domain/mail_provider_contract.dart';

/// Bodies on request and Conversazioni come with T3, the Azioni with T4.
const _pending = {'body': 'T3', 'conversation': 'T3', 'action': 'T4'};

void main() {
  mailProviderAuthContract('MicrosoftProvider', GraphHarness.new, pending: _pending);
  mailProviderSyncContract('MicrosoftProvider', GraphHarness.new, pending: _pending);
  mailProviderLabelContract('MicrosoftProvider', GraphHarness.new, pending: _pending);

  test('a message moved to another folder comes once, in the new folder, with the same id', () async {
    final h = GraphHarness()..deliver(msg('a'));
    final first = okValue(await h.provider.initialSync());
    h.deliver(msg('a', labelIds: [h.viaggiId]));
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    expect(next.messages.single.id, 'a');
    expect(next.messages.single.labelIds, [h.viaggiId]);
    expect(next.removedMessageIds, isEmpty, reason: 'removed from the inbox, new in Viaggi: one message');
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

  test('Cestino, Posta indesiderata and Posta in uscita are not synced', () async {
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
