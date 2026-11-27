// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_tokens.dart';
import 'postino_below_bar.dart';

/// One pane on the phone: [appBar], the [drawer] behind it, [banners] on top of the [body], [fab] over it.
class const PostinoSinglePaneLayout({
  super.key,

  /// Barra superiore, che sta nel corpo e prende l'altezza del suo contenuto.
  required final Widget appBar,

  /// Contenuto principale, sotto i banner.
  required final Widget body,

  /// Drawer di navigazione facoltativo.
  final Widget? drawer,

  /// Banner mostrati sopra il contenuto, con il margine laterale.
  final List<Widget> banners = const [],

  /// Pulsante di azione flottante facoltativo.
  final Widget? fab,
}) extends StatelessWidget {
  /// Crea il layout a un solo pannello, per il telefono.
  this;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: drawer,
    floatingActionButton: fab,
    // The bar sits in the body, not in `Scaffold.appBar`: it takes the height of its content
    // (56, more with enlarged text) and the rest starts under it, with no fixed cap.
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        appBar,
        Padding(
          // Side margins: space-4 on the phone, space-6 from the tablet up.
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < PostinoSize.breakpointMedium
                ? PostinoSpacing.s4
                : PostinoSpacing.s6,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: banners),
        ),
        // A group of its own: Tab goes through the whole body before the floating [fab] (reading order alone would reach a
        // right-aligned control after a FAB that shares its column).
        Expanded(
          child: FocusTraversalGroup(child: PostinoBelowBar(child: body)),
        ),
      ],
    ),
  );
}
