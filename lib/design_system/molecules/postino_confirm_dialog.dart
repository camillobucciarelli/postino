import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../tokens/postino_text.dart';
import '../tokens/postino_theme.dart';

/// A Dialog asking the user to confirm a risky step: [title] says what is going on (a title, not selectable),
/// [message] and [note] explain it (selectable, so a domain can be copied). Esc and [cancelLabel] answer false,
/// [confirmLabel] true; the focus starts on [cancelLabel], so Enter never confirms by accident.
Future<bool> showPostinoConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  String? note,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final c = context.pc;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message, style: PostinoText.body.copyWith(color: c.ink)),
              if (note != null) ...[
                const SizedBox(height: 12),
                SelectableText(note, style: PostinoText.bodyQuote.copyWith(color: c.inkMuted)),
              ],
            ],
          ),
          actions: [
            Focus(
              autofocus: true,
              skipTraversal: true,
              descendantsAreTraversable: true,
              child: PostinoButton(
                label: cancelLabel,
                variant: PostinoButtonVariant.ghost,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            PostinoButton(label: confirmLabel, onPressed: () => Navigator.pop(context, true)),
          ],
        );
      },
    ) ??
    false;
