import 'package:flutter/material.dart';

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
/// [onRetry], by default [onOpen]: the failed action may have been a save).
/// Name and size are selectable text; screen readers hear «name, size» as a button, [openLabel] as its hint.
class PostinoAttachmentChip extends StatefulWidget {
  const PostinoAttachmentChip({
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
    this.retryLabel = '',
    this.onRetry,
    this.moreLabel = '',
    this.saveLabel = '',
    this.onSave,
  });

  final String name;

  /// Already formatted («1,2 MB»).
  final String size;

  /// Null: a plain label, not a button (a file only shown, like the forwarded ones of a Bozza).
  final VoidCallback? onOpen;
  final String openLabel;
  final double? progress;
  final String? progressLabel;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final String? error;
  final String retryLabel;
  final VoidCallback? onRetry;

  /// The menu button's name («Altre azioni»); no menu without [onSave].
  final String moreLabel;
  final String saveLabel;
  final VoidCallback? onSave;

  @override
  State<PostinoAttachmentChip> createState() => _PostinoAttachmentChipState();
}

class _PostinoAttachmentChipState extends State<PostinoAttachmentChip> {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final w = widget;
    final progress = w.progress;
    final error = w.error;
    final meta = progress != null ? w.progressLabel ?? '' : error ?? w.size;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.md));
    final save = w.onSave;
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final open = w.onOpen;
    final body = Padding(
      padding: const EdgeInsets.all(PostinoSpacing.s2),
      child: Row(
        spacing: PostinoSpacing.s3,
        children: [
          SelectionContainer.disabled(child: _TypeBadge(w.name)),
          Expanded(
            child: PostinoSelectable(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    // Enlarged text wraps instead of being cut.
                    maxLines: wrap ? null : 1,
                    overflow: wrap
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: PostinoText.preview.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _Meta(text: meta, error: error != null),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 220,
        maxWidth: 320,
        minHeight: 56,
      ),
      child: Material(
        color: c.surfaceRaised,
        // The progress bar follows the rounded corners.
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: error != null ? c.danger : c.borderSubtle,
            width: PostinoBorder.borderWidthHairline,
          ),
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
                            child: PostinoFocusRing(
                              borderRadius: radius,
                              inset: true,
                              child: body,
                            ),
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
                    child: ColoredBox(
                      color: c.brand,
                      child: const SizedBox(height: 3),
                    ),
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

/// The size, the progress or the reason it failed: `meta` in `ink-subtle`, or `danger` with the alert icon.
class _Meta extends StatelessWidget {
  const _Meta({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final color = error ? c.danger : c.inkSubtle;
    return Text.rich(
      TextSpan(
        children: [
          if (error) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: PostinoIcon(
                PostinoIcons.alert,
                size: PostinoSize.iconSm,
                color: color,
              ),
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

/// 40 square, `radius-sm`: the extension (up to 4 letters) or the image icon, colored by kind.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.name);

  final String name;

  static final _kinds = {
    'pdf': _Kind.pdf,
    for (final e in ['doc', 'docx', 'odt', 'rtf', 'txt', 'pages']) e: _Kind.doc,
    for (final e in ['xls', 'xlsx', 'ods', 'csv', 'numbers']) e: _Kind.sheet,
    for (final e in [
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'heic',
      'bmp',
      'tif',
      'tiff',
      'svg',
    ])
      e: _Kind.image,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 && dot < name.length - 1
        ? name.substring(dot + 1).toLowerCase()
        : '';
    final kind = _kinds[ext] ?? _Kind.other;
    final (bg, fg) = switch (kind) {
      _Kind.pdf => (c.dangerSubtle, c.danger),
      _Kind.doc => (c.brandSubtle, c.brand),
      _Kind.sheet => (c.successSubtle, c.success),
      _Kind.image => (c.labelSeaBg, c.labelSeaFg),
      _Kind.other => (c.surfacePressed, c.inkMuted),
    };
    final label = (ext.isEmpty ? 'file' : ext).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: PostinoSize.controlMd,
        height: PostinoSize.controlMd,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(
            Radius.circular(PostinoRadius.sm),
          ),
        ),
        child: kind == _Kind.image
            ? PostinoIcon(PostinoIcons.image, color: fg)
            : Text(
                label.length > 4 ? label.substring(0, 4) : label,
                maxLines: 1,
                // Inside its fixed 40 square: it does not grow with the text size.
                textScaler: TextScaler.noScaling,
                style: PostinoText.overline.copyWith(
                  color: fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }
}

enum _Kind { pdf, doc, sheet, image, other }
