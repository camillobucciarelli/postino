// Attachments of a Conversazione (#34): name and size, a tap downloads (then opens from the cache, offline too),
// progress and Annulla, the offline note, Salva… from the menu, keyboard, screen reader and selectable text.
import 'dart:async';
import 'dart:ui' show ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

late Harness h;
late FakeMailProvider gmail;
String? _clipboard;

/// Opens Conversazione m1 (Contratto.pdf, 88 KB, and note.txt, 980 B) on a desktop window.
Future<void> _start(WidgetTester tester, {int? cap}) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      _clipboard = (call.arguments as Map)['text'] as String?;
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  h = await Harness.create(attachmentCap: cap);
  gmail = await h.addAccount('a1')
    ..bodies['m1'] = const MessageBody('Ti mando il contratto', BodyKind.testo)
    ..attach('m1', 'Contratto.pdf', List.filled(88 * 1024, 7))
    ..attach('m1', 'note.txt', List.filled(980, 1))
    ..deliver(msg('m1', conversationId: 't', subject: 'Contratto'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('row-a1-m1')));
  await tester.pumpAndSettle();
}

Finder _chip(String name) => find.byKey(ValueKey('attachment-m1-att-$name'));
Finder _in(String name, Key key) => find.descendant(of: _chip(name), matching: find.byKey(key));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// m1 with setup.exe, install.command, script.sh and a bidi-spoofed name too (#75), for the tests on executables.
Future<void> _startWithExecutables(WidgetTester tester) async {
  await _start(tester);
  gmail
    ..attach('m1', 'setup.exe', List.filled(100, 2))
    ..attach('m1', 'install.command', List.filled(100, 3))
    ..attach('m1', 'script.sh', List.filled(100, 4))
    ..attach('m1', 'fattura\u202Efdp.exe', List.filled(100, 5))
    ..deliver(msg('m1', conversationId: 't', subject: 'Contratto'));
  await tester.pumpAndSettle();
}

List<String> get _cached => h.fs.directory('/support/attachments').listSync().map((e) => e.path).toList();

