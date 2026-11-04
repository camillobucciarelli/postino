import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A header line of the composer («A», «Oggetto»): the label on the left, a bare single-line
/// field, a `composer-field-divider` hairline below that turns `input-border-focus` with focus.
class const PostinoComposerField({
  super.key,
  required this.label,
  required this.controller,
  this.focusNode,
  this.autofocus = false,
  this.onChanged,
  this.keyboardType,
  this.trailing,
}) extends StatefulWidget {
  /// Crea una riga di intestazione del compositore.
  this;

  /// Etichetta a sinistra, anche nome accessibile del campo.
  final String label;

  /// Controller del testo.
  final TextEditingController controller;

  /// Nodo del focus; se nullo il campo ne crea uno suo.
  final FocusNode? focusNode;

  /// Se il campo prende il focus all'apertura.
  final bool autofocus;

  /// Chiamata a ogni modifica del testo.
  final ValueChanged<String>? onChanged;

  /// Tipo di tastiera richiesto.
  final TextInputType? keyboardType;

  /// Widget a destra del campo (es. un'azione).
  final Widget? trailing;

  @override
  State<PostinoComposerField> createState() => _PostinoComposerFieldState();
}

class _PostinoComposerFieldState() extends State<PostinoComposerField> {
  late final _focus = widget.focusNode ?? FocusNode(debugLabel: widget.label);

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) => Container(
        constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
        decoration: BoxDecoration(
          border: Border(
            bottom: _focus.hasFocus
                ? BorderSide(color: c.inputBorderFocus, width: PostinoBorder.borderWidthFocus)
                : BorderSide(color: c.composerFieldDivider),
          ),
        ),
        child: Row(
          spacing: PostinoSpacing.s3,
          children: [
            Expanded(
              // One node, the field's, named by the label: VoiceOver reads «A, text field».
              child: MergeSemantics(
                child: Row(
                  spacing: PostinoSpacing.s3,
                  children: [
                    Semantics(
                      label: widget.label,
                      child: ExcludeSemantics(
                        child: Text(widget.label, style: PostinoText.label.copyWith(color: c.inkMuted)),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        autofocus: widget.autofocus,
                        onChanged: widget.onChanged,
                        keyboardType: widget.keyboardType,
                        style: PostinoText.body.copyWith(color: c.ink),
                        // No box: the row's hairline is the only border.
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: PostinoSpacing.s3),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }
}
