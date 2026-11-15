// «Sincronizza su…» (#124): the entry, the chooser, the incremental consent to Drive, from mouse and keyboard.

import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_backend.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/core/domain/settings_sync_control.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_settings_backend.dart';
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

  for (final reduced in [false, true]) {
    testWidgets(
      'the progress opens, then fades into the error${reduced ? ', at once with reduced motion' : ''} (#283)',
      (tester) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final h = await _start(tester);
        final gate = Completer<void>();
        h.consent
          ..gate = gate.future
          ..failure = const DriveScopeFailure();
        await tester.tap(_entry);
        await tester.pumpAndSettle();
        final busy = find.byKey(const ValueKey('sync-busy'));
        final error = find.byKey(const ValueKey('sync-error'));
        await tester.tap(find.byKey(const ValueKey('sync-a1')));
        for (var i = 0; i < 10 && busy.evaluate().isEmpty; i++) {
          await tester.pump();
        }
        await tester.pump(PostinoMotion.snackbar ~/ 2);
        final reveal = find.ancestor(of: busy, matching: find.byType(PostinoSizeFade));
        final full = tester.getSize(busy).height + PostinoSpacing.s2;
        expect(tester.getSize(reveal).height, reduced ? full : inExclusiveRange(0, full));

        gate.complete();
        for (var i = 0; i < 10 && error.evaluate().isEmpty; i++) {
          await tester.pump();
        }
        await tester.pump(PostinoMotion.snackbar ~/ 2);
        expect(busy, reduced ? findsNothing : findsOneWidget, reason: 'the progress fades out under the error');
        expect(error, findsOneWidget);
        await tester.pumpAndSettle();
        expect(busy, findsNothing);
        expect(error, findsOneWidget);
      },
    );
  }

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
    // Focus order of the screen: the back arrow, the Impostazioni del dispositivo, «Rimuovi» of the two Accounts,
    // «Aggiungi Account», then the entry.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
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

  group('the last cycle of the sync (#317)', () {
    final error = find.byKey(const ValueKey('settings-sync-error'));
    final done = find.byKey(const ValueKey('settings-sync-done'));
    final retry = find.descendant(of: error, matching: find.text('Riprova'));
    late FakeSettingsBackend file;

    /// a1 chosen, its file in memory: the choice starts a cycle.
    Future<Harness> synced(WidgetTester tester, {Failure? failure}) async {
      final h = await _start(tester);
      file = FakeSettingsBackend()..readFailure = failure;
      getIt.registerSingleton<SettingsBackend>(file, instanceName: 'a1');
      await getIt<SettingsRepository>().setSettingsSyncAccount('a1');
      await tester.pumpAndSettle();
      return h;
    }

    const disabled = UnexpectedFailure('Drive: HTTP 403 accessNotConfigured');

    testWidgets('a failed cycle shows its reason, selectable, until «Riprova» goes through', (tester) async {
      await synced(tester, failure: disabled);
      expect(error, findsOneWidget);
      expect(find.descendant(of: error, matching: find.text('Impostazioni non sincronizzate')), findsOneWidget);
      final reason = find.descendant(of: error, matching: find.textContaining('accessNotConfigured'));
      expect(reason, findsOneWidget);
      expect(find.ancestor(of: reason, matching: find.byType(PostinoSelectable)), findsWidgets);
      expect(done, findsNothing);

      file.readFailure = null;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(find.descendant(of: done, matching: find.textContaining('Impostazioni sincronizzate')), findsOneWidget);
    });

    testWidgets('a missing scope says how to fix it, and picking the Account again syncs at once', (tester) async {
      final h = await synced(tester, failure: const DriveScopeFailure());
      expect(find.descendant(of: error, matching: find.textContaining('scegli di nuovo')), findsOneWidget);

      file.readFailure = null;
      h.consent.address = 'a1@example.com';
      await _choose(tester, 'sync-a1');
      expect(error, findsNothing);
      expect(done, findsOneWidget);
    });

    testWidgets('it says the time of a cycle today, the date of one before', (tester) async {
      final h = await synced(tester);
      final at = h.clock.now().toLocal();
      expect(
        find.descendant(
          of: done,
          matching: find.text('Impostazioni sincronizzate alle ${DateFormat.Hm('it').format(at)}'),
        ),
        findsOneWidget,
      );
      // Two days on, a cycle held in flight redraws it with the last success.
      final gate = file.readGate = Completer<void>();
      h.clock.advance(const Duration(days: 2));
      unawaited(getIt<SettingsSyncControl>().syncNow());
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(
          of: done,
          matching: find.text('Impostazioni sincronizzate il ${DateFormat.MMMd('it').format(at)}'),
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a refused consent does not hide the failure of the Account still chosen', (tester) async {
      final h = await synced(tester, failure: disabled);
      h.consent.failure = const DriveScopeFailure();
      await _choose(tester, 'sync-a2');
      expect(find.byKey(const ValueKey('sync-error')), findsOneWidget);
      expect(error, findsOneWidget);
    });

    testWidgets('the screen reader hears the error as it comes, and «Riprova» is a button', (tester) async {
      final semantics = tester.ensureSemantics();
      await synced(tester, failure: disabled);
      expect(
        find.descendant(
          of: error,
          matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false)),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(retry),
        isSemantics(label: 'Riprova', isButton: true, isFocusable: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('«Riprova» is reached and pressed from the keyboard', (tester) async {
      await synced(tester, failure: disabled);
      file.readFailure = null;
      bool focused() {
        final c = FocusManager.instance.primaryFocus?.context;
        return c != null &&
            find.ancestor(of: find.byElementPredicate((e) => e == c), matching: error).evaluate().isNotEmpty;
      }

      for (var i = 0; i < 30 && !focused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focused(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(done, findsOneWidget);
    });

    testWidgets('coming back to the app runs a cycle', (tester) async {
      await synced(tester);
      final before = file.reads;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(file.reads, before + 1);
    });
  });
}
