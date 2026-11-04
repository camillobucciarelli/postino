import 'package:flutter/material.dart';

import '../tokens/postino_tokens.dart';

/// One pane on the phone: [appBar], the [drawer] behind it, [banners] on top of the [body], [fab] over it.
class PostinoSinglePaneLayout extends StatelessWidget {
  /// Crea il layout a un solo pannello, per il telefono.
  const PostinoSinglePaneLayout({
    super.key,
    required this.appBar,
    required this.body,
    this.drawer,
    this.banners = const [],
    this.fab,
  });

  /// Barra superiore, che sta nel corpo e prende l'altezza del suo contenuto.
  final Widget appBar;

  /// Contenuto principale, sotto i banner.
  final Widget body;

  /// Drawer di navigazione facoltativo.
  final Widget? drawer;

  /// Banner mostrati sopra il contenuto, con il margine laterale.
  final List<Widget> banners;

  /// Pulsante di azione flottante facoltativo.
  final Widget? fab;

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
        Expanded(child: body),
      ],
    ),
  );
}
