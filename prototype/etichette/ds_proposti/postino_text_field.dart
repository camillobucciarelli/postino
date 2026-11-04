// PROTOTIPO (#106) — componente proposto per il design system (atomo).
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// A text field on the theme's `inputDecorationTheme` (input-bg, input-border*): [label] floats and names it,
/// [helper] in caption, [error] replaces the helper in `danger`, as a live region so screen readers announce it.
/// [multiline] grows from three lines. Helper and error wrap, never truncate.
class const PostinoTextField({
  super.key,
  required final String label,
  final TextEditingController? controller,
  final FocusNode? focusNode,
  final String? helper,
  final String? error,
  final PostinoIconData? icon,
  final bool multiline = false,
  final bool autofocus = false,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? null : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.done,
      style: PostinoText.preview.copyWith(color: c.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: PostinoText.preview.copyWith(color: c.inkMuted),
        helperText: helper,
        helperMaxLines: 6,
        helperStyle: PostinoText.caption.copyWith(color: c.inkMuted),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
                child: PostinoIcon(icon!, color: c.inkMuted),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: PostinoSize.controlMd),
        error: error == null
            ? null
            : Semantics(
                liveRegion: true,
                child: Text(error!, style: PostinoText.caption.copyWith(color: c.danger)),
              ),
      ),
    );
  }
}
