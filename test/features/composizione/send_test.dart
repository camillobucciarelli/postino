// Invio (#36): Invia closes the composer and shows the Snackbar of Annulla invio; the fake Provider gets the
// message only after the 10 s window (fake clock), once; Annulla reopens the Bozza; the Inviati list shows
// the queued message with its state (also offline), then the sent one; the Gmail limit; a restart; the
// semantics and Cmd+Enter.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _id = 'a1';
const _waiting = "In attesa d'invio";
const _offline = 'In uscita, in attesa di rete';

late Harness h;
late FakeMailProvider gmail;

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = await h.addAccount(_id);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  Routefly.navigate(routePaths.posta.path);
  await tester.pumpAndSettle();
}

/// flutter_quill reads the platform once: macOS, as the app in QA; semantics on, for the labels.
void _onMac(
  String name,
  Future<void> Function(WidgetTester) body, {
  bool skip = false,
}) => testWidgets(name, skip: skip, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  final semantics = tester.ensureSemantics();
  try {
    await body(tester);
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
});

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is PostinoComposerField && w.label == label,
  ),
  matching: find.byType(TextField),
);

Future<void> _typeInEditor(WidgetTester tester, String text) async {
  await tester.tap(find.byType(QuillEditor));
  await tester.pump();
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: '$text\n',
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

/// Opens a new composition from the FAB and fills A, Oggetto and the body.
Future<void> _write(WidgetTester tester, {bool recipient = true}) async {
  await tester.tap(find.text('Scrivi'));
  await tester.pumpAndSettle();
  if (recipient) await tester.enterText(_field('A'), 'ada@example.com');
  await tester.enterText(_field('Oggetto'), 'Saluti');
  await _typeInEditor(tester, 'Ciao Ada');
  await tester.pumpAndSettle();
}

String _openId() => Routefly.currentUri.pathSegments[3];

/// Frames plus the event queue: the database answers between frames, with nothing scheduled meanwhile.
/// Bounded pumps, never pumpAndSettle: the Snackbar ticks every second while shown and would never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(pumpEventQueue);
  }
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Invia'));
  await _settle(tester);
}

Future<void> _afterWindow(WidgetTester tester) async {
  h.clock.advance(PostinoMotion.undoWindow);
  await _settle(tester);
}

Finder get _undo => find.widgetWithText(PostinoButton, 'Annulla');

/// The text [s] inside a row of the list (not in the Snackbar).
Finder _inTile(String s) => find.descendant(
  of: find.byType(PostinoMessageTile),
  matching: find.textContaining(s),
);

Future<void> _openSent(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('sent-$_id')));
  await _settle(tester);
}

