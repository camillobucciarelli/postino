// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../organisms/postino_app_bar.dart';

/// A full-screen page over the list: the bar with `arrow-left` ([onBack], Esc too) and [title] over a [subtitle],
/// then [child] filling the rest. For a content that is not a list, like «Vedi originale».
class const PostinoDetailPage({
  super.key,

  /// Titolo della pagina.
  required final String title,

  /// Chiamata dalla freccia indietro e da Esc.
  required final VoidCallback onBack,

  /// Il contenuto, a tutto schermo sotto la barra.
  required final Widget child,

  /// Sottotitolo facoltativo, per esempio l'oggetto del messaggio.
  final String? subtitle,
}) extends StatelessWidget {
  /// Crea la pagina.
  this;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): onBack},
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostinoAppBar(title: title, subtitle: subtitle, onBack: onBack),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
