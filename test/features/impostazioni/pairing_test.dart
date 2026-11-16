// The Abbinamento in «Sincronizza su…» (ADR 0019, #321): the request to pair a device, the code typed or pasted,
// «Abbina un altro dispositivo» with the QR and the code, «Rigenera la chiave»; from mouse, keyboard and screen reader.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/sync_key.dart';
import 'package:postino/core/data/sync/sync_key_store.dart';
import 'package:postino/core/domain/settings_backend.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/impostazioni/presentation/pairing_code_panel.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_settings_backend.dart';
import '../../support/harness.dart';

final _banner = find.byKey(const ValueKey('settings-sync-pair'));
final _pairOther = find.byKey(const ValueKey('settings-sync-pair-other'));
final _regenerate = find.byKey(const ValueKey('settings-sync-regenerate'));
final _done = find.byKey(const ValueKey('settings-sync-done'));
final _entry = find.byKey(const ValueKey('pairing-entry'));
final _code = find.byKey(const ValueKey('pairing-code'));

/// The file on Drive of a1, sealed with the shared key: another device synced there.
late FakeSettingsBackend _file;

/// The Impostazioni, a1 chosen as the Account di sincronizzazione; this device's key is [key], none by default; with
/// [file] false there is no file on Drive yet.
Future<Harness> _start(WidgetTester tester, {SyncKey? key, bool file = true}) async {
  tester.view
    ..physicalSize = const Size(1200, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  if (key != null) keysWith(key, h.deviceKeychain);
  await h.addAccount('a1');
  _file = FakeSettingsBackend();
  if (file) {
    _file.file = sealedWith({
      'schemaVersion': 3,
      'entries': {
        'auto_labels/a1': {
          'value': {'L1': <String, Object?>{}},
          'updatedAt': 1,
          'deviceId': 'other',
          'deleted': false,
        },
      },
    });
  }
  getIt.registerSingleton<SettingsBackend>(_file, instanceName: 'a1');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  await getIt<SettingsRepository>().setSettingsSyncAccount('a1');
  await tester.pumpAndSettle();
  return h;
}

Future<SyncKey?> _savedKey(Harness h) => SyncKeyStore(h.deviceKeychain).read();

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.descendant(of: _entry, matching: find.byType(EditableText)), code);
  await tester.tap(find.byKey(const ValueKey('pairing-entry-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  group('a device to pair', () {
    testWidgets('without a key: the request to pair it, no «Abbina un altro dispositivo», a warning not a failure', (
      tester,
    ) async {
      await _start(tester);
      expect(find.descendant(of: _banner, matching: find.text('Questo dispositivo non è abbinato')), findsOneWidget);
      expect(find.descendant(of: _banner, matching: find.text('Inserisci il codice')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-sync-error')), findsNothing);
      expect(_pairOther, findsNothing);
      expect(_regenerate, findsOneWidget);
    });

    testWidgets('with another key: «Chiave di sincronizzazione non più valida»', (tester) async {
      await _start(tester, key: SyncKey.random());
      expect(
        find.descendant(of: _banner, matching: find.text('Chiave di sincronizzazione non più valida')),
        findsOneWidget,
      );
    });

    testWidgets('a wrong code says why and keeps the dialog; the right one pasted pairs and syncs', (tester) async {
      final h = await _start(tester);
      await tester.tap(find.descendant(of: _banner, matching: find.text('Inserisci il codice')));
      await tester.pumpAndSettle();
      expect(find.text('Abbina questo dispositivo'), findsWidgets);

      await _typeCode(tester, SyncKey.random().code);
      expect(find.textContaining('Codice non valido'), findsOneWidget);
      expect(find.textContaining('stesso Account'), findsWidgets);
      expect(await _savedKey(h), isNull);

      final code = testSyncKey.code;
      final grouped = 'P1 ${[for (var i = 2; i < code.length; i += 4) code.substring(i, i + 4)].join(' ')}';
      await _typeCode(tester, grouped);
      expect(_entry, findsNothing);
      expect((await _savedKey(h))?.id, testSyncKey.id);
      expect(_banner, findsNothing);
      expect(_done, findsOneWidget);
      expect(_pairOther, findsOneWidget);
    });

    testWidgets('the code field is named for the screen reader and reached and sent from the keyboard', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = await _start(tester);
      await tester.tap(find.descendant(of: _banner, matching: find.text('Inserisci il codice')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Codice di abbinamento')), findsWidgets);
      // The field has the focus: the code is typed and Enter sends it.
      tester.testTextInput.enterText(testSyncKey.code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect((await _savedKey(h))?.id, testSyncKey.id);
      expect(_entry, findsNothing);
      semantics.dispose();
    });

    testWidgets('Esc closes it and saves nothing', (tester) async {
      final h = await _start(tester);
      await tester.tap(find.descendant(of: _banner, matching: find.text('Inserisci il codice')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_entry, findsNothing);
      expect(await _savedKey(h), isNull);
    });
  });

  group('«Abbina un altro dispositivo»', () {
    Future<Harness> open(WidgetTester tester) async {
      final h = await _start(tester, key: testSyncKey);
      await tester.tap(_pairOther);
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('shows the QR and the code in groups of 4, selectable, the capture protection on', (tester) async {
      final h = await open(tester);
      expect(find.byType(PostinoQrCode), findsOneWidget);
      final shown = tester.widget<Text>(_code).data!;
      expect(shown.replaceAll(' ', ''), testSyncKey.code);
      expect(shown.split(' ').first, 'P1');
      expect(shown.split(' ').skip(1), everyElement(hasLength(4)));
      expect(find.ancestor(of: _code, matching: find.byType(PostinoSelectable)), findsOneWidget);
      expect(h.screenGuard.protected, isTrue);
      expect(find.text('Si chiude tra 2:00'), findsOneWidget);

      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      expect((_code.evaluate().isEmpty, h.screenGuard.protected), (true, false));
    });

    testWidgets('the screen reader hears the QR\'s name and the code character by character', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('QR del codice di abbinamento'), findsOneWidget);
      final spelled = RegExp(r'^Codice di abbinamento: P 1, ([A-Z2-7] [A-Z2-7] [A-Z2-7] [A-Z2-7](, |$)){13}');
      expect(find.bySemanticsLabel(spelled), findsOneWidget);
      expect(find.bySemanticsLabel('Il codice si chiude tra 120 secondi'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('closes by itself after 2 minutes, counting down', (tester) async {
      final h = await open(tester);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Si chiude tra 0:59'), findsOneWidget);
      await tester.pump(pairingCodeShownFor);
      await tester.pumpAndSettle();
      expect((_code.evaluate().isEmpty, h.screenGuard.protected), (true, false));
    });

    testWidgets('closes when the app goes to the background', (tester) async {
      final h = await open(tester);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      // No frame is drawn in the background: back in foreground it is gone.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_code, findsNothing);
      expect(h.screenGuard.protected, isFalse);
    });

    testWidgets('hides the code while the screen is recorded or mirrored', (tester) async {
      final h = await open(tester);
      h.screenGuard.capture(on: true);
      await tester.pump();
      await tester.pump();
      expect((_code.evaluate().isEmpty, find.byType(PostinoQrCode).evaluate().isEmpty), (true, true));
      expect(find.textContaining('nascosto mentre lo schermo'), findsOneWidget);
      h.screenGuard.capture(on: false);
      await tester.pump();
      await tester.pump();
      expect(_code, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    testWidgets('the secret waits for the platform\'s answer: a recording already running never catches it', (
      tester,
    ) async {
      final h = await _start(tester, key: testSyncKey);
      final answer = Completer<bool>();
      h.screenGuard.answer = answer.future;
      await tester.tap(_pairOther);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect((_code.evaluate().isEmpty, find.byType(PostinoQrCode).evaluate().isEmpty), (true, true));
      answer.complete(true);
      await tester.pump();
      expect(find.textContaining('nascosto mentre lo schermo'), findsOneWidget);
      expect(_code, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    testWidgets('on a desktop, losing the focus to another window does not close it; hiding it does', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(_code, findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('two taps open one screen only', (tester) async {
      final h = await _start(tester, key: testSyncKey);
      await tester.tap(_pairOther);
      await tester.tap(_pairOther, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_code, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.screenGuard.protected, isFalse);
    });

    testWidgets('«Chiudi» has the focus: Enter closes it', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_code, findsNothing);
    });

    testWidgets('a device that never synced anything has nothing to show yet', (tester) async {
      await _start(tester, file: false);
      await tester.tap(_pairOther);
      await tester.pumpAndSettle();
      expect(find.textContaining('nulla da abbinare'), findsOneWidget);
      expect((_code.evaluate().isEmpty, find.byType(PostinoQrCode).evaluate().isEmpty), (true, true));
      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
    });
  });

  group('«Rigenera la chiave»', () {
    testWidgets('asks first, saying what may be lost; then seals the file with a new key', (tester) async {
      final h = await _start(tester, key: testSyncKey);
      await tester.tap(_regenerate);
      await tester.pumpAndSettle();
      expect(find.text('Rigenerare la chiave di sincronizzazione?'), findsOneWidget);
      expect(find.textContaining('va perso'), findsOneWidget);
      // The focus on «Annulla»: Enter never confirms by accident.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect((await _savedKey(h))?.id, testSyncKey.id);

      await tester.tap(_regenerate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rigenera'));
      await tester.pumpAndSettle();
      final key = (await _savedKey(h))!;
      expect(key.id, isNot(testSyncKey.id));
      expect((jsonDecode(_file.file!) as Map<String, Object?>)['keyId'], key.id);
      expect(_file.entries(key).keys, ['auto_labels/a1']);
      expect(_done, findsOneWidget);
    });

    testWidgets('offline it says so and keeps the key', (tester) async {
      final h = await _start(tester, key: testSyncKey);
      h.connectivity.online = false;
      await tester.tap(_regenerate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rigenera'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(const ValueKey('sync-error')), matching: find.textContaining('offline')),
        findsOneWidget,
      );
      expect((await _savedKey(h))?.id, testSyncKey.id);
    });

    testWidgets('the rows are buttons for the screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await _start(tester, key: testSyncKey);
      for (final (row, label) in [
        (_pairOther, 'Abbina un altro dispositivo\nMostra il codice da inserire sul nuovo dispositivo'),
        (_regenerate, 'Rigenera la chiave\nGli altri dispositivi andranno abbinati di nuovo'),
      ]) {
        expect(
          tester.getSemantics(row),
          matchesSemantics(label: label, isButton: true, isFocusable: true, hasTapAction: true, hasFocusAction: true),
        );
      }
      semantics.dispose();
    });
  });
}