void main() {
  _onMac(
    'after Invia «Annulla» shows; the Provider gets the message only after 10 s, once',
    (tester) async {
      await _start(tester);
      await _write(tester);
      await _send(tester);
      expect(find.byType(PostinoComposerField), findsNothing);
      expect(_undo, findsOneWidget);
      expect(gmail.sent, isEmpty);

      await _afterWindow(tester);
      expect(gmail.sent, hasLength(1));
      expect(gmail.sent.single.$1, matches(RegExp(r'^<.+@example\.com>$')));

      // The Snackbar lives on real time: the window over, it goes.
      await tester.pump(PostinoMotion.undoWindow);
      await tester.pump(const Duration(seconds: 1));
      expect(_undo, findsNothing);
      await _afterWindow(tester);
      expect(gmail.sent, hasLength(1));
    },
  );

  _onMac(
    '«Annulla» reopens the composition with the text; the message stays a Bozza',
    (tester) async {
      await _start(tester);
      await _write(tester);
      final id = _openId();
      await _send(tester);
      await tester.tap(_undo);
      await _settle(tester);

      expect(_openId(), id);
      expect(
        tester.widget<TextField>(_field('Oggetto')).controller!.text,
        'Saluti',
      );
      expect(
        tester
            .widget<QuillEditor>(find.byType(QuillEditor))
            .controller
            .document
            .toPlainText(),
        contains('Ciao Ada'),
      );
      final drafts = await GetIt.I<InboxRepository>().watchDrafts(_id).first;
      expect(drafts.single.subject, 'Saluti');
      await _afterWindow(tester);
      expect(gmail.sent, isEmpty);
    },
  );

  _onMac(
    'Inviati lists the message as «In attesa d\'invio» at once, then as sent without a state',
    (tester) async {
      await _start(tester);
      await _write(tester);
      await _send(tester);
      await _openSent(tester);
      expect(find.text('Inviati'), findsWidgets);
      expect(_inTile(_waiting), findsOneWidget);
      expect(_inTile('Saluti'), findsOneWidget);

      await _afterWindow(tester);
      expect(_inTile(_waiting), findsNothing);
      expect(_inTile(_offline), findsNothing);
      expect(_inTile('Saluti'), findsOneWidget);
      expect(gmail.sent, hasLength(1));
    },
  );

  _onMac(
    'offline the message waits as «In uscita, in attesa di rete» and goes once with the network',
    (tester) async {
      await _start(tester);
      h.connectivity.online = false;
      gmail.goOffline();
      await _write(tester);
      await _send(tester);
      await _openSent(tester);
      expect(_inTile(_waiting), findsOneWidget);

      await _afterWindow(tester);
      expect(gmail.sent, isEmpty);
      expect(_inTile(_offline), findsOneWidget);

      gmail.goOnline();
      h.connectivity.online = true;
      await _settle(tester);
      expect(gmail.sent, hasLength(1));
      expect(_inTile(_offline), findsNothing);
      expect(_inTile('Saluti'), findsOneWidget);
    },
  );

  _onMac('Invia without a recipient asks for one and queues nothing', (
    tester,
  ) async {
    await _start(tester);
    await _write(tester, recipient: false);
    await _send(tester);
    expect(find.text('Aggiungi almeno un destinatario'), findsOneWidget);
    expect(find.byType(PostinoComposerField), findsWidgets);
    await _afterWindow(tester);
    expect(gmail.sent, isEmpty);
    // The next edit clears the notice.
    await tester.enterText(_field('A'), 'ada@example.com');
    await _settle(tester);
    expect(find.text('Aggiungi almeno un destinatario'), findsNothing);
    // The Bozza reaches the Provider: left pending, the composer's flush on dispose blocks the next database reset.
    await _afterWindow(tester);
  });

  _onMac('a message over the Gmail limit is refused, naming the 35 MB limit', (
    tester,
  ) async {
    await _start(tester);
    // ponytail: 37 MB put in the Quill document never lays out in a widget test (tried: it hangs); the engine's refusal of a real
    // oversized message is outbox_sync_test's, here the composer only has to show it.
    final real = GetIt.I<MailSync>();
    GetIt.I
      ..unregister<MailSync>()
      ..registerSingleton<MailSync>(_TooBig(real));
    await _write(tester);
    await _send(tester);
    expect(
      find.text('Il messaggio supera il limite di 35 MB di Gmail'),
      findsOneWidget,
    );
    expect(find.byType(PostinoComposerField), findsWidgets);
    expect(_undo, findsNothing);
    await _afterWindow(tester);
    expect(gmail.sent, isEmpty);
  });

  _onMac(
    'a message still queued at the restart of PostinoApp goes',
    // The app is disposed within the window and started again after it: the replay at start sends it.
    (tester) async {
      await _start(tester);
      await _write(tester);
      await _send(tester);
      // The app closes within the window; time passes while it is down.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(pumpEventQueue);
      h.clock.advance(const Duration(minutes: 1));
      await tester.runAsync(pumpEventQueue);
      expect(gmail.sent, isEmpty);

      await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
      await _settle(tester);
      expect(gmail.sent, hasLength(1));
    },
  );

  _onMac(
    'the Snackbar announces «In attesa d\'invio»; Tab reaches «Annulla», Enter runs it',
    (tester) async {
      await _start(tester);
      await _write(tester);
      final id = _openId();
      await _send(tester);
      expect(find.bySemanticsLabel(RegExp(_waiting)), findsOneWidget);
      expect(
        find.semantics.byLabel('Annulla'),
        isSemantics(isButton: true, isEnabled: true),
      );

      // The focus sits inside the «Annulla» button (a scope above it would also contain the text).
      Finder focused() => find.ancestor(
        of: find.byElementPredicate(
          (e) => e == FocusManager.instance.primaryFocus?.context,
        ),
        matching: _undo,
      );
      for (var i = 0; i < 40 && focused().evaluate().isEmpty; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focused(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(_openId(), id);
      await _afterWindow(tester);
      expect(gmail.sent, isEmpty);
    },
  );

  _onMac('Cmd+Enter in the editor sends', (tester) async {
    await _start(tester);
    await _write(tester);
    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await _settle(tester);
    expect(find.byType(PostinoComposerField), findsNothing);
    expect(_undo, findsOneWidget);
    await _afterWindow(tester);
    expect(gmail.sent, hasLength(1));
  });
}

/// The real engine, but every message is over the Provider's limit.
class _TooBig implements MailSync {
  _TooBig(this.real);
  final MailSync real;

  @override
  Future<Result<DateTime>> send(String a, OutgoingMessage m) async =>
      const Err(SizeLimitFailure(gmailSendLimitBytes));
  @override
  Future<void> syncAll() => real.syncAll();
  @override
  Future<Result<void>> openConversation(String a, String c) =>
      real.openConversation(a, c);
  @override
  Future<Result<void>> fetchBody(String a, String m) => real.fetchBody(a, m);
  @override
  Future<void> saveDraft(String a, OutgoingMessage d) => real.saveDraft(a, d);
  @override
  Future<void> flushDrafts(String a) => real.flushDrafts(a);
  @override
  Future<bool> cancelSend(String a, String m) => real.cancelSend(a, m);
  @override
  Future<void> flushOutbox(String a) => real.flushOutbox(a);
  @override
  Future<Result<OutgoingMessage>> openDraft(String a, String m) =>
      real.openDraft(a, m);
}
