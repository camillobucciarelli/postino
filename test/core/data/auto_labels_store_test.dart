// Etichette automatiche (#107): one voce per Account in the Impostazioni di Postino.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/auto_labels_store.dart';
import 'package:postino/core/data/postino_database.dart';

import '../../support/fake_platform.dart';

/// The activation of the Etichette switched on at the test clock's time.
final _now = DateTime.utc(2026, 11, 5).millisecondsSinceEpoch;

void main() {
  late PostinoDatabase db;
  late AutoLabelsStore store;
  setUp(() {
    db = PostinoDatabase.inMemory();
    store = AutoLabelsStore(db, FakeClock(DateTime.utc(2026, 11, 5)));
  });
  tearDown(() => db.close());

  test('nothing set up reads empty', () async {
    expect(await store.watch('a1').first, isEmpty);
  });

  test('switch and description are kept per Account; off keeps the description', () async {
    await store.setAutomatic('a1', 'L1', automatic: true);
    await store.setDescription('a1', 'L1', '  Fatture  ');
    await store.setAutomatic('a2', 'L9', automatic: true);
    expect(await store.watch('a1').first, {'L1': (automatic: true, description: 'Fatture', activatedAt: _now)});

    await store.setAutomatic('a1', 'L1', automatic: false);
    expect(await store.watch('a1').first, {'L1': (automatic: false, description: 'Fatture', activatedAt: null)});
    expect(await store.watch('a2').first, {'L9': (automatic: true, description: null, activatedAt: _now)});
  });

  test('a blank description removes it, and an Etichetta left with nothing leaves a tombstone', () async {
    await store.setAutomatic('a1', 'L1', automatic: true);
    await store.setDescription('a1', 'L1', 'x');
    await store.setDescription('a1', 'L1', '   ');
    await store.setAutomatic('a1', 'L1', automatic: false);
    expect(await store.watch('a1').first, isEmpty);
    expect(await db.postinoSettingsDao.read('auto_labels/a1'), isNull);
    expect((await db.select(db.postinoSettings).getSingle()).deleted, isTrue);
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
    expect(seen.last, {
      'L1': (automatic: true, description: null, activatedAt: _now),
      'L2': (automatic: true, description: null, activatedAt: _now),
    });
  });

  test(
    'the activation is stamped when the switch goes on, kept while on, and the description does not touch it',
    () async {
      final clock = FakeClock(DateTime.utc(2026, 11, 5));
      store = AutoLabelsStore(db, clock);
      await store.setAutomatic('a1', 'L1', automatic: true);
      clock.advance(const Duration(hours: 1));
      await store.setAutomatic('a1', 'L1', automatic: true);
      await store.setDescription('a1', 'L1', 'Fatture');
      expect((await store.watch('a1').first)['L1']!.activatedAt, _now);

      await store.setAutomatic('a1', 'L1', automatic: false);
      await store.setAutomatic('a1', 'L1', automatic: true);
      expect((await store.watch('a1').first)['L1']!.activatedAt, _now + const Duration(hours: 1).inMilliseconds);
    },
  );

  test('an Etichetta automatica saved without activation is active since the voce was written, and stays so', () async {
    final written = DateTime.utc(2026, 11, 2);
    await db.postinoSettingsDao.write('auto_labels/a1', '{"L1": {"automatic": true}}', at: written);
    expect((await store.watch('a1').first)['L1']!.activatedAt, written.millisecondsSinceEpoch);

    // A later write keeps it: the activation does not move with the voce.
    await store.setDescription('a1', 'L2', 'Fatture');
    expect((await store.watch('a1').first)['L1']!.activatedAt, written.millisecondsSinceEpoch);
  });
}
