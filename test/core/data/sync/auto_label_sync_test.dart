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
  final after = DateTime.utc(2026, 10, 28, 13);

  /// The engine runs after the sync, not awaited by it: waits until [done], or a while.
  Future<void> settle(bool Function() done) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await pumpEventQueue();
    }
  }

  setUp(() async {
    h = await Harness.create();
    h.embedder.vectorOf = (text) => text.contains('Viaggi') || text.contains('Volo') ? [1, 0] : [0, 1];
    await getIt<AutoLabelsRepository>().setAutomatic('a', _viaggi, automatic: true);
    a = (await h.addAccount('a'))..deliver(msg('1', subject: 'Volo per Lisbona', date: after));
  });

  test('the initial sync classifies nothing; a new mail of an incremental one reaches the Provider labelled', () async {
    await getIt<SyncEngine>().syncAll();
    await settle(() => h.embedder.texts.isNotEmpty);
    expect(h.embedder.texts, isEmpty);
    expect(a.labelCalls, isEmpty);

    a.deliver(msg('2', subject: 'Volo per Oporto', date: after));
    await getIt<SyncEngine>().syncAll();
    await settle(() => a.labelCalls.isNotEmpty);
    expect(a.labelCalls, [('2', _viaggi, true)]);
  });

  test('the model not ready: no Etichetta', () async {
    h.embedder.vectorOf = (_) => null;
    await getIt<SyncEngine>().syncAll();
    a.deliver(msg('2', subject: 'Volo per Oporto', date: after));
    await getIt<SyncEngine>().syncAll();
    await settle(() => h.embedder.texts.isNotEmpty);
    await settle(() => false);
    expect(h.embedder.texts, isNotEmpty);
    expect(a.labelCalls, isEmpty);
  });
}