void main() {
  testWidgets('each attachment shows its name and size', (tester) async {
    await _start(tester);
    expect(find.text('Contratto.pdf'), findsOneWidget);
    expect(find.textContaining('88 KB', findRichText: true), findsOneWidget);
    expect(find.text('note.txt'), findsOneWidget);
    expect(find.textContaining('980 B', findRichText: true), findsOneWidget);
    // The type is written, not only colored.
    expect(find.descendant(of: _chip('Contratto.pdf'), matching: find.text('PDF')), findsOneWidget);
  });

  testWidgets('the first tap downloads and opens; the second, offline, opens from the cache', (tester) async {
    await _start(tester);
    await _tap(tester, _chip('Contratto.pdf'));
    expect(gmail.attachmentCalls, [('m1', 'att-Contratto.pdf')]);
    final opened = h.links.opened.single;
    expect(opened.scheme, 'file');
    expect(opened.pathSegments.last, 'Contratto.pdf');
    expect(h.fs.file(opened.toFilePath()).lengthSync(), 88 * 1024);

    gmail.goOffline();
    await _tap(tester, _chip('Contratto.pdf'));
    expect(gmail.attachmentCalls, hasLength(1));
    expect(h.links.opened, hasLength(2));
  });

  testWidgets('offline, an attachment never downloaded says so clearly', (tester) async {
    await _start(tester);
    gmail.goOffline();
    await _tap(tester, _chip('note.txt'));
    expect(find.textContaining('Offline: allegato non ancora scaricato', findRichText: true), findsOneWidget);
    expect(h.links.opened, isEmpty);

    // Back online, Riprova opens it.
    gmail.goOnline();
    await _tap(tester, _in('note.txt', const ValueKey('attachment-retry')));
    expect(find.textContaining('Offline: allegato non ancora scaricato', findRichText: true), findsNothing);
    expect(h.links.opened, hasLength(1));
  });

  testWidgets('while downloading: progress and Annulla, which leaves nothing cached', (tester) async {
    await _start(tester);
    gmail.holdAttachment = Completer<void>();
    await _tap(tester, _chip('Contratto.pdf'));
    expect(find.textContaining('Scaricamento… 50%', findRichText: true), findsOneWidget);
    expect(
      tester.widget<FractionallySizedBox>(_in('Contratto.pdf', const ValueKey('attachment-progress'))).widthFactor,
      0.5,
    );

    await _tap(tester, _in('Contratto.pdf', const ValueKey('attachment-cancel')));
    expect(find.textContaining('Scaricamento… 50%', findRichText: true), findsNothing);
    expect(find.textContaining('88 KB', findRichText: true), findsOneWidget);
    expect(_cached, isEmpty);
    expect(h.links.opened, isEmpty);
  });

  testWidgets('closing the Conversazione mid-download cancels it: no open, '
      'no save, no error', (tester) async {
    await _start(tester);
    gmail.holdAttachment = Completer<void>();
    await _tap(tester, _chip('Contratto.pdf'));
    expect(_in('Contratto.pdf', const ValueKey('attachment-cancel')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_chip('Contratto.pdf'), findsNothing);
    gmail.holdAttachment!.complete();
    await tester.pumpAndSettle();
    expect(h.links.opened, isEmpty);
    expect(h.saver.saved, isEmpty);
    expect(_cached, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an attachment bigger than the cache opens without being cached', (tester) async {
    await _start(tester, cap: 10 * 1024);
    await _tap(tester, _chip('Contratto.pdf'));
    expect(h.links.opened, hasLength(1));
    expect(_cached, isEmpty);

    // The small one still fits.
    await _tap(tester, _chip('note.txt'));
    expect(_cached, hasLength(1));
  });

  testWidgets('Salva… in the menu offers Save As, with the attachment name', (tester) async {
    await _start(tester);
    await _tap(tester, _in('Contratto.pdf', const ValueKey('attachment-more')));
    await _tap(tester, find.text('Salva…'));
    final (path, name) = h.saver.saved.single;
    expect(name, 'Contratto.pdf');
    expect(h.fs.file(path).lengthSync(), 88 * 1024);
    expect(h.links.opened, isEmpty);
  });

  testWidgets('no Save As where the platform has none', (tester) async {
    await _start(tester);
    h.saver.available = false;
    // Rebuilt by the next state change.
    await _tap(tester, _chip('note.txt'));
    expect(_in('note.txt', const ValueKey('attachment-more')), findsNothing);
  });

  testWidgets('keyboard: Tab reaches each attachment, Enter opens, the menu saves', (tester) async {
    await _start(tester);
    Future<void> tabTo(Finder target) async {
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null &&
            find.ancestor(of: find.byElementPredicate((e) => e == focused), matching: target).evaluate().isNotEmpty) {
          return;
        }
      }
      fail('Tab never reached $target');
    }

    await tabTo(_in('Contratto.pdf', const ValueKey('attachment-open')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.links.opened, hasLength(1));

    await tabTo(_in('Contratto.pdf', const ValueKey('attachment-more')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // The menu takes the focus: Enter picks Salva….
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.saver.saved.single.$2, 'Contratto.pdf');

    await tabTo(_in('note.txt', const ValueKey('attachment-open')));
  });

  testWidgets('screen readers hear the name, the size and that it opens', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester);
    expect(
      tester.getSemantics(
        find.descendant(of: _chip('Contratto.pdf'), matching: find.bySemanticsLabel('Contratto.pdf')),
      ),
      matchesSemantics(label: 'Contratto.pdf', value: '88 KB', hint: 'Apri', isButton: true, hasTapAction: true),
    );
    expect(find.byTooltip('Altre azioni'), findsNWidgets(2));
    handle.dispose();
  });

  testWidgets('name and size are selectable and copiable', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Ti mando il contratto'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_clipboard, contains('Contratto.pdf'));
    expect(_clipboard, contains('88 KB'));
    expect(_clipboard, contains('note.txt'));
    // Buttons and the type badge stay out of the selection.
    expect(_clipboard, isNot(contains('PDF\n')));
  });

  testWidgets('a download that fails says so, and the chip can try again', (tester) async {
    await _start(tester);
    h.keychain.failure = Exception('keychain locked');
    await _tap(tester, _chip('note.txt'));
    expect(find.textContaining('Scaricamento non riuscito', findRichText: true), findsOneWidget);
    h.keychain.failure = null;
    await _tap(tester, _chip('note.txt'));
    expect(h.links.opened, hasLength(1));
  });

  testWidgets('a body stored before attachments were known is downloaded again on expanding', (tester) async {
    await _start(tester);
    // m0: an older, read message whose body came from database v8 (attachments unknown).
    gmail
      ..attach('m0', 'vecchio.pdf', List.filled(10, 1))
      ..deliver(msg('m0', conversationId: 't', isRead: true, date: DateTime.utc(2025, 12)));
    await tester.pumpAndSettle();
    await getIt<MailStore>().saveBody('a1', 'm0', const MessageBody('Corpo di m0', BodyKind.testo, attachments: null));
    await tester.pumpAndSettle();
    expect(find.text('vecchio.pdf'), findsNothing);

    await _tap(tester, find.textContaining('Anteprima', findRichText: true).last);
    expect(find.text('vecchio.pdf'), findsOneWidget);
  });

  testWidgets('Riprova after a failed Salva… saves, it does not open', (tester) async {
    await _start(tester);
    gmail.goOffline();
    await _tap(tester, _in('note.txt', const ValueKey('attachment-more')));
    await _tap(tester, find.text('Salva…'));
    expect(find.textContaining('Offline: allegato non ancora scaricato', findRichText: true), findsOneWidget);
    gmail.goOnline();
    await _tap(tester, _in('note.txt', const ValueKey('attachment-retry')));
    expect(h.saver.saved.single.$2, 'note.txt');
    expect(h.links.opened, isEmpty);
  });

  testWidgets('a download that fails before Salva… is a failed download, not a failed save', (tester) async {
    await _start(tester);
    h.keychain.failure = Exception('keychain locked');
    await _tap(tester, _in('note.txt', const ValueKey('attachment-more')));
    await _tap(tester, find.text('Salva…'));
    expect(find.textContaining('Scaricamento non riuscito', findRichText: true), findsOneWidget);
    h.keychain.failure = null;
    await _tap(tester, _in('note.txt', const ValueKey('attachment-retry')));
    expect(h.saver.saved.single.$2, 'note.txt');
  });

  testWidgets('a Save As that fails says so, and Riprova saves again', (tester) async {
    await _start(tester);
    h.saver.failure = Exception('disk full');
    await _tap(tester, _in('note.txt', const ValueKey('attachment-more')));
    await _tap(tester, find.text('Salva…'));
    expect(find.textContaining('Salvataggio non riuscito', findRichText: true), findsOneWidget);
    h.saver.failure = null;
    await _tap(tester, _in('note.txt', const ValueKey('attachment-retry')));
    expect(h.saver.saved.single.$2, 'note.txt');
    expect(find.textContaining('Salvataggio non riuscito', findRichText: true), findsNothing);
  });

  testWidgets('an attachment without a name is «Allegato senza nome»', (tester) async {
    await _start(tester);
    gmail
      ..attach('m2', '', [1, 2], mimeType: 'application/pdf')
      ..attach('m2', 'Fattura', [3], mimeType: 'application/pdf')
      ..deliver(msg('m2', conversationId: 't2', subject: 'Senza nome'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('row-a1-m2')));
    // Named by its type, so it opens in the right app.
    expect(find.text('Allegato senza nome.pdf'), findsOneWidget);
    expect(find.text('Fattura.pdf'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('attachment-m2-att-')));
    expect(Uri.decodeComponent(h.links.opened.single.pathSegments.last), 'Allegato senza nome.pdf');
  });

  testWidgets('an executable never opens: a warning, and only Salva… (#75)', (tester) async {
    await _startWithExecutables(tester);
    for (final name in ['setup.exe', 'install.command', 'script.sh', 'fattura\u202Efdp.exe']) {
      await _tap(tester, _chip(name));
    }
    expect(h.links.opened, isEmpty);
    expect(gmail.attachmentCalls, isEmpty);
    expect(find.textContaining('Eseguibile', findRichText: true), findsNWidgets(4));
    // The chip shows the name without the bidi override.
    expect(find.text('fatturafdp.exe'), findsOneWidget);
    expect(find.text('fattura\u202Efdp.exe'), findsNothing);

    await _tap(tester, _in('setup.exe', const ValueKey('attachment-more')));
    await _tap(tester, find.text('Salva…'));
    expect(h.saver.saved.single.$2, 'setup.exe');
    expect(h.links.opened, isEmpty);
    await _tap(tester, _in('fattura\u202Efdp.exe', const ValueKey('attachment-more')));
    await _tap(tester, find.text('Salva…'));
    expect(h.saver.saved.last.$2, 'fatturafdp.exe');
    // The others still open.
    await _tap(tester, _chip('Contratto.pdf'));
    expect(h.links.opened.single.pathSegments.last, 'Contratto.pdf');
  });

  testWidgets('an executable: screen readers hear the warning, not a button; the menu by keyboard (#75)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _startWithExecutables(tester);
    expect(
      tester.getSemantics(find.descendant(of: _chip('setup.exe'), matching: find.bySemanticsLabel('setup.exe'))),
      matchesSemantics(
        label: 'setup.exe',
        value: 'Eseguibile: non si apre da Postino. Salvalo solo se ti fidi del mittente',
      ),
    );
    handle.dispose();

    final more = _in('setup.exe', const ValueKey('attachment-more'));
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null &&
          find.ancestor(of: find.byElementPredicate((e) => e == focused), matching: more).evaluate().isNotEmpty) {
        return;
      }
    }
    fail('Tab never reached the menu of setup.exe');
  });

  testWidgets('the executable warning is selectable and copiable (#75)', (tester) async {
    await _startWithExecutables(tester);
    await tester.tap(find.text('Ti mando il contratto'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_clipboard, contains('setup.exe'));
    expect(_clipboard, contains('Eseguibile: non si apre da Postino'));
  });

  // QA saw the menu open on its own after a download and after a cancelled Save As: the window loses and
  // regains focus in both cases (another app, the system sheet). Not reproduced here; pinned all the same.
  Future<void> windowFocusRoundTrip(WidgetTester tester) async {
    for (final direction in ViewFocusDirection.values) {
      for (final state in [ViewFocusState.unfocused, ViewFocusState.focused]) {
        tester.binding.handleViewFocusChanged(
          ViewFocusEvent(viewId: tester.view.viewId, state: state, direction: direction),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Salva…'), findsNothing, reason: '$direction');
    }
  }

  testWidgets('the menu stays closed after a download, when the window regains focus', (tester) async {
    await _start(tester);
    await _tap(tester, _chip('Contratto.pdf'));
    expect(h.links.opened, hasLength(1));
    await windowFocusRoundTrip(tester);
  });

  testWidgets('the menu stays closed while the Save As dialog is open and after its Annulla', (tester) async {
    await _start(tester);
    final dialog = h.saver.dialog = Completer<bool>();
    await _tap(tester, _in('Contratto.pdf', const ValueKey('attachment-more')));
    expect(find.text('Salva…'), findsOneWidget);
    await _tap(tester, find.text('Salva…'));
    expect(find.text('Salva…'), findsNothing);
    // The system sheet is up: the window loses and regains focus meanwhile.
    await windowFocusRoundTrip(tester);
    dialog.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Salva…'), findsNothing);
    expect(h.saver.saved, isEmpty);
    await windowFocusRoundTrip(tester);
  });
}
