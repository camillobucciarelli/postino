// The app bar at 200% in a narrow column: a title with the Account's mark wraps (and the bar grows), it is not
// laid out on one line wider than its room. Material's AppBar gives its title `softWrap: false` and a text scale
// of at most 1.34, so the bar has to undo both.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void main() {
  for (final width in [300.0, 328.0, 360.0]) {
    for (final back in [true, false]) {
      testWidgets('title with Account mark wraps at 200% in $width (back: $back)', (tester) async {
        tester.view
          ..physicalSize = const Size(720, 2400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: PostinoTheme.light(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: PostinoSinglePaneLayout(
                      appBar: PostinoAppBar(
                        title: 'Etichette automatiche',
                        subtitle: 'Impostazioni · Lavoro',
                        account: (color: PostinoAccountColor.sky, initial: 'L'),
                        onBack: back ? () {} : null,
                      ),
                      body: const SizedBox(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final text in ['Etichette automatiche', 'Impostazioni · Lavoro']) {
          final p = tester.renderObject<RenderParagraph>(find.text(text));
          // Text at 200%, not at the 1.34 Material clamps the app bar title to.
          expect(p.textScaler.scale(10), 20, reason: text);
          // Wider than its room means several lines, never one line spilling out.
          if (p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5) {
            expect(
              p.size.height,
              greaterThan(p.getFullHeightForCaret(const TextPosition(offset: 0)) * 1.5),
              reason: text,
            );
          }
        }
        // The bar grew around the wrapped lines.
        final bar = tester.getRect(find.byType(AppBar));
        expect(tester.getRect(find.text('Impostazioni · Lavoro')).bottom, lessThanOrEqualTo(bar.bottom));
      });
    }
  }

  // The composer's bar: back, then Send and Close at the end take room from the title.
  for (final width in [300.0, 328.0, 360.0]) {
    testWidgets('title with actions wraps and the bar grows at 200% in $width', (tester) async {
      tester.view
        ..physicalSize = const Size(720, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PostinoTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: PostinoSinglePaneLayout(
                    appBar: PostinoAppBar(
                      title: 'Nuovo messaggio',
                      onBack: () {},
                      actions: [
                        PostinoIconButton(icon: PostinoIcons.send, label: 'Invia', onPressed: () {}),
                        PostinoIconButton(icon: PostinoIcons.close, label: 'Chiudi', onPressed: () {}),
                      ],
                    ),
                    body: const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final p = tester.renderObject<RenderParagraph>(find.text('Nuovo messaggio'));
      expect(p.didExceedMaxLines, isFalse);
      final bar = tester.getRect(find.byType(AppBar));
      expect(tester.getRect(find.text('Nuovo messaggio')).bottom, lessThanOrEqualTo(bar.bottom));
    });
  }
}
