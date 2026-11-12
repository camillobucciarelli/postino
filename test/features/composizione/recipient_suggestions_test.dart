// Contatti in the composition (#216): typing in A suggests from the synced mail; Up/Down/Enter choose, Esc closes
// the list and only the second one the composition, Tab still goes to Cc, Cmd+Enter still sends; announced to
// screen readers without taking the focus from the field.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _id = 'a1';

late Harness h;
late FakeMailProvider gmail;

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = await h.addAccount(_id);
  final now = h.clock.now();
  gmail
    ..deliver(msg('m1', from: 'maria@example.com', fromName: 'Maria Rossi', date: now))
    ..deliver(
      msg('m2', from: 'marco@example.com', fromName: 'Marco Bianchi', date: now.subtract(const Duration(days: 90))),
    )
    ..deliver(msg('m3', from: 'luca@example.com', fromName: 'Luca Verdi', date: now));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await _settle(tester);
  await tester.tap(find.text('Scrivi'));
  await _settle(tester);
}

void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  final semantics = tester.ensureSemantics();
  try {
    await body(tester);
    // A Bozza still waiting for its 5 s would hang the next test's database close: let it go now.
    h.clock.advance(const Duration(seconds: 5));
    await _settle(tester);
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
});

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is PostinoComposerField && w.label == label),
  matching: find.byType(TextField),
);

String _text(WidgetTester tester, String label) => tester.widget<TextField>(_field(label)).controller!.text;

/// Frames plus the event queue: the database answers between frames.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(pumpEventQueue);
  await tester.pumpAndSettle();
}

/// Types [text] in A as the keyboard would, firing onChanged.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field('A'), text);
  await _settle(tester);
}

Finder get _list => find.byType(PostinoSuggestions);

/// [text] inside the suggestions (the list behind has the same names).
Finder _s(String text) => find.descendant(of: _list, matching: find.text(text));
bool _open(WidgetTester tester) => tester.widget<PostinoSuggestions>(_list.first).suggestions.isNotEmpty;

void main() {
  _onMac('«mar» suggests the Contatti, best first; Enter writes the first and the next address suggests again', (
    tester,
  ) async {
    await _start(tester);
    await _type(tester, 'mar');
    expect(_s('Maria Rossi'), findsOneWidget);
    expect(_s('marco@example.com'), findsOneWidget);
    expect(_s('Luca Verdi'), findsNothing);
    expect(tester.getTopLeft(_s('Maria Rossi')).dy, lessThan(tester.getTopLeft(_s('Marco Bianchi')).dy));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_text(tester, 'A'), 'Maria Rossi <maria@example.com>, ');
    expect(_open(tester), isFalse);

    await _type(tester, '${_text(tester, 'A')}lu');
    expect(_s('Luca Verdi'), findsOneWidget);
  });

  _onMac('Down then Enter chooses the second; Up wraps to the last', (tester) async {
    await _start(tester);
    await _type(tester, 'mar');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_text(tester, 'A'), 'Marco Bianchi <marco@example.com>, ');

    await _type(tester, 'mar');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_text(tester, 'A'), 'Marco Bianchi <marco@example.com>, ');
  });

  _onMac('a tap chooses a suggestion and the focus stays in the field', (tester) async {
    await _start(tester);
    await _type(tester, 'lu');
    await tester.tap(_s('Luca Verdi'));
    await _settle(tester);
    expect(_text(tester, 'A'), 'Luca Verdi <luca@example.com>, ');
    expect(tester.widget<TextField>(_field('A')).focusNode!.hasFocus, isTrue);
  });

  _onMac('Esc closes the list, not the composition; a second Esc closes the composition', (tester) async {
    await _start(tester);
    await _type(tester, 'mar');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(_open(tester), isFalse);
    expect(find.byType(PostinoComposerField), findsWidgets);
    expect(_text(tester, 'A'), 'mar');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byType(PostinoComposerField), findsNothing);
  });

  _onMac('Tab goes to Cc with the list open, and closes it', (tester) async {
    await _start(tester);
    await _type(tester, 'mar');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _settle(tester);
    expect(tester.widget<TextField>(_field('Cc')).focusNode!.hasFocus, isTrue);
    expect(_open(tester), isFalse);
    expect(_text(tester, 'A'), 'mar');
  });

  _onMac('Cmd+Enter sends with the list open; the Bozza had the chosen address', (tester) async {
    await _start(tester);
    await _type(tester, 'mar');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    h.clock.advance(const Duration(seconds: 5));
    await _settle(tester);
    expect(gmail.drafts.values.single.to, ['Maria Rossi <maria@example.com>']);

    await _type(tester, '${_text(tester, 'A')}lu');
    expect(_open(tester), isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await _settle(tester);
    expect(find.byType(PostinoComposerField), findsNothing);
  });

  _onMac('the field says how many suggestions; each reads «Name, address»; moving announces the highlighted one', (
    tester,
  ) async {
    await _start(tester);
    tester.takeAnnouncements();
    await _type(tester, 'mar');
    expect(tester.getSemantics(_field('A')), isSemantics(hint: '2 suggerimenti', isTextField: true));
    expect(find.bySemanticsLabel('Maria Rossi, maria@example.com'), findsOneWidget);
    expect(tester.takeAnnouncements().map((a) => a.message), ['2 suggerimenti']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.takeAnnouncements().map((a) => a.message), ['Marco Bianchi, marco@example.com']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Marco Bianchi, marco@example.com')),
      isSemantics(label: 'Marco Bianchi, marco@example.com', isButton: true, isSelected: true, hasTapAction: true),
    );
  });
}
