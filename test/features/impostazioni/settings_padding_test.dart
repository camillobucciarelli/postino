// The padding of every page of the Impostazioni, on the Mac and on the phone (#312): the same column, the headings in
// line with the rows' text, the rows of a section touching, the same gap under the intro.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

const _desktop = Size(1280, 800);
const _phone = Size(400, 800);

final _rows = find.byWidgetPredicate((w) => w is PostinoSettingsItem || w is PostinoSwitchRow || w is PostinoChoiceRow);

/// The first Text in [of]: a row's title, a section's heading.
Rect _text(WidgetTester tester, Finder of) =>
    tester.getRect(find.descendant(of: of, matching: find.byType(Text)).first);

/// The app at [size] with a status bar (or the Mac's titlebar) of 28, on the Impostazioni.
Future<void> _start(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 28);
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  h.launchAtLogin.supported = true;
  h.updater.supported = true;
  await h.addAccount('a1');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.impostazioni.path));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String path) async {
  unawaited(Routefly.navigate(path));
  await tester.pumpAndSettle();
}

/// The column every page shares: a side margin of space-4 on the phone, space-6 from the tablet up, centred at most
/// `reading-max-width`.
(double, double) _column(Size size) {
  if (size.width < PostinoSize.breakpointMedium) return (PostinoSpacing.s4, size.width - PostinoSpacing.s4);
  final extra = (size.width - PostinoSize.readingMaxWidth) / 2;
  return (extra + PostinoSpacing.s6, size.width - extra - PostinoSpacing.s6);
}

void _expectColumn(WidgetTester tester, Size size, String page) {
  final (left, right) = _column(size);
  final rows = _rows.evaluate().toList();
  expect(rows, isNotEmpty, reason: page);
  for (var i = 0; i < rows.length; i++) {
    final row = tester.getRect(_rows.at(i));
    expect((row.left, row.right), (left, right), reason: '$page: row $i in the column');
  }
  final text = _text(tester, _rows.first).left;
  expect(text, left + PostinoSpacing.s4, reason: '$page: the rows inset their text by space-4');
  final sections = find.byType(PostinoSettingsSection);
  for (var i = 0; i < sections.evaluate().length; i++) {
    expect(_text(tester, sections.at(i)).left, text, reason: '$page: heading $i in line with the rows');
    final inSection = find.descendant(of: sections.at(i), matching: _rows);
    for (var j = 1; j < inSection.evaluate().length; j++) {
      expect(
        tester.getRect(inSection.at(j)).top,
        tester.getRect(inSection.at(j - 1)).bottom,
        reason: '$page: section $i, rows ${j - 1} and $j touch, as in a list',
      );
    }
  }
}

void main() {
  for (final size in [_desktop, _phone]) {
    group('$size', () {
      testWidgets('the Impostazioni: one column, headings and notes in line with the rows', (tester) async {
        await _start(tester, size);
        _expectColumn(tester, size, 'index');
        // The note of the Sincronizzazione is the rows' text, not the margin.
        expect(tester.getRect(find.textContaining('Le Impostazioni di Postino')).left, _text(tester, _rows.first).left);
      });

      testWidgets('the Impostazioni del dispositivo: the same column, under the bar by space-4', (tester) async {
        await _start(tester, size);
        await _open(tester, routePaths.impostazioni.dispositivo);
        _expectColumn(tester, size, 'device');
        // Both headings of the Azioni of a notification are built, so both are measured.
        expect(find.byType(PostinoSettingsSection), findsNWidgets(2));
        final bar = tester.getRect(find.byType(PostinoAppBar));
        expect(tester.getRect(_rows.first).top, bar.bottom + PostinoSpacing.s4);
      });

      testWidgets('Scorrimento and Etichette automatiche: the same column and gap under the intro', (tester) async {
        await _start(tester, size);
        await _open(tester, routePaths.impostazioni.scorrimento);
        _expectColumn(tester, size, 'swipe');
        final swipeGap =
            _text(tester, find.byType(PostinoSettingsSection).first).top -
            tester.getRect(find.textContaining('Scorrendo una riga')).bottom;

        await _open(tester, routePaths.impostazioni.$accountId.etichette.changes({'accountId': 'a1'}));
        _expectColumn(tester, size, 'etichette');
        final labelsGap =
            _text(tester, find.byType(PostinoSettingsSection).first).top -
            tester.getRect(find.textContaining('Un modello che gira')).bottom;
        expect(labelsGap, swipeGap, reason: 'with no banner, the intro sits as far from the first heading');
        expect(
          tester.getRect(find.textContaining('Un modello che gira')).left,
          _text(tester, _rows.first).left,
          reason: 'the intro in line with the rows',
        );
      });
    });
  }
}
