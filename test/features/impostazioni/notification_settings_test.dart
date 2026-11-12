// Impostazioni del dispositivo › «Notifiche» and the Azioni of a notification (#211), with a fake OS: where there is
// no avvio al login (iOS, Android) too.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/new_mail_notifier.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

Finder _choice(String place, String action) => find.byKey(ValueKey('notification-action-$place-$action'));
final _allow = find.byKey(const ValueKey('notifications-allow'));

bool _selected(WidgetTester tester, String place, String action) =>
    tester.widget<PostinoChoiceRow>(_choice(place, action)).selected;

/// The Impostazioni del dispositivo open, Italian, with no avvio al login nor updater (as on a phone).
Future<Harness> _open(WidgetTester tester, {bool permissionNeeded = false}) async {
  tester.view
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  h.launchAtLogin.supported = false;
  h.notifications.needed = permissionNeeded;
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

void main() {
  testWidgets('Archivia and Segna come letto by default; a choice is saved and the next notification has it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await _open(tester);
    expect(_selected(tester, 'first', 'archive'), isTrue);
    expect(_selected(tester, 'second', 'markRead'), isTrue);

    await tester.tap(_choice('first', 'delete'));
    await tester.pumpAndSettle();
    await tester.tap(_choice('second', 'none'));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'first', 'delete'), isTrue);
    expect(_selected(tester, 'first', 'archive'), isFalse);
    expect(_selected(tester, 'second', 'none'), isTrue);
    expect(await tester.runAsync(() => getIt<SettingsRepository>().notificationActions()), (
      first: NotificationAction.delete,
      second: null,
    ));

    const account = Account(id: 'a1', address: 'ada@example.com', provider: ProviderKind.gmail, color: 0, position: 0);
    await tester.runAsync(() => getIt<NewMailNotifier>().notify(account, [msg('n')]));
    expect(h.notifications.shown.last.actions, [NotificationAction.delete]);
    semantics.dispose();
  });

  testWidgets('each choice reads with its place, and Tab then Space chooses it', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester);
    expect(tester.getSemantics(_choice('second', 'star')).label, 'Seconda Azione della notifica\nStella');

    Focus.of(tester.element(find.text('Stella').last)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_selected(tester, 'second', 'delete'), isTrue);
    semantics.dispose();
  });

  testWidgets('«Notifiche» allowed: it says so, nothing to ask', (tester) async {
    await _open(tester);
    expect(find.text('Consentite'), findsOneWidget);
    expect(_allow, findsNothing);
  });

  testWidgets('«Notifiche» not allowed: «Consenti» asks the OS, then says it is allowed', (tester) async {
    final h = await _open(tester, permissionNeeded: true);
    expect(find.text('Non consentite: la posta nuova arriva senza avviso.'), findsOneWidget);

    await tester.tap(_allow);
    await tester.pumpAndSettle();
    expect(h.notifications.requests, 1);
    expect(h.notifications.settingsOpened, 0);
    expect(find.text('Consentite'), findsOneWidget);
    expect(_allow, findsNothing);
  });

  testWidgets('the OS no longer asks: «Consenti» opens the system settings', (tester) async {
    final h = await _open(tester, permissionNeeded: true);
    h.notifications.grants = false;

    await tester.tap(_allow);
    await tester.pumpAndSettle();
    expect(h.notifications.settingsOpened, 1);
    expect(_allow, findsOneWidget);
  });
}
