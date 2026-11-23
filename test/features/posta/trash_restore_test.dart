// Ripristina nel Cestino (#372): al posto di Archivia ed Elimina nella barra, nel menu della riga, nello swipe e nelle
// scorciatoie; riporta la Conversazione nella Posta in arrivo, con Annulla. Fuori dal Cestino nulla cambia.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/app/posta/posta_routes.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/swipe_actions.dart';
import 'package:postino/core/domain/swipe_actions_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_model_download.dart';
import '../../support/harness.dart';

late Harness h;
late FakeMailProvider gmail;

/// The Provider calls before the test's own: the setup's Elimina.
late int _actionsBefore;

/// m1 deleted in the setup, the list open on [view] (the Cestino by default).
Future<void> _start(WidgetTester tester, {Size size = const Size(1600, 900), String view = trashLabelId}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  await getIt.unregister<ModelDownload>();
  getIt.registerSingleton<ModelDownload>(FakeModelDownload());
  gmail = (await h.addAccount('a1'))
    ..deliver(msg('m1', conversationId: 't', subject: 'Cena', isRead: true))
    ..deliver(msg('m2', conversationId: 'u', subject: 'Pranzo', isRead: true));
  final engine = getIt<SyncEngine>();
  await engine.syncAll();
  await engine.act('a1', ['m1'], const Delete());
  await engine.syncAll();
  _actionsBefore = gmail.actionCalls.length;
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(labelPath('a1', view)));
  await _settle(tester);
}

/// Bounded pumps, never pumpAndSettle once a Snackbar shows: it ticks every second.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(pumpEventQueue);
  }
}

Future<void> _tap(WidgetTester tester, Finder f, {int buttons = 1}) async {
  await tester.tap(f, buttons: buttons);
  await _settle(tester);
}

/// The Annulla window ends: the held voci leave the device.
Future<void> _expire(WidgetTester tester) async {
  h.clock.advance(PostinoMotion.undoWindow);
  await tester.pump(PostinoMotion.undoWindow + const Duration(seconds: 1));
  await _settle(tester);
}

/// `#`, as Maiusc+3 types it.
Future<void> _hash(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit3, character: '#');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await _settle(tester);
}

Finder _row(String latest) => find.byKey(ValueKey('row-a1-$latest'));

Future<List<String>> _labelsOf(WidgetTester tester, String id) async =>
    (await tester.runAsync(() => getIt<InboxRepository>().watchMessage('a1', id).first))!.labelIds;

/// The Azioni that reached the Provider during the test.
List<MailAction> _sent() => [for (final (_, action, _) in gmail.actionCalls.skip(_actionsBefore)) action];

/// m1 is back in the inbox, here and on the Provider, through Ripristina.
Future<void> _restored(WidgetTester tester) async {
  await _expire(tester);
  expect(await _labelsOf(tester, 'm1'), allOf(contains(inboxLabelId), isNot(contains(trashLabelId))));
  expect(_sent(), [const Restore()]);
}

void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  _onMac('the bar of a Conversazione from the Cestino offers Ripristina with its shortcut, no Archivia nor Elimina', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('m1'));
    expect(find.byTooltip('Archivia · E'), findsNothing);
    expect(find.byTooltip('Elimina · #'), findsNothing);
    expect(find.bySemanticsLabel('Ripristina'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Ripristina · E')).shortestSide,
      greaterThanOrEqualTo(PostinoSize.touchTargetAndroid),
    );

    await _tap(tester, find.byTooltip('Ripristina · E'));
    expect(find.text('Conversazione ripristinata'), findsOneWidget);
    await _restored(tester);
  });

  _onMac('the row menu in the Cestino offers Ripristina, no Archivia nor Elimina; Annulla takes it back', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('m1'), buttons: kSecondaryButton);
    expect(find.text('Archivia'), findsNothing);
    expect(find.text('Elimina'), findsNothing);
    await _tap(tester, find.text('Ripristina'));
    expect(_row('m1'), findsNothing);

    await _tap(tester, find.widgetWithText(PostinoButton, 'Annulla'));
    await _expire(tester);
    expect(await _labelsOf(tester, 'm1'), contains(trashLabelId));
    expect(_sent(), isEmpty);
  });

  _onMac('in the Cestino `e` restores the focused row and `#` does nothing', (tester) async {
    await _start(tester);
    tester.widget<PostinoMessageTile>(_row('m1')).focusNode!.requestFocus();
    await _settle(tester);
    await _hash(tester);
    expect(_row('m1'), findsOneWidget);
    expect(find.text('Conversazione spostata nel Cestino'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await _settle(tester);
    await _restored(tester);
  });

  _onMac('in a Conversazione open from the Cestino `e` restores and `#` does nothing', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m1'));
    await _hash(tester);
    expect(find.text('Conversazione spostata nel Cestino'), findsNothing);
    await _expire(tester);
    expect(_sent(), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await _settle(tester);
    await _restored(tester);
  });

  testWidgets('in the Cestino the swipe of Archivia restores, also for the screen reader', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final semantics = tester.ensureSemantics();
    try {
      await _start(tester, size: const Size(500, 900));
      SemanticsNode node = tester.getSemantics(_row('m1'));
      final ids = node.getSemanticsData().customSemanticsActionIds ?? const [];
      int id(String label) => CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));
      expect(ids, contains(id('Ripristina')));
      expect(ids, isNot(contains(id('Archivia'))));

      node = tester.getSemantics(_row('m1'));
      node.owner!.performAction(node.id, SemanticsAction.customAction, id('Ripristina'));
      await _settle(tester);
      await _restored(tester);
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('in the Cestino dragging the row left restores it', (tester) async {
    await _start(tester, size: const Size(500, 900));
    await tester.drag(_row('m1'), const Offset(-200, 0));
    await _settle(tester);
    await _restored(tester);
  });

  testWidgets('in the Cestino the swipe the Impostazioni bind to Elimina restores too', (tester) async {
    await _start(tester, size: const Size(500, 900));
    await getIt<SwipeActionsRepository>().set(SwipeDirection.left, SwipeAction.delete);
    await _settle(tester);
    await tester.drag(_row('m1'), const Offset(-200, 0));
    await _settle(tester);
    await _restored(tester);
  });

  _onMac('outside the Cestino nothing changes: Archivia and Elimina, no Ripristina', (tester) async {
    await _start(tester, view: inboxLabelId);
    await _tap(tester, _row('m2'));
    expect(find.byTooltip('Archivia · E'), findsOneWidget);
    expect(find.byTooltip('Elimina · #'), findsOneWidget);
    expect(find.byTooltip('Ripristina · E'), findsNothing);

    await _tap(tester, _row('m2'), buttons: kSecondaryButton);
    expect(find.text('Ripristina'), findsNothing);
  });
}
