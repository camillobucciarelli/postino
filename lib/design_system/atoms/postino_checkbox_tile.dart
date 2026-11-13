// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';

/// A checkbox and its [label] as one row: one Tab stop (the row), Space/Enter toggles it,
/// read as one node, «Fatture, casella, selezionata». At least `touch-target-android` high; a long label wraps.
class const PostinoCheckboxTile({
  super.key,

  /// Testo della riga, che dà anche il nome alla casella.
  required final String label,

  /// Se la casella è spuntata.
  required final bool value,

  /// Chiamata con il nuovo valore.
  required final ValueChanged<bool> onChanged,

  /// The row's focus, for a list that moves it with the keyboard.
  final FocusNode? focusNode,

  /// True for one choice out of many: the screen reader announces a radio group, not independent boxes.
  final bool exclusive = false,
}) extends StatelessWidget {
  /// Crea la riga con la casella.
  this;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      inMutuallyExclusiveGroup: exclusive ? true : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: focusNode,
          onTap: () => onChanged(!value),
          child: PostinoFocusRing(
            inset: true,
            borderRadius: BorderRadius.circular(PostinoRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s2),
                child: Row(
                  spacing: PostinoSpacing.s1,
                  children: [
                    // The row is the focus stop; the box only draws and tells the state.
                    ExcludeFocus(
                      child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
                    ),
                    Expanded(
                      // A control's label: out of any selection.
                      child: SelectionContainer.disabled(
                        child: Text(label, style: PostinoText.label.copyWith(color: context.pc.ink)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
