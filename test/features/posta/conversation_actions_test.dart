// Azioni in Posta (#146): Archivia, Elimina, Stella, letto/non letto from the Conversazione's header, from the
// context menu of a row and from the keyboard; on the whole Conversazione, here at once; Archivia and Elimina (and
// an Etichetta on a folder Provider) held behind «Annulla» for `undoWindow`, which keeps them off the Provider.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_model_download.dart';
import '../../support/harness.dart';

late Harness h;
late FakeMailProvider gmail;

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

/// The list, newest first: x (x1), o (o1), t (m1, m2).
/// [olderStarred]: m1, not the latest, has the Stella.
Future<void> _start(
  WidgetTester tester, {
  ProviderKind provider = ProviderKind.gmail,
  bool olderStarred = false,
}) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  await getIt.unregister<ModelDownload>();
  getIt.registerSingleton<ModelDownload>(FakeModelDownload());
  gmail = await h.addAccount('a1', provider: provider);
  gmail.labels.add(const Label(id: 'Label_13', name: 'Fatture', kind: LabelKind.etichetta));
  gmail
    ..deliver(
      msg(
        'm1',
        conversationId: 't',
        subject: 'Cena',
        date: _day(1),
        isRead: true,
        isStarred: olderStarred,
        labelIds: [inboxLabelId, if (olderStarred) starredLabelId],
      ),
    )
    ..deliver(msg('m2', conversationId: 't', subject: 'Re: Cena', date: _day(2), isRead: true))
    ..deliver(msg('o1', conversationId: 'o', subject: 'Altro', date: _day(3), isRead: true))
    ..deliver(msg('x1', conversationId: 'x', subject: 'Ultimo', date: _day(4), isRead: true));
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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _settle(tester);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false, String? character}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key, character: character);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await _settle(tester);
}

/// The Annulla window ends: on the app's clock (the held voci) and on the test's (the snackbar).
Future<void> _expire(WidgetTester tester) async {
  h.clock.advance(PostinoMotion.undoWindow);
  await tester.pump(PostinoMotion.undoWindow + const Duration(seconds: 1));
  await _settle(tester);
}

void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  final semantics = tester.ensureSemantics();
  try {
    await body(tester);
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
});

Finder _row(String latest) => find.byKey(ValueKey('row-a1-$latest'));
Finder _open(String conversation) => find.byKey(ValueKey('conversation-a1/$conversation'));
Finder get _snackbar => find.byType(PostinoSnackbar);
Finder get _undo => find.widgetWithText(PostinoButton, 'Annulla');
PostinoMessageTile _tile(WidgetTester tester, String latest) => tester.widget<PostinoMessageTile>(_row(latest));

/// The Azioni that reached the Provider, comparable.
List<(String, MailAction)> get _sent => [for (final (id, action, _) in gmail.actionCalls) (id, action)];

Future<void> _menu(WidgetTester tester, String latest, String item) async {
  await tester.tap(_row(latest), buttons: kSecondaryButton);
  await _settle(tester);
  await _tap(tester, find.text(item));
}

