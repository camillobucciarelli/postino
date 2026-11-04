import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/postino_tokens.dart';

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

  /// Esc from anywhere in the pane (a screen of its own, like the Impostazioni): usually what the back arrow does.
  final VoidCallback? onEscape,
}) extends StatelessWidget {
  /// Crea il layout a un solo pannello, per il telefono.
  this;

  @override
  Widget build(BuildContext context) {
    final escape = onEscape;
    final pane = _pane(context);
    return escape == null
        ? pane
        : CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): escape},
            // Focus inside, so Esc works before anything was clicked.
            child: FocusScope(autofocus: true, child: pane),
          );
  }

  Widget _pane(BuildContext context) => Scaffold(
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
