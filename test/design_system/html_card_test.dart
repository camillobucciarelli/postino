// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// PostinoHtmlCard (#47): the cartoncino in dark theme, wide newsletters scaled down, links.

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/domain/safe_html.dart';

import '../support/html_fallback_engine.dart';

Future<void> _pump(WidgetTester tester, Widget card, {double width = 360, ThemeData? theme}) => tester.pumpWidget(
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

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// A GitHub Actions notification: `width:100%` table, a 24px status column.
String _actionsEmail() {
  final rows = [
    for (final j in ['apple', 'android', 'web'])
      '<tr><td style="width:24px"><img src="$_png" width="16" height="16"></td>'
          '<td>CI / $j — Succeeded in 2 minutes and 52 seconds</td>'
          '<td>1 warning</td></tr>',
  ];
  // In a div, as in the real email: a table straight under tight constraints is always equal.
  return '<div><table style="width:100%;border-collapse:collapse">'
      '<tr><th style="width:24px">Status</th><th>Job</th><th>Annotations</th></tr>'
      '${rows.join()}</table></div>';
}

bool _onPaper(WidgetTester tester) => find
    .descendant(
      of: find.byType(PostinoHtmlCard),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == PostinoColors.light.surfaceRaised,
      ),
    )
    .evaluate()
    .isNotEmpty;

/// Anonymized Cerberus-style newsletter: banner header, bordered card, centered banner, footer,
/// all one-column tables with `width="100%"` or `width:100%`.
String _newsletter() =>
    '<html><head><title>Titolo segreto della newsletter</title></head><body>'
    '<table role="presentation" width="100%" style="background:#ddd"><tr><td>'
    '<table role="presentation" width="100%" style="background:#036"><tr>'
    '<td style="padding:8px;color:#fff">Testata</td></tr></table>'
    '<table role="presentation" style="width:100%;border:1px solid #999"><tr>'
    '<td style="padding:8px">Corpo della card</td></tr></table>'
    '<table role="presentation" width="100%" style="margin:0 auto;background:#fc0"><tr>'
    '<td style="padding:8px">Banner</td></tr></table>'
    '<table role="presentation" width="100%"><tr><td>Piede</td></tr></table>'
    '</td></tr></table></body></html>';

