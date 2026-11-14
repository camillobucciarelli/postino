// PostinoSuggestions (#283): the panel opens and fades in, closes and fades out still showing the last suggestions,
// out of reach while it closes; with reduced motion it is instant.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _items = [(name: 'Maria Rossi', address: 'maria@example.com'), (name: null, address: 'ada@example.com')];

final _focus = FocusNode();

Widget _app(List<PostinoSuggestion> suggestions, {bool reduced = false, ValueChanged<int>? onSelected}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: PostinoSuggestions(
            suggestions: suggestions,
            highlighted: 0,
            onSelected: onSelected ?? (_) {},
            onDismiss: () {},
            countLabel: '${suggestions.length} suggerimenti',
            child: PostinoComposerField(label: 'A', controller: TextEditingController(), focusNode: _focus),
          ),
        ),
      ),
    ),
  ),
);

Finder get _panel => find.ancestor(of: find.text('Maria Rossi'), matching: find.byType(Material)).first;

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.ancestor(of: find.text('Maria Rossi'), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

void main() {
  final half = PostinoMotion.state ~/ 2;

  testWidgets('open from the start: just there', (tester) async {
    await tester.pumpWidget(_app(_items));
    await tester.pump();
    expect(_opacity(tester), 1);
    expect(tester.widget<SizeTransition>(find.byType(SizeTransition)).sizeFactor.value, 1);
  });

  testWidgets('it opens: half way partly faded and partly open, then whole', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    expect(find.text('Maria Rossi'), findsNothing);
    await tester.pumpWidget(_app(_items));
    await tester.pump(half);
    final k = PostinoMotion.standardDecelerate.transform(0.5);
    expect(_opacity(tester), closeTo(k, 0.05));
    final full = tester.getSize(_panel).height;
    await tester.pump(half);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(tester.getSize(_panel).height, greaterThan(full));
  });

  testWidgets('it closes with the last suggestions, which take no taps and are not read', (tester) async {
    final handle = tester.ensureSemantics();
    int? chosen;
    await tester.pumpWidget(_app(_items, onSelected: (i) => chosen = i));
    await tester.pump();
    await tester.pumpWidget(_app(const [], onSelected: (i) => chosen = i));
    await tester.pump(half);
    expect(find.text('Maria Rossi'), findsOneWidget);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(find.semantics.byLabel(RegExp('Maria Rossi')), findsNothing);
    await tester.tap(find.text('Maria Rossi'), warnIfMissed: false);
    expect(chosen, isNull);
    await tester.pump(half);
    await tester.pumpAndSettle();
    expect(find.text('Maria Rossi'), findsNothing);
    handle.dispose();
  });

  testWidgets('a shorter list: the height follows it, at once with reduced motion', (tester) async {
    double height() => tester.getSize(find.byType(SingleChildScrollView)).height;
    await tester.pumpWidget(_app(_items));
    await tester.pump();
    final two = height();
    await tester.pumpWidget(_app(_items.take(1).toList()));
    await tester.pump();
    Size sized() => tester.getSize(find.byType(AnimatedSize));
    expect(sized().height, two, reason: 'the new height is not there at once');
    await tester.pump(half);
    final mid = sized().height;
    await tester.pumpAndSettle();
    final one = sized().height;
    expect(one, lessThan(two));
    expect(mid, inExclusiveRange(one, two));

    await tester.pumpWidget(_app(_items, reduced: true));
    await tester.pump();
    await tester.pumpWidget(_app(_items.take(1).toList(), reduced: true));
    await tester.pump();
    expect(find.byType(AnimatedSize), findsNothing);
    expect(height(), lessThan(two));
  });

  testWidgets('with reduced motion it opens and closes at once', (tester) async {
    await tester.pumpWidget(_app(const [], reduced: true));
    await tester.pump();
    await tester.pumpWidget(_app(_items, reduced: true));
    await tester.pump();
    expect(_opacity(tester), 1);
    await tester.pumpWidget(_app(const [], reduced: true));
    await tester.pump();
    expect(find.text('Maria Rossi'), findsNothing);
  });
}
