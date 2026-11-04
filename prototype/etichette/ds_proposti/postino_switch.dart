// PROTOTIPO (#106) — componente proposto per il design system (atomo).
import 'package:flutter/material.dart';

/// An on/off switch colored by the theme's `switchTheme` (switch-track-*, switch-thumb-*).
/// Exposes `toggled`; [label] names it when it stands alone (inside a PostinoSettingsItem the row names it).
/// [focusable] false when a row around it is the focus stop.
class const PostinoSwitch({
  super.key,
  required final bool value,
  required final ValueChanged<bool> onChanged,
  final String? label,
  final bool focusable = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Switch(value: value, onChanged: onChanged);
    final w = focusable ? s : ExcludeFocus(child: s);
    return label == null ? w : Semantics(label: label, child: w);
  }
}
