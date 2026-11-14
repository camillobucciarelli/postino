// PostinoAttachmentChip (#283): the download bar glides to a new progress (linear) and fades away at the end;
// downloading, failed and at rest fade one into the next, the leaving buttons out of reach; the first build is just
// there; reduced motion is instant.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _chip({double? progress, String? error, bool reduced = false, VoidCallback? onCancel}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Center(
        child: PostinoAttachmentChip(
          name: 'Contratto.pdf',
          size: '1,2 MB',
          onOpen: () {},
          progress: progress,
          progressLabel: progress == null ? null : '${(progress * 100).round()}%',
          cancelLabel: 'Annulla',
          onCancel: onCancel ?? () {},
          error: error,
          retryLabel: 'Riprova',
        ),
      ),
    ),
  ),
);

const _bar = ValueKey('attachment-progress');

double _width(WidgetTester tester) => tester.widget<FractionallySizedBox>(find.byKey(_bar)).widthFactor!;

double _opacity(WidgetTester tester, Finder f) => tester
    .widgetList<FadeTransition>(find.ancestor(of: f, matching: find.byType(FadeTransition)))
    .fold(1, (o, t) => o * t.opacity.value);

void main() {
  final half = PostinoMotion.state ~/ 2;

  testWidgets('the first progress is just there; a new one is reached linearly', (tester) async {
    await tester.pumpWidget(_chip(progress: 0.2));
    expect(_width(tester), 0.2);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_chip(progress: 0.6));
    await tester.pump(half);
    expect(_width(tester), closeTo(0.4, 0.01));
    await tester.pump(half);
    expect(_width(tester), closeTo(0.6, 1e-9));
  });

  testWidgets('at the end the bar fades away and Annulla fades into the rest, out of reach', (tester) async {
    final handle = tester.ensureSemantics();
    var cancels = 0;
    await tester.pumpWidget(_chip(progress: 0.9, onCancel: () => cancels++));
    await tester.pumpWidget(_chip());
    await tester.pump(half);
    expect(find.byKey(_bar), findsOneWidget, reason: 'still drawn while it fades');
    final fade = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(_bar), matching: find.byType(AnimatedOpacity)),
    );
    expect(fade.opacity, 0);
    final cancel = find.byKey(const ValueKey('attachment-cancel'));
    expect(_opacity(tester, cancel), inExclusiveRange(0, 1));
    expect(find.semantics.byLabel('Annulla'), findsNothing);
    expect(Focus.of(tester.element(cancel)).canRequestFocus, isFalse);
    await tester.tap(cancel, warnIfMissed: false);
    expect(cancels, 0);
    expect(_opacity(tester, find.text('1,2 MB')), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.byKey(_bar), findsNothing);
    expect(cancel, findsNothing);
    expect(_opacity(tester, find.text('1,2 MB')), 1);

    // A new download starts its bar from nothing, not from where the last one ended.
    await tester.pumpWidget(_chip(progress: 0.1));
    expect(_width(tester), 0.1);
    handle.dispose();
  });

  testWidgets('a failure fades in its Riprova', (tester) async {
    await tester.pumpWidget(_chip(progress: 0.5));
    await tester.pumpWidget(_chip(error: 'Non scaricato'));
    await tester.pump(half);
    expect(_opacity(tester, find.byKey(const ValueKey('attachment-retry'))), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, find.byKey(const ValueKey('attachment-retry'))), 1);
  });

  testWidgets('with reduced motion bar and buttons change at once', (tester) async {
    await tester.pumpWidget(_chip(progress: 0.2, reduced: true));
    await tester.pumpWidget(_chip(progress: 0.6, reduced: true));
    await tester.pump();
    expect(_width(tester), 0.6);
    await tester.pumpWidget(_chip(reduced: true));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('attachment-cancel')), findsNothing);
    expect(find.byKey(_bar), findsNothing);
  });
}
