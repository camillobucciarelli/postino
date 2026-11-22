// An Azione or a change of Etichetta taken from a view reaches only the messages that view shows: from the inbox, the
// row's menu, its swipe and the picker of the Etichette leave the message in the Cestino alone (Gmail semantics:
// Archivia would take it out of the Cestino). The view comes from the list to its rows and to the Conversazione.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/app/posta/posta_routes.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/features/posta/presentation/message_list.dart';
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
late int _labelsBefore;

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

/// Conversazione t: m1 in the inbox, m2 (newest, Viaggi) in the Cestino; the inbox row is m1's.
Future<void> _start(
  WidgetTester tester, {
  Size size = const Size(1600, 900),
  List<String> m1Labels = const ['INBOX'],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  await getIt.unregister<ModelDownload>();
  getIt.registerSingleton<ModelDownload>(FakeModelDownload());
  gmail = await h.addAccount('a1');
  gmail.labels.add(const Label(id: 'Label_13', name: 'Fatture', kind: LabelKind.etichetta));
  gmail
    ..deliver(msg('m1', conversationId: 't', subject: 'Cena', date: _day(1), isRead: true, labelIds: m1Labels))
    ..deliver(
      msg('m2', conversationId: 't', subject: 'Re: Cena', date: _day(2), isRead: true, labelIds: ['INBOX', 'Label_12']),
    );
  final engine = getIt<SyncEngine>();
  await engine.syncAll();
  await engine.act('a1', ['m2'], const Delete());
  await engine.syncAll();
  _actionsBefore = gmail.actionCalls.length;
  _labelsBefore = gmail.labelCalls.length;
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

/// Bounded pumps, never pumpAndSettle once a Snackbar shows: it ticks every second.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(pumpEventQueue);
  }
}

Future<void> _tap(WidgetTester tester, Finder f, {int buttons = kPrimaryButton}) async {
  await tester.tap(f, buttons: buttons);
  await _settle(tester);
}

/// The Annulla window ends: the held voci leave the device.
Future<void> _expire(WidgetTester tester) async {
  h.clock.advance(PostinoMotion.undoWindow);
  await tester.pump(PostinoMotion.undoWindow + const Duration(seconds: 1));
  await _settle(tester);
}

Finder _row(String latest) => find.byKey(ValueKey('row-a1-$latest'));
Finder _tile(String name) => find.widgetWithText(PostinoCheckboxTile, name);
bool _ticked(WidgetTester tester, String name) => tester.widget<PostinoCheckboxTile>(_tile(name)).value;

/// Read on the real clock: the database does not answer under the test's fake one.
Future<List<String>> _labelsOf(WidgetTester tester, String id) async =>
    (await tester.runAsync(() => getIt<InboxRepository>().watchMessage('a1', id).first))!.labelIds;

/// The Azioni and label calls that reached the Provider for [id] during the test.
List<Object> _sentFor(String id) => [
  for (final (m, action, _) in gmail.actionCalls.skip(_actionsBefore))
    if (m == id) action,
  for (final (m, label, on) in gmail.labelCalls.skip(_labelsBefore))
    if (m == id) (label, on),
];

