// PROTOTIPO (#106) — componente proposto per il design system (molecola).
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// A checkbox and its [label] as one row: one Tab stop (the row), Space/Enter toggles,
/// read as «Fatture, casella, selezionata». At least `touch-target-android` high; long labels wrap.
class const PostinoCheckboxTile({
  super.key,
  required final String label,
  required final bool value,
  required final ValueChanged<bool> onChanged,
  final FocusNode? focusNode,
  final bool autofocus = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MergeSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: focusNode,
          autofocus: autofocus,
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
                      child: Text(label, style: PostinoText.label.copyWith(color: c.ink)),
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
