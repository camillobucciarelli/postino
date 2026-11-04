import 'package:flutter/material.dart';

import '../atoms/postino_focus_ring.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One setting that is on or off: [title], an optional [description] under it, the switch at the end.
/// The whole row is one control (one tab stop, Space/Enter toggles it), read by the screen reader as a switch
/// named by its [title] and [description].
class const PostinoSwitchRow({
  super.key,

  /// Nome dell'impostazione.
  required final String title,

  /// Cosa fa l'impostazione, o perché non è cambiata.
  final String? description,

  /// Se l'impostazione è attiva.
  required final bool value,

  /// Chiamata con il nuovo valore; se nulla la riga è disabilitata.
  required final ValueChanged<bool>? onChanged,
}) extends StatelessWidget {
  /// Crea la riga con l'interruttore.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final change = onChanged;
    return MergeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: change == null ? null : () => change(!value),
          child: PostinoFocusRing(
            inset: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: PostinoSpacing.s3),
                child: Row(
                  spacing: PostinoSpacing.s4,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: PostinoSpacing.s1,
                        children: [
                          Text(title, style: PostinoText.label.copyWith(color: change == null ? c.inkDisabled : c.ink)),
                          if (description case final d?) Text(d, style: PostinoText.meta.copyWith(color: c.inkSubtle)),
                        ],
                      ),
                    ),
                    // The row is the control: the switch is not a second tab stop.
                    ExcludeFocus(
                      child: Switch(value: value, onChanged: onChanged),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
