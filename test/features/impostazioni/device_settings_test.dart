// Impostazioni del dispositivo (#38): the avvio al login switch, with a fake OS, reached from the drawer on desktop;
// «Cerca aggiornamenti» (#122) with a fake updater.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/launch_at_login_use_case.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

final _row = find.byKey(const ValueKey('launch-at-login'));
final _updates = find.byKey(const ValueKey('check-for-updates'));

bool _switchOn(WidgetTester tester) =>
    tester.widget<Switch>(find.descendant(of: _row, matching: find.byType(Switch))).value;

/// The app at desktop width, Italian, with the drawer docked; [firstRun] applies the default as main() does.
Future<Harness> _start(WidgetTester tester, {bool supported = true, bool updates = false, bool firstRun = true}) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  h.launchAtLogin.supported = supported;
  h.updater.supported = updates;
  await h.addAccount('a1');
  if (firstRun) await getIt<LaunchAtLoginUseCase>().applyDefault();
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-device')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('at the first run it is on; the switch turns it off, and the choice is remembered', (tester) async {
    final h = await _start(tester);
    await _openSettings(tester);
    expect(find.text('Impostazioni del dispositivo'), findsOneWidget);
    expect(_switchOn(tester), isTrue);

    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isFalse);
    expect(h.launchAtLogin.enabled, isFalse);
    expect(await getIt<SettingsRepository>().launchAtLogin(), isFalse);

    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isTrue);
    expect(h.launchAtLogin.changes, [true, false, true]);
  });

  testWidgets('the switch shows what the OS says, not the remembered choice', (tester) async {
    final h = await _start(tester);
    h.launchAtLogin.enabled = false;
    await _openSettings(tester);
    expect(_switchOn(tester), isFalse);
  });

  testWidgets('a refusal of the OS leaves the switch as the OS has it and says so', (tester) async {
    final h = await _start(tester);
    h.launchAtLogin.failure = Exception('refused');
    await _openSettings(tester);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isTrue);
    expect(find.textContaining('Il sistema non ha accettato la modifica'), findsOneWidget);
  });

  testWidgets('one switch for the screen reader, named by its row, toggled from the keyboard', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await _start(tester);
    await _openSettings(tester);
    expect(
      tester.getSemantics(_row),
      matchesSemantics(
        label: 'Avvio al login\nPostino si apre quando accedi al computer e resta nella tray, così la posta continua ad arrivare.',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    // Focus order: the back arrow, then the row; the switch is not a stop of its own.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoSwitchRow>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(h.launchAtLogin.enabled, isFalse);
    semantics.dispose();
  });

  testWidgets('Esc goes back to the Impostazioni, then to the Posta', (tester) async {
    await _start(tester);
    await _openSettings(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni del dispositivo'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-device')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-device')), findsNothing);
    expect(find.text('Posta unificata'), findsWidgets);
  });

  testWidgets('opened by a link with nothing under it, back goes to the Posta unificata', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(routePaths.impostazioni.dispositivo));
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni del dispositivo'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni del dispositivo'), findsNothing);
    expect(find.text('Posta unificata'), findsWidgets);
  });

  testWidgets('when the OS cannot say, the switch reads off and still works', (tester) async {
    final h = await _start(tester);
    h.launchAtLogin.readFailure = Exception('unreadable');
    await _openSettings(tester);
    expect(_switchOn(tester), isFalse);
    h.launchAtLogin.readFailure = null;
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(h.launchAtLogin.changes.last, isTrue);
    expect(_switchOn(tester), isTrue);
  });

  testWidgets('no device settings where there is no avvio al login (mobile)', (tester) async {
    final h = await _start(tester, supported: false);
    await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-device')), findsNothing);
    expect(h.launchAtLogin.changes, isEmpty);
  });

  testWidgets('«Cerca aggiornamenti» asks the updater, which answers with its own window', (tester) async {
    final h = await _start(tester, updates: true);
    await _openSettings(tester);
    expect(find.text('Cerca aggiornamenti'), findsOneWidget);
    await tester.tap(_updates);
    await tester.pumpAndSettle();
    expect(h.updater.checks, 1);
  });

  testWidgets('«Cerca aggiornamenti» is one button for the screen reader, pressed from the keyboard', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await _start(tester, updates: true);
    await _openSettings(tester);
    expect(
      tester.getSemantics(_updates),
      matchesSemantics(
        label: 'Cerca aggiornamenti\nCerca subito una nuova versione di Postino.',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    // Focus order: the back arrow, the avvio al login, then «Cerca aggiornamenti».
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.updater.checks, 1);
    semantics.dispose();
  });

  testWidgets('where only the updater exists, the device settings still show, with it alone', (tester) async {
    await _start(tester, supported: false, updates: true);
    await _openSettings(tester);
    expect(_updates, findsOneWidget);
    expect(_row, findsNothing);
  });

  testWidgets('no «Cerca aggiornamenti» where Postino does not update itself', (tester) async {
    await _start(tester);
    await _openSettings(tester);
    expect(_row, findsOneWidget);
    expect(_updates, findsNothing);
  });
}
