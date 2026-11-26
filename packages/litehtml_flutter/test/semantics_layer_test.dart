import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

Widget view(String html, {ValueChanged<String>? onLinkTap}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: LitehtmlView(
      html: html,
      width: 400,
      onLinkTap: onLinkTap,
      errorBuilder: (context, error) => Text('ripiego $error'),
    ),
  ),
);

const _html =
    '<h1>Offerte</h1> '
    '<table role="presentation"><tr><td>Colonna sinistra<br>seconda riga</td><td>Colonna destra</td></tr></table> '
    '<p>Leggi <a href="https://esempio.it/a">le condizioni</a> prima.</p> '
    '<img alt="Logo del negozio" width="20" height="20">';

void main() {
  testWidgets('titoli con livello, paragrafi, celle e immagini sono nodi in ordine di documento', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(view(_html));

    final heading = tester.getSemantics(find.bySemanticsLabel('Offerte'));
    expect(heading, matchesSemantics(label: 'Offerte', isHeader: true));
    expect(heading.getSemanticsData().headingLevel, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Logo del negozio')),
      matchesSemantics(label: 'Logo del negozio', isImage: true),
    );
    // Le tabelle di impaginazione non si annunciano: le celle sono paragrafi.
    expect(find.bySemanticsLabel('Colonna sinistra'), findsOneWidget);

    final root = tester.getSemantics(find.byType(LitehtmlView));
    final labels = <String>[];
    void visit(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      for (final child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
        visit(child);
      }
    }

    visit(root);
    expect(labels, [
      'Offerte',
      // Ordine di documento: la seconda riga della cella sinistra prima della cella destra, che le sta sopra.
      'Colonna sinistra',
      'seconda riga',
      'Colonna destra',
      'Leggi',
      'le condizioni',
      'prima.',
      'Logo del negozio',
    ]);
    semantics.dispose();
  });

  testWidgets('un link è un nodo link con url e azione tap che chiama onLinkTap', (tester) async {
    final semantics = tester.ensureSemantics();
    final tapped = <String>[];
    await tester.pumpWidget(view(_html, onLinkTap: tapped.add));

    final link = tester.getSemantics(find.bySemanticsLabel('le condizioni'));
    expect(
      link,
      matchesSemantics(
        label: 'le condizioni',
        isLink: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(link.getSemanticsData().linkUrl, Uri.parse('https://esempio.it/a'));
    tester.semantics.tap(find.semantics.byLabel('le condizioni'));
    expect(tapped, ['https://esempio.it/a']);
    semantics.dispose();
  });
}
