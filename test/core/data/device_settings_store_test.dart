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
    await store.setSidebarExpanded(expanded: true);
    expect(await store.sidebarExpanded(), isTrue);
    await store.setSidebarExpanded(expanded: false);
    expect(await store.sidebarExpanded(), isFalse);
    await store.setSidebarExpanded(expanded: null);
    expect(await store.sidebarExpanded(), isNull);
    expect(await db.select(db.deviceSettings).get(), isEmpty);
  });

  test('the list width is null until chosen, then kept as it was chosen', () async {
    expect(await store.listWidth(), isNull);
    await store.setListWidth(412);
    expect(await store.listWidth(), 412);
    await store.setListWidth(380.5);
    expect(await store.listWidth(), 380.5);
  });

  test('the avvio al login is null until the default or the user chose it (#38)', () async {
    expect(await store.launchAtLogin(), isNull);
    await store.setLaunchAtLogin(enabled: true);
    expect(await store.launchAtLogin(), isTrue);
    await store.setLaunchAtLogin(enabled: false);
    expect(await store.launchAtLogin(), isFalse);
  });

  test('the notifications are not asked until the explanation was shown (#39)', () async {
    expect(await store.notificationsAsked(), isFalse);
    await store.setNotificationsAsked();
    expect(await store.notificationsAsked(), isTrue);
  });
}
