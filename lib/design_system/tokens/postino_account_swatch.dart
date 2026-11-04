// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

/// Le tre tinte di un colore account in un tema.
@immutable
class PostinoAccountSwatch {
  /// Crea la terna di tinte.
  const PostinoAccountSwatch(this.color, this.subtle, this.onColor);

  /// Tinta piena dell'account (badge, avatar).
  final Color color;

  /// Tinta tenue, per sfondi.
  final Color subtle;

  /// Colore del testo sopra la tinta piena.
  final Color onColor;
}
