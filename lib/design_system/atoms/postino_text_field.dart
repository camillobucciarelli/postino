import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_icon.dart';

/// A text field on the theme's `inputDecorationTheme` (`input-bg`, `input-border*`). [label] sits above it,
/// wrapping at large text, and names it with [helper] for the screen reader; [error] replaces the helper,
/// in `danger` with `input-border-error`, as a live region so it is announced. [multiline] grows from three lines.
/// With [onSubmitted] Enter keeps the focus in the field (a search that ticks or creates). [obscure] hides the text
/// (a password: read as an obscured field, no suggestions); [readOnly] shows a value the user cannot change.
class const PostinoTextField({
  super.key,

  /// Nome del campo, mostrato sopra.
  required final String label,

  /// Testo del campo.
  final TextEditingController? controller,

  /// Focus del campo.
  final FocusNode? focusNode,

  /// Aiuto sotto il campo; va a capo.
  final String? helper,

  /// Errore sotto il campo, al posto dell'aiuto; annunciato dallo screen reader.
  final String? error,

  /// Icona all'inizio del campo, per esempio la lente di una ricerca.
  final PostinoIconData? icon,

  /// Campo su più righe.
  final bool multiline = false,

  /// Prende il focus quando compare.
  final bool autofocus = false,

  /// Campo oscurato, per una password.
  final bool obscure = false,

  /// Valore mostrato ma non modificabile.
  final bool readOnly = false,

  /// Tastiera a schermo; di base testo.
  final TextInputType? keyboardType,

  /// Chiamata a ogni modifica del testo.
  final ValueChanged<String>? onChanged,

  /// Chiamata con Invio (solo su una riga).
  final ValueChanged<String>? onSubmitted,

  /// The keyboard's action key; «Fine» by default, «Cerca» for a search.
  final TextInputAction? textInputAction,
}) extends StatelessWidget {
  /// Crea il campo di testo.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final e = error;
    final i = icon;
    final errorBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
      borderSide: BorderSide(color: c.inputBorderError, width: e == null ? 1 : 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: PostinoSpacing.s1,
      children: [
        // Label, field and helper are one node: «Descrizione, campo di testo, Descrivi che email…».
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: PostinoSpacing.s1,
            children: [
              // A control's label: out of any selection.
              SelectionContainer.disabled(
                child: Text(label, style: PostinoText.labelSm.copyWith(color: c.inkMuted)),
              ),
              TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                obscureText: obscure,
                enableSuggestions: !obscure,
                autocorrect: !obscure,
                readOnly: readOnly,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                // Without it Enter (done) would also drop the focus.
                onEditingComplete: onSubmitted == null ? null : () {},
                minLines: multiline ? 3 : 1,
                maxLines: multiline ? null : 1,
                keyboardType: multiline ? TextInputType.multiline : keyboardType ?? TextInputType.text,
                textInputAction: multiline ? TextInputAction.newline : textInputAction ?? TextInputAction.done,
                style: PostinoText.preview.copyWith(color: c.ink),
                decoration: InputDecoration(
                  isDense: true,
                  helperText: e == null ? helper : null,
                  helperMaxLines: 10,
                  helperStyle: PostinoText.caption.copyWith(color: c.inkMuted),
                  enabledBorder: e == null ? null : errorBorder,
                  focusedBorder: e == null ? null : errorBorder,
                  prefixIcon: i == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
                          child: PostinoIcon(i, color: c.inkMuted),
                        ),
                  prefixIconConstraints: const BoxConstraints(minWidth: PostinoSize.controlMd),
                ),
              ),
            ],
          ),
        ),
        if (e != null)
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(e, style: PostinoText.caption.copyWith(color: c.danger)),
          ),
      ],
    );
  }
}