void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  _onMac('Archivia from the menu of an inbox row leaves the message in the Cestino there', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m1'), buttons: kSecondaryButton);
    await _tap(tester, find.text('Archivia'));
    await _expire(tester);

    expect(await _labelsOf(tester, 'm1'), isNot(contains(inboxLabelId)));
    expect(await _labelsOf(tester, 'm2'), contains(trashLabelId));
    expect(_sentFor('m2'), isEmpty);
  });

  testWidgets('Archivia by swiping an inbox row leaves the message in the Cestino there', (tester) async {
    await _start(tester, size: const Size(500, 900));
    await tester.drag(_row('m1'), const Offset(-200, 0));
    await _settle(tester);
    await _expire(tester);

    expect(await _labelsOf(tester, 'm2'), contains(trashLabelId));
    expect(_sentFor('m2'), isEmpty);
  });

  _onMac('the picker from an inbox row ticks and applies on the messages shown only', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m1'), buttons: kSecondaryButton);
    await _tap(tester, find.byKey(const ValueKey('row-labels-a1-m1')));
    await _tap(tester, _tile('Fatture'));

    expect(await _labelsOf(tester, 'm1'), contains('Label_13'));
    expect(await _labelsOf(tester, 'm2'), isNot(contains('Label_13')));
    expect(_sentFor('m2'), isEmpty);
    expect(_ticked(tester, 'Viaggi'), isFalse, reason: 'only the message in the Cestino has it');
  });

  _onMac('Archivia with the shortcut on an inbox row leaves the message in the Cestino there', (tester) async {
    await _start(tester);
    tester.widget<PostinoMessageTile>(_row('m1')).focusNode!.requestFocus();
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await _settle(tester);
    await _expire(tester);

    expect(await _labelsOf(tester, 'm1'), isNot(contains(inboxLabelId)));
    expect(await _labelsOf(tester, 'm2'), contains(trashLabelId));
    expect(_sentFor('m2'), isEmpty);
  });

  _onMac('unticking from an inbox row, and its Annulla, leave the message in the Cestino alone', (tester) async {
    await _start(tester, m1Labels: const ['INBOX', 'Label_12']);
    await _tap(tester, _row('m1'), buttons: kSecondaryButton);
    await _tap(tester, find.byKey(const ValueKey('row-labels-a1-m1')));
    await _tap(tester, _tile('Viaggi'));
    expect(await _labelsOf(tester, 'm1'), isNot(contains('Label_12')));
    expect(await _labelsOf(tester, 'm2'), contains('Label_12'));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    await _tap(tester, find.widgetWithText(PostinoButton, 'Annulla'));
    expect(await _labelsOf(tester, 'm1'), contains('Label_12'));
    expect(_sentFor('m2'), isEmpty);
  });

  _onMac('a tick while the picker still fetches the Conversazione does not reach the message in the Cestino', (
    tester,
  ) async {
    await _start(tester);
    gmail.holdConversation = Completer<void>();
    await _tap(tester, _row('m1'), buttons: kSecondaryButton);
    await _tap(tester, find.byKey(const ValueKey('row-labels-a1-m1')));
    await _tap(tester, _tile('Fatture'));
    gmail.holdConversation!.complete();
    await _settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);

    expect(await _labelsOf(tester, 'm1'), contains('Label_13'));
    expect(await _labelsOf(tester, 'm2'), isNot(contains('Label_13')));
    expect(_sentFor('m2'), isEmpty);
  });

  _onMac('the picker from the Conversazione opened from the inbox ticks and applies on the messages shown only', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('m1'));
    await _tap(tester, find.byTooltip('Etichette'));

    expect(_ticked(tester, 'Viaggi'), isFalse, reason: 'only the message in the Cestino has it');
    await _tap(tester, _tile('Fatture'));

    expect(await _labelsOf(tester, 'm2'), isNot(contains('Label_13')));
    expect(_sentFor('m2'), isEmpty);
  });

  _onMac('from the Cestino the picker still sees and reaches every message', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(labelPath('a1', trashLabelId)));
    await _settle(tester);
    await _tap(tester, _row('m2'), buttons: kSecondaryButton);
    await _tap(tester, find.byKey(const ValueKey('row-labels-a1-m2')));

    expect(_ticked(tester, 'Viaggi'), isTrue);
    await _tap(tester, _tile('Fatture'));
    expect(await _labelsOf(tester, 'm2'), contains('Label_13'));
  });

  _onMac('the view of the list reaches its rows and the Conversazione it opens', (tester) async {
    await _start(tester);
    expect(tester.widget<MessageList>(find.byType(MessageList)).view, inboxLabelId);

    unawaited(Routefly.navigate(labelPath('a1', trashLabelId)));
    await _settle(tester);
    expect(tester.widget<MessageList>(find.byType(MessageList)).view, trashLabelId);
    await _tap(tester, _row('m2'));
    expect(tester.widget<ConversationView>(find.byType(ConversationView)).view, trashLabelId);
  });

  _onMac('the search from the Cestino gives its view to the results and the Conversazione it opens', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(labelPath('a1', trashLabelId)));
    await _settle(tester);
    await _tap(tester, find.byTooltip('Cerca'));
    await tester.enterText(find.byType(TextField), 'Cena');
    await _settle(tester);

    final results = find.byType(MessageList);
    expect(tester.widget<MessageList>(results).view, trashLabelId);
    await _tap(tester, find.descendant(of: results, matching: find.byType(PostinoMessageTile)).first);
    expect(tester.widget<ConversationView>(find.byType(ConversationView)).view, trashLabelId);
  });
}
