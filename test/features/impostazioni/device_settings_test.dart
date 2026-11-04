// Impostazioni del dispositivo (#38): the avvio al login switch, with a fake OS, reached from the drawer on desktop.

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

bool _switchOn(WidgetTester tester) =>
    tester.widget<Switch>(find.descendant(of: _row, matching: find.byType(Switch))).value;

/// The app at desktop width, Italian, with the drawer docked; [firstRun] applies the default as main() does.
Future<Harness> _start(WidgetTester tester, {bool supported = true, bool firstRun = true}) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  h.launchAtLogin.supported = supported;
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

  testWidgets('Esc goes back to the Posta', (tester) async {
    await _start(tester);
    await _openSettings(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni del dispositivo'), findsNothing);
    expect(find.text('Posta unificata'), findsWidgets);
  });

  testWidgets('no Impostazioni in the drawer where there is no avvio al login (mobile)', (tester) async {
    final h = await _start(tester, supported: false);
    expect(find.byKey(const ValueKey('drawer-impostazioni')), findsNothing);
    expect(h.launchAtLogin.changes, isEmpty);
  });
}
