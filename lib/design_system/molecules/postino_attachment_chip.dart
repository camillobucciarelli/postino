import 'package:flutter/material.dart';

import '../atoms/postino_file_type_badge.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_icon_button.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_menu.dart';

/// An attached file (AttachmentChip): its type (a 40 badge with the extension, or the image icon), [name] and
/// [size], then the actions. A tap (or Enter) calls [onOpen]; the menu offers «Salva…» ([saveLabel], [onSave]).
/// Downloading ([progress] 0–1): [progressLabel] instead of the size, a `brand` bar along the bottom and
/// Annulla ([cancelLabel], [onCancel]). Failed ([error], in words): `danger` border and Riprova ([retryLabel],
/// [onRetry], by default [onOpen]: the failed action may have been a save). A [warning] (an executable, #75)
/// takes the size's place in `warning`; [error] wins when both are set. Without [onOpen] the chip is not a
/// button: no tap, no hint, screen readers hear «name, warning»; the menu stays.
/// Name and size are selectable text; screen readers hear «name, size» as a button, [openLabel] as its hint.
class const PostinoAttachmentChip({
  super.key,
  required this.name,
  required this.size,
  this.onOpen,
  this.openLabel = '',
  this.progress,
  this.progressLabel,
  this.cancelLabel = '',
  this.onCancel,
  this.error,
  this.warning,
  this.retryLabel = '',
  this.onRetry,
  this.moreLabel = '',
  this.saveLabel = '',
  this.onSave,
}) extends StatefulWidget {
  /// Crea il chip dell'allegato; senza `onOpen` è una semplice etichetta.
  this;

  /// Nome del file; troncato con ellissi a scala normale, a capo con testo ingrandito.
  final String name;

  /// Already formatted («1,2 MB»).
  final String size;

  /// Null: a plain label, not a button (a file only shown, like the forwarded ones of a Bozza).
  final VoidCallback? onOpen;

  /// Suggerimento accessibile per aprire l'allegato (usato solo con `onOpen`).
  final String openLabel;

  /// Avanzamento del download da 0 a 1; null se non è in corso.
  final double? progress;

  /// Testo che sostituisce la dimensione durante il download («42%»).
  final String? progressLabel;

  /// Nome del pulsante Annulla.
  final String cancelLabel;

  /// Chiamata dal pulsante Annulla durante il download.
  final VoidCallback? onCancel;

  /// Motivo dell'errore, a parole; il chip diventa `danger` con Riprova.
  final String? error;

  /// Avviso (es. eseguibile) al posto della dimensione, in `warning`.
  final String? warning;

  /// Nome del pulsante Riprova.
  final String retryLabel;

  /// Chiamata da Riprova; se null ripete `onOpen`.
  final VoidCallback? onRetry;

  /// The menu button's name («Altre azioni»); no menu without [onSave].
  final String moreLabel;

  /// Etichetta della voce «Salva…» del menu.
  final String saveLabel;

  /// Salva il file; senza di essa il menu non compare.
  final VoidCallback? onSave;

  @override
  State<PostinoAttachmentChip> createState() => _PostinoAttachmentChipState();
}

class _PostinoAttachmentChipState() extends State<PostinoAttachmentChip> {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final w = widget;
    final progress = w.progress;
    final error = w.error;
    final warning = w.warning;
    final meta = progress != null ? w.progressLabel ?? '' : error ?? warning ?? w.size;
    final metaColor = error != null
        ? c.danger
        : warning != null
        ? c.warning
        : c.inkSubtle;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.md));
    final save = w.onSave;
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final open = w.onOpen;
    final body = Padding(
      padding: const EdgeInsets.all(PostinoSpacing.s2),
      child: Row(
        spacing: PostinoSpacing.s3,
        children: [
          SelectionContainer.disabled(child: PostinoFileTypeBadge(w.name)),
          Expanded(
            child: PostinoSelectable(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    // Enlarged text wraps instead of being cut.
                    maxLines: wrap ? null : 1,
                    overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: PostinoText.preview.copyWith(color: c.ink, fontWeight: FontWeight.w500),
                  ),
                  _Meta(text: meta, color: metaColor, icon: metaColor != c.inkSubtle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320, minHeight: 56),
      child: Material(
        color: c.surfaceRaised,
        // The progress bar follows the rounded corners.
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: error != null ? c.danger : c.borderSubtle),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: open != null,
                    label: w.name,
                    value: meta,
                    hint: open == null ? null : w.openLabel,
                    onTap: open,
                    excludeSemantics: true,
                    child: open == null
                        ? body
                        : InkWell(
                            key: const ValueKey('attachment-open'),
                            onTap: open,
                            borderRadius: radius,
                            child: PostinoFocusRing(borderRadius: radius, inset: true, child: body),
                          ),
                  ),
                ),
                SelectionContainer.disabled(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (progress != null)
                        PostinoIconButton(
                          key: const ValueKey('attachment-cancel'),
                          icon: PostinoIcons.close,
                          label: w.cancelLabel,
                          onPressed: w.onCancel,
                        )
                      else ...[
                        if (error != null)
                          PostinoIconButton(
                            key: const ValueKey('attachment-retry'),
                            icon: PostinoIcons.refresh,
                            label: w.retryLabel,
                            onPressed: w.onRetry ?? open,
                          ),
                        if (save != null) _menu(save),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    key: const ValueKey('attachment-progress'),
                    widthFactor: progress.clamp(0, 1),
                    child: ColoredBox(color: c.brand, child: const SizedBox(height: 3)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menu(VoidCallback save) => PostinoMenu(
    buttonKey: const ValueKey('attachment-more'),
    label: widget.moreLabel,
    items: [
      PostinoMenuItem(
        key: const ValueKey('attachment-save'),
        label: widget.saveLabel,
        icon: PostinoIcons.download,
        onPressed: save,
      ),
    ],
  );
}

/// The size, the progress, a warning or the reason it failed: `meta` in [color] (`ink-subtle`, `warning`
/// or `danger`), with the alert [icon] in front when asked.
class const _Meta({required this.text, required this.color, required this.icon}) extends StatelessWidget {
  final String text;
  final Color color;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          if (icon) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: PostinoIcon(PostinoIcons.alert, size: PostinoSize.iconSm, color: color),
            ),
            const TextSpan(text: ' '),
          ],
          TextSpan(text: text),
        ],
      ),
      style: PostinoText.meta.copyWith(color: color),
    );
  }
}
