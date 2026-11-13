// The sync status under the bar of the list and «Aggiorna» (#251): desktop (from 840) and phone (390).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/desktop/channel_app_menu.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _row = ValueKey('sync-status');
const _refresh = 'Aggiorna la posta';
const _poll = Duration(seconds: 60);

late Harness _h;
late FakeMailProvider _gmail;

Future<void> _start(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _h = await Harness.create();
  _gmail = (await _h.addAccount('a1'))..deliver(msg('a'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

PostinoSyncStatus _status(WidgetTester tester) => tester.widget<PostinoSyncStatus>(find.byKey(_row));

/// A poll's sync, as the app runs it on its own.
Future<void> _autoSync(WidgetTester tester) async {
  _h.clock.advance(_poll);
  await tester.pumpAndSettle();
}

Iterable<String> _announced(WidgetTester tester) => tester.takeAnnouncements().map((a) => a.message);

void main() {
  group('desktop', () {
    testWidgets('the row says the last update, with the green check; «Aggiorna» sits before «Cerca»', (tester) async {
      await _start(tester, const Size(1280, 800));
      expect(_status(tester).state, PostinoSyncState.ok);
      expect(find.text('Aggiornato adesso'), findsOneWidget);
      expect(
        tester.widget<PostinoIcon>(find.descendant(of: find.byKey(_row), matching: find.byType(PostinoIcon))).color,
        PostinoTheme.light().extension<PostinoColors>()!.syncOk,
      );
      final refresh = find.byKey(const ValueKey('refresh'));
      expect(find.byTooltip('$_refresh · Ctrl+R'), findsOneWidget);
      // Same bar, before «Cerca»: Tab reaches it first.
      expect(tester.getCenter(refresh).dx, lessThan(tester.getCenter(find.byTooltip('Cerca')).dx));
      expect(tester.getCenter(refresh).dy, tester.getCenter(find.byTooltip('Cerca')).dy);
      // Under the bar, above the list.
      expect(tester.getTopLeft(find.byKey(_row)).dy, greaterThanOrEqualTo(tester.getBottomLeft(refresh).dy));
      expect(
        tester.getTopLeft(find.byKey(_row)).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('row-a1-a'))).dy),
      );
    });

    testWidgets('«Aggiorna» syncs once, shows it running, and announces only its end', (tester) async {
      final semantics = tester.ensureSemantics();
      await _start(tester, const Size(1280, 800));
      expect(
        tester.getSemantics(find.bySemanticsLabel(_refresh)),
        isSemantics(label: _refresh, isButton: true, hasTapAction: true, isFocusable: true),
      );
      tester.takeAnnouncements();
      final before = _gmail.syncCalls;
      _gmail.hold = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('refresh')));
      await tester.pump();
      await tester.pump();
      expect(_status(tester).state, PostinoSyncState.syncing);
      expect(find.text('Sincronizzazione in corso…'), findsOneWidget);
      // A second ask while it runs joins it.
      await tester.tap(find.byKey(const ValueKey('refresh')));
      await tester.pump();
      expect(_announced(tester), isEmpty, reason: 'nothing at the start');

      _gmail.hold!.complete();
      await tester.pumpAndSettle();
      expect(_gmail.syncCalls, before + 1);
      expect(_announced(tester), ['Posta aggiornata']);
      expect(_status(tester).state, PostinoSyncState.ok);
      semantics.dispose();
    });

    testWidgets('Ctrl+R refreshes; the syncs the app runs on its own are never announced', (tester) async {
      final semantics = tester.ensureSemantics();
      await _start(tester, const Size(1280, 800));
      await _autoSync(tester);
      expect(_announced(tester), isNot(contains('Posta aggiornata')));
      await tester.tap(find.byKey(const ValueKey('row-a1-a')));
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      final before = _gmail.syncCalls;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(_gmail.syncCalls, before + 1);
      expect(_announced(tester), ['Posta aggiornata']);
      semantics.dispose();
    });

    testWidgets('on macOS it is Cmd+R, the tooltip says ⌘R', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _start(tester, const Size(1280, 800));
        expect(find.byTooltip('$_refresh · ⌘R'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('row-a1-a')));
        await tester.pumpAndSettle();
        final before = _gmail.syncCalls;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(_gmail.syncCalls, before + 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('«Aggiorna» of the macOS menu refreshes like the bar', (tester) async {
      final semantics = tester.ensureSemantics();
      await _start(tester, const Size(1280, 800));
      tester.takeAnnouncements();
      final before = _gmail.syncCalls;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        ChannelAppMenu.channel.name,
        ChannelAppMenu.channel.codec.encodeMethodCall(const MethodCall('refresh')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(_gmail.syncCalls, before + 1);
      expect(_announced(tester), ['Posta aggiornata']);
      semantics.dispose();
    });
  });

  group('phone', () {
    testWidgets('the same row under the bar, no «Aggiorna»: the pull-to-refresh stays', (tester) async {
      await _start(tester, const Size(390, 844));
      expect(find.text('Aggiornato adesso'), findsOneWidget);
      expect(find.byKey(const ValueKey('refresh')), findsNothing);
      expect(find.byTooltip(RegExp(_refresh)), findsNothing);
    });

    testWidgets('offline: «Offline · aggiornato alle», not an error', (tester) async {
      await _start(tester, const Size(390, 844));
      _h.connectivity.online = false;
      _gmail.goOffline();
      for (var i = 0; i < 3; i++) {
        await _autoSync(tester);
      }
      expect(_status(tester).state, PostinoSyncState.offline);
      expect(find.textContaining('Offline · aggiornato alle '), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);

      _h.connectivity.online = true;
      _gmail.goOnline();
      await _autoSync(tester);
      expect(find.text('Aggiornato adesso'), findsOneWidget);
    });

    testWidgets('a sync that keeps failing with the device online is an error with «Riprova», until one works', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _start(tester, const Size(390, 844));
      _gmail.goOffline();
      await _autoSync(tester);
      expect(_status(tester).state, PostinoSyncState.ok, reason: 'one OfflineFailure online is a blip');
      await _autoSync(tester);
      await _autoSync(tester);
      expect(_status(tester).state, PostinoSyncState.error);
      expect(find.text('Aggiornamento non riuscito'), findsOneWidget);
      final retry = find.widgetWithText(PostinoButton, 'Riprova');
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(retry), isSemantics(label: 'Riprova', isButton: true, hasTapAction: true));
      expect(_announced(tester), isNot(contains('Aggiornamento non riuscito')), reason: 'automatic syncs');

      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(_announced(tester), ['Aggiornamento non riuscito']);
      expect(_status(tester).state, PostinoSyncState.error, reason: 'it stays until an update works');

      _gmail.goOnline();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(_announced(tester), ['Posta aggiornata']);
      expect(find.text('Aggiornato adesso'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('an Account Da ricollegare shows it', (tester) async {
      await _start(tester, const Size(390, 844));
      _gmail.breakAuth();
      await _autoSync(tester);
      expect(_status(tester).state, PostinoSyncState.reconnect);
    });

    testWidgets('at 200% the row wraps, nothing is cut', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _start(tester, const Size(390, 844));
      _gmail.goOffline();
      for (var i = 0; i < 3; i++) {
        await _autoSync(tester);
      }
      expect(tester.takeException(), isNull);
      final label = find.text('Aggiornamento non riuscito');
      expect(tester.getSize(label).height, greaterThan(32), reason: 'two lines');
      expect(find.text('Riprova'), findsOneWidget);
    });
  });
}
