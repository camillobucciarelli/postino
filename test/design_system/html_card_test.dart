// PostinoHtmlCard (#47): the cartoncino in dark theme, wide newsletters scaled down, links.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double width = 360,
  ThemeData? theme,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? PostinoTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ListView(children: [card]),
        ),
      ),
    ),
  ),
);

bool _onPaper(WidgetTester tester) => find
    .descendant(
      of: find.byType(PostinoHtmlCard),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                PostinoColors.light.surfaceRaised,
      ),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('in dark theme the HTML sits on the light cartoncino', (
    tester,
  ) async {
    final card = PostinoHtmlCard(html: '<p>Ciao</p>', onTapUrl: (_) {});
    await _pump(tester, card, theme: PostinoTheme.dark());
    expect(find.text('Ciao', findRichText: true), findsOneWidget);
    expect(_onPaper(tester), isTrue);

    await _pump(tester, card);
    await tester.pumpAndSettle(); // the theme change animates
    expect(_onPaper(tester), isFalse);
  });

  testWidgets(
    'a 600px newsletter in a 360px column scales down: no overflow, no sideways scroll',
    (tester) async {
      final row = [
        for (var i = 0; i < 3; i++) '<td width="200">Colonna $i</td>',
      ];
      await _pump(
        tester,
        PostinoHtmlCard(
          html: '<table width="600"><tr>${row.join()}</tr></table>',
          contentWidth: 600,
          onTapUrl: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PostinoHtmlCard)).width, 360);
      final fitted = find.byType(FittedBox);
      expect(fitted, findsOneWidget);
      expect(tester.getSize(fitted).width, lessThanOrEqualTo(360));
      expect(
        tester.getRect(find.text('Colonna 2', findRichText: true)).right,
        lessThanOrEqualTo(360),
      );
      // fwfh may wrap a table in a horizontal scroll view: it must have nothing to scroll.
      for (final s in tester.stateList<ScrollableState>(
        find.byType(Scrollable),
      )) {
        if (s.widget.axisDirection == AxisDirection.right) {
          expect(s.position.maxScrollExtent, 0);
        }
      }
    },
  );

  testWidgets('a tap on a link gives its real URL, mailto: too', (
    tester,
  ) async {
    final tapped = <String>[];
    await _pump(
      tester,
      PostinoHtmlCard(
        html:
            '<p><a href="https://example.com/vero">www.banca.it</a></p>'
            '<p><a href="mailto:ada@example.com">Scrivi</a></p>',
        onTapUrl: tapped.add,
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('www.banca.it'));
    await tester.tapOnText(find.textRange.ofSubstring('Scrivi'));
    expect(tapped, ['https://example.com/vero', 'mailto:ada@example.com']);
  });
}