void main() {
  // Looks for the body's text and links as widgets.
  setUp(useHtmlFallbackEngine);
  testWidgets('in dark theme the HTML sits on the light cartoncino', (tester) async {
    final card = PostinoHtmlCard(html: '<p>Ciao</p>', onTapUrl: (_) {});
    await _pump(tester, card, theme: PostinoTheme.dark());
    expect(find.text('Ciao', findRichText: true), findsOneWidget);
    expect(_onPaper(tester), isTrue);

    await _pump(tester, card);
    await tester.pumpAndSettle(); // the theme change animates
    expect(_onPaper(tester), isFalse);
  });

  testWidgets('a 600px newsletter in a 360px column scales down: no overflow, no sideways scroll', (tester) async {
    final row = [for (var i = 0; i < 3; i++) '<td width="200">Colonna $i</td>'];
    await _pump(
      tester,
      PostinoHtmlCard(html: '<table width="600"><tr>${row.join()}</tr></table>', contentWidth: 600, onTapUrl: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PostinoHtmlCard)).width, 360);
    final fitted = find.byType(FittedBox);
    expect(fitted, findsOneWidget);
    expect(tester.getSize(fitted).width, lessThanOrEqualTo(360));
    expect(tester.getRect(find.text('Colonna 2', findRichText: true)).right, lessThanOrEqualTo(360));
    // fwfh may wrap a table in a horizontal scroll view: it must have nothing to scroll.
    for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
      if (s.widget.axisDirection == AxisDirection.right) {
        expect(s.position.maxScrollExtent, 0);
      }
    }
  });

  testWidgets('a tap on a link gives its real URL, mailto: too', (tester) async {
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

  testWidgets('a GitHub Actions table: «Status» on one line, columns by content', (tester) async {
    final card = PostinoHtmlCard(html: prepareHtml(_actionsEmail(), allowRemote: false).html, onTapUrl: (_) {});
    for (final w in [600.0, 520.0]) {
      await _pump(tester, card, width: w);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final status = find.text('Status', findRichText: true);
      expect(tester.getSize(status).height, lessThan(30));
      final job = find.textContaining('Succeeded', findRichText: true).first;
      expect(tester.getSize(job).width, greaterThan(w / 3));
      expect(tester.getSize(job).height, lessThan(60)); // at most 2 lines
    }
  });

  testWidgets('a crowded table with inline images and code: cells measurable, no exception storm', (tester) async {
    final words = 'parola lunga ' * 30;
    // In a div, so fwfh's table measures each cell's min intrinsic width: that asks every
    // inline widget for a dry baseline, which an image, an icon or a scroll view cannot give.
    final html =
        '<div><table><tr>'
        '<td><img src="$_png" width="16" height="16"> <img alt="logo"> '
        '<span style="display:inline-block"><pre>codice</pre></span> $words</td>'
        '<td>$words</td></tr></table></div>';
    await _pump(
      tester,
      PostinoHtmlCard(html: prepareHtml(html, allowRemote: false).html, onTapUrl: (_) {}),
      width: 800,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // What fwfh's table does: a failure there is swallowed but leaves debug flags set, and
    // then every paint and hover throws (the lag on opening a message).
    for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
      p.getMinIntrinsicWidth(double.infinity);
    }
    for (final b in tester.allRenderObjects.whereType<RenderBox>()) {
      expect(() => b.size, returnsNormally);
    }
  });

  testWidgets('a card table has its border outside the padding, rounded (#63)', (tester) async {
    const html =
        '<table width="100%" style="padding:16px;border:1px solid #F0F1F2;'
        'border-radius:16px"><tr><td>Offerta</td></tr></table>';
    await _pump(tester, PostinoHtmlCard(html: prepareHtml(html, allowRemote: false).html, onTapUrl: (_) {}));
    await tester.pumpAndSettle();
    final box = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(16) &&
          (w.decoration as BoxDecoration).border != null,
    );
    expect(box, findsOneWidget);
    // The text is at least 16px (padding) + 1px (border) in from the box.
    expect(
      tester.getTopLeft(find.textContaining('Offerta', findRichText: true)).dx - tester.getTopLeft(box).dx,
      greaterThanOrEqualTo(17),
    );
  });

  group('<img srcset> without src', () {
    const srcset = '<img srcset="https://shop.example/logo.png 1x" alt="logo">';
    final placeholder = find.byWidgetPredicate((w) => w is PostinoIcon && w.icon == PostinoIcons.image);

    testWidgets('allowed: the image is built from its candidate, no placeholder', (tester) async {
      await _pump(
        tester,
        PostinoHtmlCard(html: prepareHtml(srcset, allowRemote: true).html, allowRemoteImages: true, onTapUrl: (_) {}),
      );
      await tester.pump();
      expect(placeholder, findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == 'https://shop.example/logo.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets('blocked: the placeholder stays', (tester) async {
      await _pump(tester, PostinoHtmlCard(html: prepareHtml(srcset, allowRemote: false).html, onTapUrl: (_) {}));
      expect(placeholder, findsOneWidget);
    });
  });

  testWidgets('a one-column newsletter fills the column, the title stays hidden (#63)', (tester) async {
    final safe = prepareHtml(_newsletter(), allowRemote: false);
    await _pump(tester, PostinoHtmlCard(html: safe.html, contentWidth: safe.width, onTapUrl: (_) {}), width: 400);
    await tester.pumpAndSettle();
    expect(find.textContaining('Titolo segreto', findRichText: true), findsNothing);
    final card = tester.getRect(find.byType(PostinoHtmlCard));
    for (final label in ['Testata', 'Corpo della card', 'Banner', 'Piede']) {
      final text = tester.getRect(find.textContaining(label, findRichText: true).first);
      expect(text.left, lessThan(card.left + 40), reason: label);
    }
    // The header and banner backgrounds reach the card's width, not their text's.
    final boxes = find.descendant(
      of: find.byType(PostinoHtmlCard),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).color == const Color(0xFF003366) ||
                (w.decoration as BoxDecoration).color == const Color(0xFFFFCC00)),
      ),
    );
    expect(boxes, findsNWidgets(2));
    for (final b in boxes.evaluate()) {
      final w = tester.getSize(find.byWidget(b.widget)).width;
      expect(w, greaterThan(card.width - 40));
    }
  });
}
