// Etichettatura automatica (#109) end to end: la sync incrementale porta la mail nuova, il motore la classifica
// e l'Etichetta arriva al Provider passando dalla coda offline.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/auto_labels_repository.dart';
import 'package:postino/main.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

const _viaggi = 'Label_12';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;
  final after = DateTime.utc(2026, 10, 28, 13);

  /// A sync, then the Etichettatura automatica it started and its replay, which the sync does not wait for.
  Future<void> sync() async {
    await engine.syncAll();
    await engine.autoLabeling['a'];
  }

  setUp(() async {
    h = await Harness.create();
    engine = getIt<SyncEngine>();
    h.embedder.vectorOf = (text) => text.contains('Viaggi') || text.contains('Volo') ? [1, 0] : [0, 1];
    await getIt<AutoLabelsRepository>().setAutomatic('a', _viaggi, automatic: true);
    a = (await h.addAccount('a'))..deliver(msg('1', subject: 'Volo per Lisbona', date: after));
  });

  test('the initial sync classifies nothing; a new mail of an incremental one reaches the Provider labelled', () async {
    await sync();
    expect(h.embedder.texts, isEmpty);
    expect(a.labelCalls, isEmpty);

    a.deliver(msg('2', subject: 'Volo per Oporto', date: after));
    await sync();
    expect(a.labelCalls, [('2', _viaggi, true)]);
  });

  test('a new mail already read and out of the inbox is labelled too', () async {
    await sync();
    a.deliver(msg('2', subject: 'Volo per Oporto', date: after, isRead: true, labelIds: const []));
    await sync();
    expect(a.labelCalls, [('2', _viaggi, true)]);
  });

  test('the model not ready: no Etichetta', () async {
    h.embedder.vectorOf = (_) => null;
    await sync();
    a.deliver(msg('2', subject: 'Volo per Oporto', date: after));
    await sync();
    expect(h.embedder.texts, isNotEmpty);
    expect(a.labelCalls, isEmpty);
  });
}
