// Etichette automatiche (#107): one voce per Account in the Impostazioni di Postino.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/auto_labels_store.dart';
import 'package:postino/core/data/postino_database.dart';

void main() {
  late PostinoDatabase db;
  late AutoLabelsStore store;
  setUp(() {
    db = PostinoDatabase.inMemory();
    store = AutoLabelsStore(db);
  });
  tearDown(() => db.close());

  test('nothing set up reads empty', () async {
    expect(await store.watch('a1').first, isEmpty);
  });

  test('switch and description are kept per Account; off keeps the description', () async {
    await store.setAutomatic('a1', 'L1', automatic: true);
    await store.setDescription('a1', 'L1', '  Fatture  ');
    await store.setAutomatic('a2', 'L9', automatic: true);
    expect(await store.watch('a1').first, {'L1': (automatic: true, description: 'Fatture')});

    await store.setAutomatic('a1', 'L1', automatic: false);
    expect(await store.watch('a1').first, {'L1': (automatic: false, description: 'Fatture')});
    expect(await store.watch('a2').first, {'L9': (automatic: true, description: null)});
  });

  test('a blank description removes it, and an Etichetta left with nothing removes the voce', () async {
    await store.setAutomatic('a1', 'L1', automatic: true);
    await store.setDescription('a1', 'L1', 'x');
    await store.setDescription('a1', 'L1', '   ');
    await store.setAutomatic('a1', 'L1', automatic: false);
    expect(await store.watch('a1').first, isEmpty);
    expect(await db.select(db.postinoSettings).get(), isEmpty);
  });

  test('watch follows the changes, and two quick edits do not lose each other', () async {
    final seen = <Object>[];
    final sub = store.watch('a1').listen(seen.add);
    addTearDown(sub.cancel);
    await Future.wait([
      store.setAutomatic('a1', 'L1', automatic: true),
      store.setAutomatic('a1', 'L2', automatic: true),
    ]);
    await pumpEventQueue();
    expect(seen.last, {'L1': (automatic: true, description: null), 'L2': (automatic: true, description: null)});
  });
}