void main() {
  _onMac('Archivia from the Conversazione: the row leaves at once and the next opens, behind Annulla; the Provider '
      'gets it when the window ends', (tester) async {
    await _start(tester);
    await _tap(tester, _row('o1'));
    await _tap(tester, find.byTooltip('Archivia'));

    expect(_row('o1'), findsNothing);
    expect(_open('t'), findsOneWidget);
    expect(find.text('Conversazione archiviata'), findsOneWidget);
    expect(_sent, isNot(contains(('o1', const Archive()))));

    await _expire(tester);
    expect(_snackbar, findsNothing);
    expect(_sent, contains(('o1', const Archive())));
  });

  _onMac('Annulla within the window puts the row back, and nothing reaches the Provider', (tester) async {
    await _start(tester);
    await _tap(tester, _row('o1'));
    await _tap(tester, find.byTooltip('Elimina'));
    // No Cestino view: the copy says where it went.
    expect(find.text('Conversazione spostata nel Cestino'), findsOneWidget);
    expect(_row('o1'), findsNothing);

    await _tap(tester, _undo);
    expect(_row('o1'), findsOneWidget);
    await _expire(tester);
    await _expire(tester);
    expect(_sent.where((s) => s.$2 is Delete), isEmpty);
  });

  _onMac('Stella and non letto act on the whole Conversazione at once, with no Annulla; non letto closes it', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    await _tap(tester, find.byTooltip('Aggiungi stella'));
    expect(_snackbar, findsNothing);
    expect(_tile(tester, 'm2').starred, isTrue);
    expect(_sent, containsAll([('m1', const Star()), ('m2', const Star())]));
    expect(find.byTooltip('Togli stella'), findsOneWidget);

    await _tap(tester, find.byTooltip('Segna come non letto'));
    expect(_snackbar, findsNothing);
    expect(_open('t'), findsNothing);
    expect(_tile(tester, 'm2').unread, isTrue);
    expect(_sent, containsAll([('m1', const MarkUnread()), ('m2', const MarkUnread())]));
  });

  _onMac('the context menu of a row: Archivia with Annulla, Stella and letto/non letto without', (tester) async {
    await _start(tester);
    await _menu(tester, 'o1', 'Archivia');
    expect(_row('o1'), findsNothing);
    expect(find.text('Conversazione archiviata'), findsOneWidget);
    await _expire(tester);
    expect(_sent, contains(('o1', const Archive())));

    await _menu(tester, 'x1', 'Aggiungi stella');
    expect(_tile(tester, 'x1').starred, isTrue);
    await _menu(tester, 'x1', 'Segna come non letto');
    expect(_tile(tester, 'x1').unread, isTrue);
    await _menu(tester, 'x1', 'Segna come letto');
    expect(_tile(tester, 'x1').unread, isFalse);
    expect(_snackbar, findsNothing);
    expect(_sent, containsAllInOrder([('x1', const Star()), ('x1', const MarkUnread()), ('x1', const MarkRead())]));
  });

  _onMac('the shortcuts: e and # move the selection to the next Conversazione, s stars, Maiusc+U and Maiusc+I; '
      'ignored in a text field', (tester) async {
    await _start(tester);
    await _tap(tester, _row('o1'));
    await _key(tester, LogicalKeyboardKey.keyE);
    expect(_row('o1'), findsNothing);
    expect(_open('t'), findsOneWidget);

    // The last row: the previous one opens.
    await _key(tester, LogicalKeyboardKey.digit3, shift: true, character: '#');
    expect(_row('m2'), findsNothing);
    expect(find.text('Conversazione spostata nel Cestino'), findsOneWidget);
    expect(_open('x'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.keyS);
    expect(_tile(tester, 'x1').starred, isTrue);
    await _key(tester, LogicalKeyboardKey.keyS);
    expect(_tile(tester, 'x1').starred, isFalse);

    await _key(tester, LogicalKeyboardKey.keyU, shift: true);
    expect(_tile(tester, 'x1').unread, isTrue);
    expect(_open('x'), findsNothing);

    // In the search field of the picker the letters are typed.
    await _tap(tester, _row('x1'));
    expect(_tile(tester, 'x1').unread, isFalse);
    await _key(tester, LogicalKeyboardKey.keyL);
    await _tap(tester, find.byKey(const ValueKey('label-search')));
    await _key(tester, LogicalKeyboardKey.keyE, character: 'e');
    await _key(tester, LogicalKeyboardKey.keyS, character: 's');
    await _key(tester, LogicalKeyboardKey.digit3, shift: true, character: '#');
    expect(_row('x1'), findsOneWidget);
    expect(_tile(tester, 'x1').starred, isFalse);

    await _expire(tester);
    expect(_sent, containsAll([('o1', const Archive()), ('m1', const Delete()), ('m2', const Delete())]));

    // The last Conversazione of the list: none to move to, it closes.
    await _escape(tester);
    await _key(tester, LogicalKeyboardKey.keyE);
    expect(_row('x1'), findsNothing);
    expect(_open('x'), findsNothing);
  });

  _onMac('# is the character, whatever the layout puts it on: Option+à on the Italian Mac one', (tester) async {
    await _start(tester);
    await _tap(tester, _row('o1'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3, character: '#');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _settle(tester);
    expect(_row('o1'), findsNothing);
    expect(find.text('Conversazione spostata nel Cestino'), findsOneWidget);
  });

  _onMac('the row menu of the open Conversazione goes through it: Archivia opens the next, non letto closes it '
      'and it stays unread', (tester) async {
    await _start(tester);
    await _tap(tester, _row('o1'));
    await _menu(tester, 'o1', 'Archivia');
    expect(_row('o1'), findsNothing);
    expect(_open('t'), findsOneWidget);

    await _menu(tester, 'm2', 'Segna come non letto');
    expect(_open('t'), findsNothing);
    expect(_tile(tester, 'm2').unread, isTrue);
    await _settle(tester);
    expect(_tile(tester, 'm2').unread, isTrue);
  });

  _onMac('from the list the whole Conversazione is reached, older messages too, under the same Annulla', (
    tester,
  ) async {
    await _start(tester);
    gmail.deliverOutsideWindow(msg('o0', conversationId: 'o', subject: 'Altro', date: _day(1), isRead: true));
    await _menu(tester, 'o1', 'Elimina');
    await _settle(tester);
    expect(_sent.where((s) => s.$2 is Delete), isEmpty);
    await _expire(tester);
    expect(_sent, containsAll([('o1', const Delete()), ('o0', const Delete())]));

    gmail.deliverOutsideWindow(msg('x0', conversationId: 'x', subject: 'Ultimo', date: _day(1), isRead: true));
    await _menu(tester, 'x1', 'Archivia');
    await _settle(tester);
    await _tap(tester, _undo);
    await _expire(tester);
    expect(_sent.where((s) => s.$1 == 'x0' || s.$1 == 'x1'), isEmpty);
  });

  // An opening held behind a slow fetch: the older message o0 arrives only when it ends.
  Future<void> openSlowly(WidgetTester tester, {ProviderKind provider = ProviderKind.gmail}) async {
    await _start(tester, provider: provider);
    gmail
      ..deliverOutsideWindow(msg('o0', conversationId: 'o', subject: 'Altro', date: _day(1), isRead: true))
      ..holdConversation = Completer<void>();
    await _tap(tester, _row('o1'));
  }

  Future<void> endFetch(WidgetTester tester) async {
    gmail.holdConversation!.complete();
    await _settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
  }

  _onMac('Archivia while the opening is still fetching reaches the older messages it brings, held with the rest', (
    tester,
  ) async {
    await openSlowly(tester);
    await _tap(tester, find.byTooltip('Archivia'));
    await endFetch(tester);
    expect(_sent.where((s) => s.$2 is Archive), isEmpty);
    await _expire(tester);
    expect(_sent, containsAll([('o1', const Archive()), ('o0', const Archive())]));
  });

  _onMac('Annulla of an Archivia taken during the opening keeps the older messages here too', (tester) async {
    await openSlowly(tester);
    await _tap(tester, find.byTooltip('Archivia'));
    await endFetch(tester);
    await _tap(tester, _undo);
    await _expire(tester);
    expect(_sent.where((s) => s.$2 is Archive), isEmpty);
  });

  _onMac('non letto during the opening reaches the older messages it brings', (tester) async {
    await openSlowly(tester);
    await _tap(tester, find.byTooltip('Segna come non letto'));
    await endFetch(tester);
    expect(_sent, containsAll([('o1', const MarkUnread()), ('o0', const MarkUnread())]));
  });

  _onMac('on a folder Provider an Etichetta applied during a fetch holds the older messages too, under its Annulla', (
    tester,
  ) async {
    await openSlowly(tester, provider: ProviderKind.imap);
    await _tap(tester, find.byTooltip('Etichette'));
    await _tap(tester, find.widgetWithText(PostinoCheckboxTile, 'Fatture'));
    await _escape(tester);
    await endFetch(tester);
    expect(gmail.labelCalls.where((c) => c.$2 == 'Label_13'), isEmpty);
    await _tap(tester, _undo);
    await _expire(tester);
    expect(gmail.labelCalls.where((c) => c.$2 == 'Label_13'), isEmpty);
  });

  _onMac('in Inviati Archivia never moves to a queued send: none left, the Conversazione closes and the send stays', (
    tester,
  ) async {
    await _start(tester);
    gmail.deliver(msg('s1', conversationId: 's', subject: 'Inviato', date: _day(5), labelIds: const [sentLabelId]));
    await _settle(tester);
    h.connectivity.online = false;
    gmail.goOffline();
    unawaited(
      getIt<MailSync>().send(
        'a1',
        const OutgoingMessage(
          messageId: '<q1@example.com>',
          from: 'a1@example.com',
          to: ["ada@example.com"],
          subject: 'In coda',
          body: 'Ciao',
        ),
      ),
    );
    await _settle(tester);
    unawaited(
      Routefly.navigate(
        routePaths.posta.$accountId.etichetta.$labelId.changes({'accountId': 'a1', 'labelId': sentLabelId}),
      ),
    );
    await _settle(tester);
    await _tap(tester, _row('s1'));
    expect(_open('s'), findsOneWidget);

    await _tap(tester, find.byTooltip('Archivia'));
    expect(_open('s'), findsNothing);
    expect(find.byType(PostinoComposerField), findsNothing);
    expect(find.descendant(of: find.byType(PostinoMessageTile), matching: find.text('In coda')), findsOneWidget);
  });

  _onMac('a Stella on an older message stands for the Conversazione: the row offers to take it off, s takes it off', (
    tester,
  ) async {
    await _start(tester, olderStarred: true);
    _tile(tester, 'm2').focusNode!.requestFocus();
    await _settle(tester);
    await _key(tester, LogicalKeyboardKey.keyS);
    expect(_sent, contains(('m1', const Unstar())));
    await tester.tap(_row('m2'), buttons: kSecondaryButton);
    await _settle(tester);
    expect(find.text('Aggiungi stella'), findsOneWidget);
  });

  _onMac('with no Conversazione open the shortcuts act on the focused row; Archivia moves the focus on', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('x1'));
    await _key(tester, LogicalKeyboardKey.keyU, shift: true);
    expect(_open('x'), findsNothing);
    expect(_tile(tester, 'x1').focusNode!.hasPrimaryFocus, isTrue);

    await _key(tester, LogicalKeyboardKey.keyI, shift: true);
    expect(_tile(tester, 'x1').unread, isFalse);
    expect(_sent, containsAllInOrder([('x1', const MarkUnread()), ('x1', const MarkRead())]));

    await _key(tester, LogicalKeyboardKey.keyE);
    expect(_row('x1'), findsNothing);
    expect(find.text('Conversazione archiviata'), findsOneWidget);
    expect(_tile(tester, 'o1').focusNode!.hasPrimaryFocus, isTrue);
    expect(_open('o'), findsNothing);
  });

  _onMac('offline the list changes at once; the Provider gets it when the network returns', (tester) async {
    await _start(tester);
    gmail.goOffline();
    h.connectivity.online = false;
    await _tap(tester, _row('o1'));
    await _tap(tester, find.byTooltip('Archivia'));
    expect(_row('o1'), findsNothing);
    await _expire(tester);
    expect(_sent, isNot(contains(('o1', const Archive()))));

    gmail.goOnline();
    h.connectivity.online = true;
    await _settle(tester);
    expect(_sent, contains(('o1', const Archive())));
  });

  _onMac('on a folder Provider an Etichetta applied offers Annulla, which keeps it off the Provider', (tester) async {
    await _start(tester, provider: ProviderKind.imap);
    await _tap(tester, _row('o1'));
    await _tap(tester, find.byTooltip('Etichette'));
    await _tap(tester, find.widgetWithText(PostinoCheckboxTile, 'Fatture'));
    expect(find.text('Etichetta «Fatture» applicata'), findsOneWidget);
    expect(tester.widget<PostinoCheckboxTile>(find.widgetWithText(PostinoCheckboxTile, 'Fatture')).value, isTrue);

    await _escape(tester);
    expect(_tile(tester, 'o1').labels, ['Fatture']);
    await _tap(tester, _undo);
    expect(_tile(tester, 'o1').labels, isEmpty);
    await _expire(tester);
    expect(gmail.labelCalls.where((c) => c.$2 == 'Label_13'), isEmpty);
  });

  _onMac('screen reader: the buttons are named, the Annulla announced, the Azioni custom actions of the row', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    for (final name in ['Archivia', 'Elimina', 'Aggiungi stella', 'Segna come non letto', 'Etichette']) {
      expect(tester.getSemantics(find.byTooltip(name)), isSemantics(tooltip: name, isButton: true), reason: name);
    }
    await _tap(tester, find.byTooltip('Archivia'));
    final announced = tester.getSemantics(find.bySemanticsLabel(RegExp('^Conversazione archiviata, ')));
    expect(announced.flagsCollection.isLiveRegion, isTrue);

    final action = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Archivia'));
    final node = find.semantics
        .byPredicate((n) => n.getSemanticsData().customSemanticsActionIds?.contains(action) ?? false)
        .evaluate()
        .first;
    node.owner!.performAction(node.id, SemanticsAction.customAction, action);
    await _settle(tester);
    expect(_row('x1'), findsNothing);
  });
}
