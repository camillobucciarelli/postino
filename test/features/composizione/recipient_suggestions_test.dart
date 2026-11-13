// Contatti in the composition (#216): typing in A suggests from the synced mail; Up/Down/Enter choose, Esc closes
// the list and only the second one the composition, Tab still goes to Cc, Cmd+Enter still sends; announced to
// screen readers without taking the focus from the field.
import 'dart:async';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
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
  await tester.pump(const Duration(milliseconds: 200)); // the debounce
  await _settle(tester);
}

Finder get _list => find.byType(PostinoSuggestions);

/// [text] inside the suggestions (the list behind has the same names).
Finder _inList(String text) => find.descendant(of: _list, matching: find.text(text));
bool _open(WidgetTester tester) => tester.widget<PostinoSuggestions>(_list.first).suggestions.isNotEmpty;

void main() {
  _onMac('«mar» suggests the Contatti, best first; Enter writes the first and the next address suggests again', (
    tester,
  ) async {
    await _start(tester);
    await _type(tester, 'mar');
    expect(_inList('Maria Rossi'), findsOneWidget);
    expect(_inList('marco@example.com'), findsOneWidget);
    expect(_inList('Luca Verdi'), findsNothing);
    expect(tester.getTopLeft(_inList('Maria Rossi')).dy, lessThan(tester.getTopLeft(_inList('Marco Bianchi')).dy));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_text(tester, 'A'), 'Maria Rossi <maria@example.com>, ');
    expect(_open(tester), isFalse);

    await _type(tester, '${_text(tester, 'A')}lu');
    expect(_inList('Luca Verdi'), findsOneWidget);
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

  _onMac('Enter right after typing on does not write the suggestion of the previous address', (tester) async {
    await _start(tester);
    await _type(tester, 'mar');
    await tester.enterText(_field('A'), 'lu');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_text(tester, 'A'), 'lu');
    // Nor does a tap on the old list.
    await tester.tap(_inList('Maria Rossi'));
    await tester.pump();
    expect(_text(tester, 'A'), 'lu');
    await tester.pump(const Duration(milliseconds: 200));
    await _settle(tester);
    expect(_inList('Luca Verdi'), findsOneWidget);
  });

  _onMac('the suggestions are for the address the caret is in: first, middle and last', (tester) async {
    await _start(tester);
    Future<void> at(String text, int caret) async {
      await tester.tap(_field('A'));
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: caret),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await _settle(tester);
    }

    await at('mar, lu', 3);
    expect(_inList('Maria Rossi'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_text(tester, 'A'), 'Maria Rossi <maria@example.com>, lu');
    expect(
      tester.widget<TextField>(_field('A')).controller!.selection.baseOffset,
      'Maria Rossi <maria@example.com>, '.length,
    );

    await at('ada@example.com, marc, lu', 'ada@example.com, mar'.length);
    expect(_inList('Marco Bianchi'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_text(tester, 'A'), 'ada@example.com, Marco Bianchi <marco@example.com>, lu');

    await at('mar, lu', 7);
    expect(_inList('Luca Verdi'), findsOneWidget);
    expect(_inList('Maria Rossi'), findsNothing);
    // The caret moved back to «mar» after the list came: the list for «lu» closes, Enter does not write Luca there.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'mar, lu', selection: TextSelection.collapsed(offset: 2)),
    );
    await tester.pump();
    expect(_open(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_text(tester, 'A'), 'mar, lu');
  });

  _onMac('a tap chooses a suggestion and the focus stays in the field', (tester) async {
    await _start(tester);
    await _type(tester, 'lu');
    await tester.tap(_inList('Luca Verdi'));
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
