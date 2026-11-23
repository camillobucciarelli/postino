// The icon sidebar and the two panes from 900 (#60): collapse threshold, button and shortcut,
// the manual choice and when it resets, the rail's items, the registry.

import 'dart:async';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/features/posta/presentation/message_list.dart';
import 'package:postino/features/posta/presentation/posta_shortcuts.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

/// [stored]: the sidebar choice already saved by an earlier run.
Future<void> _start(WidgetTester tester, double width, {bool? stored, int many = 0, bool reconnect = false}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final a1 = await h.addAccount('a1');
  a1
    ..deliver(msg('x', subject: 'Da uno'))
    ..deliver(msg('l', subject: 'In viaggio', labelIds: const ['Label_12']));
  for (var i = 0; i < many; i++) {
    // Read: Letti under Da leggere, the scroll of a long list.
    a1.deliver(msg('n$i', subject: 'Messaggio $i', date: DateTime.utc(2026, 10, 1, 9, i), isRead: true));
  }
  (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due', isRead: true));
  if (reconnect) {
    await getIt<MailStore>().setStatus('a2', AccountStatus.daRicollegare);
  }
  if (stored != null) {
    await getIt<SettingsRepository>().setSidebarExpanded(expanded: stored);
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  await tester.pumpAndSettle();
}

double _barWidth(WidgetTester tester) => tester.getSize(find.byType(PostinoNavigationDrawer)).width;

/// Gives the focus to a drawer item (the InkWell's own focus node).
void _focusItem(WidgetTester tester, String key) =>
    Focus.of(tester.element(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(PostinoFocusRing))))
        .requestFocus();

Finder _inBar(String text) => find.descendant(of: find.byType(PostinoNavigationDrawer), matching: find.text(text));

const _close = 'Chiudi la barra laterale';
const _open = 'Apri la barra laterale';

Future<void> _ctrlB(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('collapse threshold', () {
    for (final (w, collapsed) in [(900.0, true), (1439.0, true), (1440.0, false), (1600.0, false)]) {
      testWidgets('at ${w.toInt()} the bar is ${collapsed ? 'icons only' : 'extended'}', (tester) async {
        await _start(tester, w);
        expect(_barWidth(tester), collapsed ? PostinoSize.sidebarCollapsedWidth : PostinoSize.sidebarWidth);
        expect(_inBar('Posta unificata'), collapsed ? findsNothing : findsOneWidget);
      });
    }
  });

  group('button and shortcut', () {
    testWidgets('the button closes and opens the bar, and says what it will do', (tester) async {
      await _start(tester, 1600);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      await tester.tap(find.byTooltip(_close));
      await tester.pumpAndSettle();
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
      expect(find.byTooltip(_close), findsNothing);
      await tester.tap(find.byTooltip(_open));
      await tester.pumpAndSettle();
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      expect(find.byTooltip(_close), findsOneWidget);
    });

    testWidgets('the shortcut toggles both ways with the focus in the list, in the Conversazione and in the bar', (
      tester,
    ) async {
      await _start(tester, 1600);
      await tester.tap(find.byKey(const ValueKey('row-a1-x')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationView), findsOneWidget);

      // List.
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MessageList>(), isNotNull);
      await _ctrlB(tester);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
      await _ctrlB(tester);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);

      // Conversazione.
      Focus.of(
        tester.element(
          find.descendant(of: find.byType(ConversationView), matching: find.byType(PostinoFocusRing)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await _ctrlB(tester);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);

      // Bar.
      _focusItem(tester, 'account-a1');
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoNavigationDrawer>(),
        isNotNull,
      );
      await _ctrlB(tester);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
    });

    testWidgets('on macOS it is Cmd+B, and Ctrl+B does nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _start(tester, 1600);
        await tester.tap(find.byKey(const ValueKey('row-a1-x')));
        await tester.pumpAndSettle();
        await _ctrlB(tester);
        expect(_barWidth(tester), PostinoSize.sidebarWidth);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a bare B does nothing, and Ctrl+B does not fire in a text field', (tester) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      var toggled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Actions(
              actions: {ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(onInvoke: (_) => ++toggled)},
              child: PostaShortcuts(
                cursor: ListCursor(),
                child: TextField(focusNode: field),
              ),
            ),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      await _ctrlB(tester);
      expect(toggled, 0);
    });
  });

  group('the manual choice', () {
    testWidgets('a saved choice holds until the window crosses 1440', (tester) async {
      await _start(tester, 950, stored: true);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      await _resize(tester, 900);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      await _resize(tester, 800); // modal below 840: no docked bar to measure
      await _resize(tester, 1439);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
    });

    testWidgets('a saved icons choice holds above 1440 too', (tester) async {
      await _start(tester, 1600, stored: false);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
      await _resize(tester, 1800);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
    });

    testWidgets('crossing 1440 either way clears it, in the state too', (tester) async {
      await _start(tester, 950, stored: true);
      await _resize(tester, 1600);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      expect(await getIt<SettingsRepository>().sidebarExpanded(), isNull);

      await tester.tap(find.byTooltip(_close));
      await tester.pumpAndSettle();
      expect(await getIt<SettingsRepository>().sidebarExpanded(), isFalse);
      await _resize(tester, 1439);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
      expect(await getIt<SettingsRepository>().sidebarExpanded(), isNull);

      await tester.tap(find.byTooltip(_open));
      await tester.pumpAndSettle();
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      await _resize(tester, 1600);
      expect(_barWidth(tester), PostinoSize.sidebarWidth);
      await _resize(tester, 1439);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
    });

    testWidgets('a restart applies the saved choice at the same width', (tester) async {
      await _start(tester, 1600);
      await tester.tap(find.byTooltip(_close));
      await tester.pumpAndSettle();
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
      unawaited(Routefly.navigate(routePaths.posta.path));
      await tester.pumpAndSettle();
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
    });
  });

  group('the rail', () {
    testWidgets('shows the AccountMark of every Account and the icons, unread as a dot', (tester) async {
      await _start(tester, 950);
      expect(
        find.descendant(of: find.byType(PostinoNavigationDrawer), matching: find.byType(PostinoAccountMark)),
        findsNWidgets(2),
      );
      expect(icon(PostinoIcons.inboxAll), findsOneWidget);
      // a1 has unread mail, a2 does not; the unified inbox has some.
      Finder dot(String key) =>
          find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(const ValueKey('unread-dot')));
      expect(dot('inbox-a1'), findsOneWidget);
      expect(dot('inbox-a2'), findsNothing);
      expect(dot('drawer-posta-unificata'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(PostinoNavigationDrawer), matching: find.textContaining(RegExp(r'\d'))),
        findsNothing,
      );
    });

    testWidgets('tooltip and semantics name every icon, with unread and selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _start(tester, 950);
      expect(find.byTooltip('Posta unificata'), findsOneWidget);
      expect(find.byTooltip('a1@example.com'), findsOneWidget);
      expect(find.byTooltip('a2@example.com'), findsOneWidget);
      final a1Node = tester.getSemantics(find.byKey(const ValueKey('account-a1')));
      expect(a1Node.label, 'Account a1@example.com');
      expect(a1Node.flagsCollection.isButton, isTrue);
      expect(a1Node.flagsCollection.isSelected.name, 'isFalse');
      expect(tester.getSemantics(find.byKey(const ValueKey('account-a2'))).label, 'Account a2@example.com');
      final inbox1 = tester.getSemantics(find.byKey(const ValueKey('inbox-a1')));
      expect(inbox1.label, 'Posta in arrivo, Non letto');
      expect(inbox1.flagsCollection.isButton, isTrue);
      expect(inbox1.flagsCollection.isSelected.name, 'isFalse');
      expect(tester.getSemantics(find.byKey(const ValueKey('inbox-a2'))).label, 'Posta in arrivo');
      await tester.tap(find.byKey(const ValueKey('inbox-a1')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byKey(const ValueKey('inbox-a1'))).flagsCollection.isSelected.name, 'isTrue');
      handle.dispose();
    });

    testWidgets('an Account Da ricollegare shows a warning badge, apart from the unread dot', (tester) async {
      final handle = tester.ensureSemantics();
      await _start(tester, 950, reconnect: true);
      Finder inItem(String item, String key) =>
          find.descendant(of: find.byKey(ValueKey(item)), matching: find.byKey(ValueKey(key)));
      expect(inItem('account-a2', 'reconnect-badge'), findsOneWidget);
      expect(inItem('account-a1', 'reconnect-badge'), findsNothing);
      expect(icon(PostinoIcons.alert), findsOneWidget);
      expect(find.byTooltip('a2@example.com'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('account-a2'))).label,
        'Account a2@example.com, Da ricollegare',
      );
      // a1 has unread mail and a2 is Da ricollegare: opposite corners.
      final dot = tester.getRect(inItem('inbox-a1', 'unread-dot'));
      final badge = tester.getRect(inItem('account-a2', 'reconnect-badge'));
      final item1 = tester.getRect(find.byKey(const ValueKey('inbox-a1')));
      final item2 = tester.getRect(find.byKey(const ValueKey('account-a2')));
      expect(dot.center.dy - item1.top, lessThan(item1.height / 2));
      expect(badge.center.dy - item2.top, greaterThan(item2.height / 2));
      handle.dispose();
    });

    testWidgets('the focus survives switching between extended and icons', (tester) async {
      await _start(tester, 1600);
      _focusItem(tester, 'account-a2');
      await tester.pump();
      final node = FocusManager.instance.primaryFocus;
      for (final width in [PostinoSize.sidebarCollapsedWidth, PostinoSize.sidebarWidth]) {
        await _ctrlB(tester);
        expect(_barWidth(tester), width);
        expect(FocusManager.instance.primaryFocus, same(node));
        expect(node!.context, isNotNull);
      }
    });

    testWidgets('at 200% text the labels and tooltips are not cut', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _start(tester, 950);
      expect(tester.takeException(), isNull);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
      expect(find.byTooltip('Posta unificata'), findsOneWidget);
      await _resize(tester, 1600);
      expect(tester.takeException(), isNull);
      expect(_inBar('Posta unificata'), findsOneWidget);
    });
  });

  group('the extended bar', () {
    testWidgets('shows the unread dot next to the name and reads it out', (tester) async {
      final handle = tester.ensureSemantics();
      await _start(tester, 1600);
      Finder dot(String key) =>
          find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(const ValueKey('unread-dot')));
      expect(dot('inbox-a1'), findsOneWidget);
      expect(dot('inbox-a2'), findsNothing);
      expect(dot('drawer-posta-unificata'), findsOneWidget);
      expect(tester.getSize(dot('inbox-a1')), const Size(8, 8));
      expect(tester.getSemantics(find.byKey(const ValueKey('inbox-a1'))).label, contains('Non letto'));
      handle.dispose();
    });

    testWidgets('a Conversazione with an unread message elsewhere makes its folders unread', (tester) async {
      tester.view
        ..physicalSize = const Size(1600, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create();
      // Read message in the inbox and in Label_12, unread one of the same thread without them.
      (await h.addAccount('a1'))
        ..deliver(msg('r', conversationId: 'c', isRead: true, labelIds: const [inboxLabelId, 'Label_12']))
        ..deliver(msg('u', conversationId: 'c', labelIds: const ['SENT']));
      LocaleSettings.setLocaleSync(AppLocale.it);
      await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
      unawaited(Routefly.navigate(routePaths.posta.path));
      await tester.pumpAndSettle();
      Finder dot(String key) =>
          find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(const ValueKey('unread-dot')));
      expect(dot('inbox-a1'), findsOneWidget);
      expect(dot('drawer-posta-unificata'), findsOneWidget);
      final unread = await tester.runAsync(() => getIt<MailStore>().watchUnreadFolders().first);
      expect(unread, contains(('a1', 'Label_12')));
      expect(unread, contains(('a1', inboxLabelId)));
    });

    testWidgets('at 200% text the dot does not cut the name', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _start(tester, 1600);
      expect(tester.takeException(), isNull);
      expect(_inBar('a1@example.com'), findsOneWidget);
    });
  });

  group('two panes from 900', () {
    for (final w in [900.0, 1439.0]) {
      testWidgets('at ${w.toInt()}: list and detail together, with the empty state and with a Conversazione', (
        tester,
      ) async {
        await _start(tester, w);
        expect(find.text('Seleziona una Conversazione'), findsOneWidget);
        expect(find.byKey(const ValueKey('row-a1-x')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('row-a1-x')));
        await tester.pumpAndSettle();
        expect(find.byType(ConversationView), findsOneWidget);
        expect(find.byKey(const ValueKey('row-a1-x')), findsOneWidget);
        expect(icon(PostinoIcons.arrowLeft), findsNothing);
      });
    }

    for (final w in [899.0, 600.0]) {
      testWidgets('at ${w.toInt()}: one pane', (tester) async {
        await _start(tester, w);
        expect(find.text('Seleziona una Conversazione'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('row-a1-x')));
        await tester.pumpAndSettle();
        expect(find.byType(ConversationView), findsOneWidget);
        expect(find.byKey(const ValueKey('row-a1-x')), findsNothing);
        expect(icon(PostinoIcons.arrowLeft), findsOneWidget);
      });
    }

    testWidgets('at 899 the bar is the docked rail, never an extended one beside one pane', (tester) async {
      await _start(tester, 899);
      expect(_barWidth(tester), PostinoSize.sidebarCollapsedWidth);
    });

    testWidgets('1600 to 900 keeps the open Conversazione and the list scroll', (tester) async {
      await _start(tester, 1600, many: 30);
      State list() => tester.state(find.byType(MessageList));
      final l = list();
      await tester.drag(find.byType(MessageList), const Offset(0, -600));
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .state<ScrollableState>(find.descendant(of: find.byType(MessageList), matching: find.byType(Scrollable)))
          .position;
      final scrolled = position().pixels;
      expect(scrolled, greaterThan(0));
      await tester.tapAt(const Offset(450, 400)); // a row of the scrolled list
      await tester.pumpAndSettle();
      final open = tester.state(find.byType(ConversationView));
      await _resize(tester, 900);
      expect(tester.state(find.byType(ConversationView)), same(open));
      expect(list(), same(l));
      expect(position().pixels, scrolled);
    });
  });

  test('the registry has no two actions on the same key and modifiers', () {
    final pairs = postaShortcuts.map((s) => s.chord).toList();
    expect(pairs.toSet().length, pairs.length);
    expect(
      postaShortcuts.where((s) => s.action == PostaAction.toggleSidebar).single,
      isA<PostaShortcut>()
          .having((s) => s.key, 'key', LogicalKeyboardKey.keyB)
          .having((s) => s.command, 'command', isTrue),
    );
  });
}
