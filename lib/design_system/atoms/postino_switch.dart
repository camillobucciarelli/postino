// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// An on/off switch, colored by the theme's `switchTheme` (`switch-track-*`, `switch-thumb-*`); it exposes `toggled`.
/// [label] names it when it stands alone; inside a row that is the control (PostinoSwitchRow) pass
/// [focusable] false, so the row stays the one Tab stop and names it.
class const PostinoSwitch({
  super.key,

  /// Se l'interruttore è attivo.
  required final bool value,

  /// Chiamata con il nuovo valore; se nulla l'interruttore è disabilitato.
  required final ValueChanged<bool>? onChanged,

  /// Nome per lo screen reader, quando l'interruttore sta da solo.
  final String? label,

  /// Se è un punto di Tab; falso dentro una riga che fa da controllo.
  final bool focusable = true,
}) extends StatelessWidget {
  /// Crea l'interruttore.
  this;

  @override
  Widget build(BuildContext context) {
    final s = Switch(value: value, onChanged: onChanged);
    final w = focusable ? s : ExcludeFocus(child: s);
    final l = label;
    return l == null
        ? w
        : MergeSemantics(
            child: Semantics(label: l, child: w),
          );
  }
}
