// The Azioni of the swipes (#147): two voci of the Impostazioni di Postino, `swipe/left` and `swipe/right`.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/swipe_actions_store.dart';
import 'package:postino/core/domain/swipe_actions.dart';

import '../../support/fake_platform.dart';

void main() {
  late PostinoDatabase db;
  late SwipeActionsStore store;
  setUp(() {
    db = PostinoDatabase.inMemory();
    store = SwipeActionsStore(db, FakeClock(DateTime.utc(2026, 11, 6)));
  });
  tearDown(() => db.close());

  test('nothing chosen reads the defaults: left Archivia, right Segna come letto', () async {
    expect(await store.watch().first, swipeActionsDefault);
    expect(swipeActionsDefault, (left: SwipeAction.archive, right: SwipeAction.markRead));
  });

  test('each direction is kept on its own, and watch follows the changes', () async {
    final seen = <SwipeActions>[];
    final sub = store.watch().listen(seen.add);
    addTearDown(sub.cancel);
    await store.set(SwipeDirection.right, SwipeAction.star);
    await store.set(SwipeDirection.left, SwipeAction.applyLabel);
    await pumpEventQueue();
    expect(seen.last, (left: SwipeAction.applyLabel, right: SwipeAction.star));
    expect(await db.postinoSettingsDao.read('swipe/left'), '"applyLabel"');
  });

  test('an unknown or malformed value reads as the default', () async {
    await db.postinoSettingsDao.write('swipe/left', '"posticipa"', at: DateTime.utc(2026));
    await db.postinoSettingsDao.write('swipe/right', 'not json', at: DateTime.utc(2026));
    expect(await store.watch().first, swipeActionsDefault);
  });
}
