// «Sincronizza su…» (#124): the entry, the chooser, the incremental consent to Drive, from mouse and keyboard.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

final _entry = find.byKey(const ValueKey('settings-sync-account'));

Future<Harness> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  await h.addAccount('a1');
  await h.addAccount('a2');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _choose(WidgetTester tester, String key) async {
  await tester.tap(_entry);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it shows Nessuno, and says where the Impostazioni go', (tester) async {
    await _start(tester);
    expect(find.text('Sincronizza su…'), findsOneWidget);
    expect(find.descendant(of: _entry, matching: find.text('Nessuno')), findsOneWidget);
    expect(find.textContaining('file nascosto nel Google Drive'), findsOneWidget);
  });

  testWidgets('the chooser lists Nessuno and each Account; choosing one asks Drive and remembers it', (tester) async {
    final h = await _start(tester);
    h.consent.address = 'a2@example.com';
    await tester.tap(_entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-a1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sync-a2')));
    await tester.pumpAndSettle();

    expect(h.consent.lastDrive, isTrue);
    expect(h.consent.lastLoginHint, 'a2@example.com');
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), 'a2');
    expect(find.descendant(of: _entry, matching: find.text('a2@example.com')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-error')), findsNothing);
  });

  testWidgets('while Google answers it shows the progress', (tester) async {
    final h = await _start(tester);
    final gate = Completer<void>();
    h.consent.gate = gate.future;
    h.consent.address = 'a1@example.com';
    await tester.tap(_entry);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sync-a1')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('sync-busy')), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-busy')), findsNothing);
  });

  testWidgets('a denial leaves Nessuno and says so', (tester) async {
    final h = await _start(tester);
    h.consent.failure = const DriveScopeFailure();
    await _choose(tester, 'sync-a1');
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
    expect(find.descendant(of: _entry, matching: find.text('Nessuno')), findsOneWidget);
    expect(find.textContaining('Google non ha concesso'), findsOneWidget);
  });

  testWidgets('closing the Google page is not an error', (tester) async {
    final h = await _start(tester);
    h.consent.failure = const CancelledFailure();
    await _choose(tester, 'sync-a1');
    expect(find.byKey(const ValueKey('sync-error')), findsNothing);
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
  });

  testWidgets('another Google identity is refused and names the right one', (tester) async {
    final h = await _start(tester);
    h.consent.address = 'someone@else.com';
    await _choose(tester, 'sync-a1');
    expect(find.textContaining('Scegli a1@example.com'), findsOneWidget);
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
  });

  testWidgets('Nessuno turns the sync off without asking Google', (tester) async {
    final h = await _start(tester);
    await getIt<SettingsRepository>().setSettingsSyncAccount('a1');
    await tester.pumpAndSettle();
    expect(find.descendant(of: _entry, matching: find.text('a1@example.com')), findsOneWidget);
    await _choose(tester, 'sync-none');
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
    expect(h.consent.lastDrive, isNull);
    expect(find.descendant(of: _entry, matching: find.text('Nessuno')), findsOneWidget);
  });

  testWidgets('from the keyboard: Enter opens, the ticked row has the focus, Enter picks, Esc closes', (tester) async {
    final h = await _start(tester);
    h.consent.address = 'a1@example.com';
    // Focus order of the screen: the back arrow, then the entry.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-none')), findsOneWidget);

    // Esc closes it, the focus goes back to the entry.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-none')), findsNothing);
    expect(find.text('Sincronizza su…'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // Nessuno is ticked, so it has the focus; Tab moves to the first Account.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), 'a1');
  });

  testWidgets('the screen reader hears a button with the entry and its current choice', (tester) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    expect(
      tester.getSemantics(_entry),
      matchesSemantics(
        label: 'Sincronizza su…\nNessuno',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(_entry);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Sincronizza le Impostazioni su'), findsWidgets);
    expect(find.bySemanticsLabel('Nessuno'), findsWidgets);
    // One choice out of many: read as a radio group, the current one checked.
    expect(
      tester.getSemantics(find.byKey(const ValueKey('sync-none'))),
      isSemantics(label: 'Nessuno', isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('sync-a1'))),
      isSemantics(isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: false),
    );
    semantics.dispose();
  });
}
