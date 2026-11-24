import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'link_target.dart';
import 'litehtml_content.dart';

/// Semantics e tastiera del contenuto: un nodo per paragrafo, titolo, link e immagine, letti e attraversati con Tab in
/// ordine di documento.
///
/// Le tabelle non hanno nodi propri: nelle email sono quasi sempre di impaginazione, e le loro celle si leggono come
/// paragrafi.
class const LitehtmlSemanticsLayer({
  super.key,
  required final LitehtmlContent content,
  required final ValueChanged<String>? onLinkTap,
  required final Color focusColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        children: [
          for (final (i, node) in content.nodes.indexed)
            Positioned.fromRect(rect: node.bounds, child: _node(node, i.toDouble())),
        ],
      ),
    ),
  );

  Widget _node(ContentNode node, double order) {
    final href = node.href;
    if (href != null) {
      final onTap = onLinkTap;
      return FocusTraversalOrder(
        order: NumericFocusOrder(order),
        child: LinkTarget(
          node: node,
          order: order,
          onTap: onTap == null ? null : () => onTap(href),
          focusColor: focusColor,
        ),
      );
    }
    final level = node.headingLevel;
    return Semantics(
      container: true,
      sortKey: OrdinalSortKey(order),
      label: node.label,
      header: level > 0,
      headingLevel: level > 0 ? level : null,
      image: node.image,
      child: const SizedBox.expand(),
    );
  }
}
