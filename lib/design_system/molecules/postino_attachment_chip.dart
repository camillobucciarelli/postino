import 'package:flutter/material.dart';

import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_icon_button.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// An attached file (AttachmentChip): its type (a 40 badge with the extension, or the image icon), [name] and
/// [size], then the actions. A tap (or Enter) calls [onOpen]; the menu offers «Salva…» ([saveLabel], [onSave]).
/// Downloading ([progress] 0–1): [progressLabel] instead of the size, a `brand` bar along the bottom and
/// Annulla ([cancelLabel], [onCancel]). Failed ([error], in words): `danger` border and Riprova ([retryLabel],
/// [onRetry], by default [onOpen]: the failed action may have been a save). A [warning] (an executable, #75)
/// takes the size's place in `warning`; [error] wins when both are set. Without [onOpen] the chip is not a
/// button: no tap, no hint, screen readers hear «name, warning»; the menu stays.
/// Name and size are selectable text; screen readers hear «name, size» as a button, [openLabel] as its hint.
class PostinoAttachmentChip extends StatefulWidget {
  const PostinoAttachmentChip({
    super.key,
    required this.name,
    required this.size,
    required this.onOpen,
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
  });

  final String name;

  /// Already formatted («1,2 MB»).
  final String size;
  final VoidCallback? onOpen;
  final String openLabel;
  final double? progress;
  final String? progressLabel;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final String? error;
  final String? warning;
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
  /// The first item: focused when the menu opens, so the keyboard lands inside it.
  final _save = FocusNode(debugLabel: 'Salva');

  @override
  void dispose() {
    _save.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final w = widget;
    final progress = w.progress;
    final error = w.error;
    final warning = w.warning;
    final meta = progress != null
        ? w.progressLabel ?? ''
        : error ?? warning ?? w.size;
    final metaColor = error != null
        ? c.danger
        : warning != null
        ? c.warning
        : c.inkSubtle;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.md));
    final save = w.onSave;
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
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
                    button: w.onOpen != null,
                    label: w.name,
                    value: meta,
                    hint: w.onOpen == null ? null : w.openLabel,
                    onTap: w.onOpen,
                    excludeSemantics: true,
                    child: InkWell(
                      key: const ValueKey('attachment-open'),
                      onTap: w.onOpen,
                      borderRadius: radius,
                      child: PostinoFocusRing(
                        borderRadius: radius,
                        inset: true,
                        child: Padding(
                          padding: const EdgeInsets.all(PostinoSpacing.s2),
                          child: Row(
                            spacing: PostinoSpacing.s3,
                            children: [
                              SelectionContainer.disabled(
                                child: _TypeBadge(w.name),
                              ),
                              Expanded(
                                child: PostinoSelectable(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      _Meta(
                                        text: meta,
                                        color: metaColor,
                                        icon: metaColor != c.inkSubtle,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            onPressed: w.onRetry ?? w.onOpen,
                          ),
                        if (save != null) _menu(c, save),
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

  // ponytail: the Menu molecule lives here until a second menu needs it; then it moves to its own file.
  Widget _menu(PostinoColors c, VoidCallback save) => MenuAnchor(
    style: MenuStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: PostinoSpacing.s1),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(PostinoRadius.md),
          ),
          side: BorderSide(
            color: c.borderSubtle,
            width: PostinoBorder.borderWidthHairline,
          ),
        ),
      ),
    ),
    menuChildren: [
      MenuItemButton(
        key: const ValueKey('attachment-save'),
        focusNode: _save,
        onPressed: save,
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(220, PostinoSize.touchTargetAndroid),
          padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4),
          foregroundColor: c.ink,
          iconColor: c.inkMuted,
          textStyle: PostinoText.label,
        ),
        leadingIcon: const PostinoIcon(PostinoIcons.download),
        child: Text(widget.saveLabel),
      ),
    ],
    builder: (context, menu, _) => PostinoIconButton(
      key: const ValueKey('attachment-more'),
      icon: PostinoIcons.moreVertical,
      label: widget.moreLabel,
      onPressed: () {
        if (menu.isOpen) return menu.close();
        menu.open();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _save.requestFocus(),
        );
      },
    ),
  );
}

/// The size, the progress, a warning or the reason it failed: `meta` in [color] (`ink-subtle`, `warning`
/// or `danger`), with the alert [icon] in front when asked.
class _Meta extends StatelessWidget {
  const _Meta({required this.text, required this.color, required this.icon});

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
