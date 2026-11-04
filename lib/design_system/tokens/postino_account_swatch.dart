// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

/// Le tre tinte di un colore account in un tema.
@immutable
class const PostinoAccountSwatch(this.color, this.subtle, this.onColor) {
  /// Crea la terna di tinte.
  this;

  /// Tinta piena dell'account (badge, avatar).
  final Color color;

  /// Tinta tenue, per sfondi.
  final Color subtle;

  /// Colore del testo sopra la tinta piena.
  final Color onColor;
}
