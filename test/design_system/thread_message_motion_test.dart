// PostinoThreadMessage (#283): the details and the quote open and close with a fade (duration-thread-expand), a
// notice leaves fading and closing (duration-snackbar); what the first build shows is just there; reduced motion is
// instant. A notice on its way out is not read nor reachable.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/design_system/molecules/postino_quote_toggle.dart';

Widget _message({bool blocked = false, bool reduced = false, VoidCallback? onShow}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: SingleChildScrollView(
        child: PostinoThreadMessage(
          sender: 'Ada Okafor',
          time: '09:42',
          preview: 'Sì',
          recipients: 'a me',
          details: const [PostinoMessageDetail('Da', 'ada@example.com')],
          notices: [
            if (blocked)
              PostinoBanner(
                tone: PostinoBannerTone.info,
                title: 'Immagini bloccate',
                spaced: false,
                actionLabel: 'Mostra immagini',
                onAction: onShow,
              ),
          ],
          expanded: true,
          onToggle: () {},
          body: const PostinoMessageBody(text: 'Ciao'),
          quote: const PostinoMessageBody(text: '> Ti va una cena?', quiet: true),
          quoteLabel: 'Mostra testo citato',
        ),
      ),
    ),
  ),
);

/// The opacity of the reveal holding [f], 1 when none is fading.
double _opacity(WidgetTester tester, Finder f) => tester
    .widgetList<FadeTransition>(find.ancestor(of: f, matching: find.byType(FadeTransition)))
    .fold(1, (o, t) => o * t.opacity.value);

void main() {
  final half = PostinoMotion.threadExpand ~/ 2;

  testWidgets('the details open fading in and close fading out', (tester) async {
    await tester.pumpWidget(_message());
    await tester.tap(find.text('a me'));
    await tester.pump();
    await tester.pump(half);
    expect(_opacity(tester, find.text('ada@example.com')), inExclusiveRange(0, 1));
    await tester.pump(half);
    await tester.pump();
    expect(_opacity(tester, find.text('ada@example.com')), 1);

    await tester.tap(find.text('a me'));
    await tester.pump();
    await tester.pump(half);
    expect(find.text('ada@example.com'), findsOneWidget, reason: 'still drawn while it closes');
    expect(_opacity(tester, find.text('ada@example.com')), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('ada@example.com'), findsNothing);
  });

  testWidgets('the quote opens fading in; «…» keeps the focus', (tester) async {
    await tester.pumpWidget(_message());
    // The focus inside the toggle's InkWell.
    final inner = find.descendant(of: find.byKey(const ValueKey('quote-toggle')), matching: find.byType(PostinoIcon));
    Focus.of(tester.element(inner)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(half);
    expect(_opacity(tester, find.text('> Ti va una cena?')), inExclusiveRange(0, 1));
    expect(Focus.of(tester.element(inner)).hasFocus, isTrue);
    await tester.pumpAndSettle();
    expect(_opacity(tester, find.text('> Ti va una cena?')), 1);
    expect(Focus.of(tester.element(inner)).hasFocus, isTrue);
  });

  testWidgets('the notice of blocked images is just there at first, then leaves fading, out of reach', (tester) async {
    final handle = tester.ensureSemantics();
    var shown = 0;
    await tester.pumpWidget(_message(blocked: true, onShow: () => shown++));
    expect(_opacity(tester, find.text('Immagini bloccate')), 1);
    expect(tester.hasRunningAnimations, isFalse);
    final body = tester.getTopLeft(find.text('Ciao')).dy;

    await tester.pumpWidget(_message());
    await tester.pump(PostinoMotion.snackbar ~/ 2);
    expect(find.text('Immagini bloccate'), findsOneWidget);
    expect(_opacity(tester, find.text('Immagini bloccate')), inExclusiveRange(0, 1));
    expect(find.semantics.byLabel('Immagini bloccate'), findsNothing);
    await tester.tap(find.text('Mostra immagini'), warnIfMissed: false);
    expect(shown, 0);
    final moving = tester.getTopLeft(find.text('Ciao')).dy;
    expect(moving, lessThan(body), reason: 'the body moves up bit by bit');
    await tester.pumpAndSettle();
    expect(find.text('Immagini bloccate'), findsNothing);
    expect(tester.getTopLeft(find.text('Ciao')).dy, lessThan(moving));
    handle.dispose();
  });

  testWidgets('with reduced motion details, quote and notice change at once', (tester) async {
    await tester.pumpWidget(_message(blocked: true, reduced: true));
    await tester.tap(find.text('a me'));
    await tester.pump();
    expect(_opacity(tester, find.text('ada@example.com')), 1);
    await tester.tap(find.byType(PostinoQuoteToggle));
    await tester.pump();
    expect(_opacity(tester, find.text('> Ti va una cena?')), 1);
    await tester.pumpWidget(_message(reduced: true));
    await tester.pump();
    expect(find.text('Immagini bloccate'), findsNothing);
  });
}
