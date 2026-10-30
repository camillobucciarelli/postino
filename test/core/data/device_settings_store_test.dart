// Impostazioni del dispositivo (#60): a key/value table, the sidebar choice is the first.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/postino_database.dart';

void main() {
  late PostinoDatabase db;
  late DeviceSettingsStore store;
  setUp(() {
    db = PostinoDatabase.inMemory();
    store = DeviceSettingsStore(db);
  });
  tearDown(() => db.close());

  test('the sidebar choice is null until made, then kept: expanded, icons, cleared', () async {
    expect(await store.sidebarExpanded(), isNull);
    await store.setSidebarExpanded(true);
    expect(await store.sidebarExpanded(), isTrue);
    await store.setSidebarExpanded(false);
    expect(await store.sidebarExpanded(), isFalse);
    await store.setSidebarExpanded(null);
    expect(await store.sidebarExpanded(), isNull);
    expect(await db.select(db.deviceSettings).get(), isEmpty);
  });
}
