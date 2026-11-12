import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

/// The Impostazioni del dispositivo open, Italian, with no avvio al login nor updater (as on a phone); [permissionNeeded]
/// as the fake OS says; [android] with the Notifiche immediate (#214).
Future<Harness> openPhoneDeviceSettings(
  WidgetTester tester, {
  bool permissionNeeded = false,
  bool android = false,
}) async {
  tester.view
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  h.launchAtLogin.supported = false;
  h.notifications.needed = permissionNeeded;
  h.immediate.supported = android;
  // «Non ora» long ago: the explanation at the first Account does not come back (#39).
  await getIt<SettingsRepository>().setNotificationsAsked();
  await h.addAccount('a1');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-device')));
  await tester.pumpAndSettle();
  return h;
}
