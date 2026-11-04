import 'package:flutter/material.dart';

import '../atoms/postino_icon.dart';
import '../atoms/postino_icon_button.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One entry of a [PostinoMenu]: [label] (a verb), an optional leading [icon], [onPressed].
class const PostinoMenuItem({
  /// Verbo che dice cosa fa la voce.
  required final String label,

  /// Chiamata alla scelta della voce.
  required final VoidCallback onPressed,

  /// Icona a sinistra, se serve.
  final PostinoIconData? icon,

  /// For the tests, on the item's button.
  final Key? key,
}) {
  /// Crea una voce di menu.
  this;
}

/// A menu (Menu molecule) behind an icon button: [label] is the button's name («Altre azioni»,
/// «Azioni del messaggio»), [icon] its glyph. Opening it (click, Enter, Space) focuses the first item,
/// so the keyboard lands inside; Esc closes it. The items are at least 220 wide and 48 high.
class const PostinoMenu({
  super.key,

  /// Nome del pulsante per lo screen reader.
  required final String label,

  /// Le voci, nell'ordine mostrato.
  required final List<PostinoMenuItem> items,

  /// Icona del pulsante; di default i tre puntini verticali.
  final PostinoIconData icon = PostinoIcons.moreVertical,

  /// For the tests, on the trigger button.
  final Key? buttonKey,
}) extends StatefulWidget {
  /// Crea il menu con il suo pulsante.
  this;

  @override
  State<PostinoMenu> createState() => _PostinoMenuState();
}

class _PostinoMenuState() extends State<PostinoMenu> {
  /// The first item: focused when the menu opens.
  final _first = FocusNode(debugLabel: 'Menu');

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MenuAnchor(
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: PostinoSpacing.s1)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
            side: BorderSide(color: c.borderSubtle),
          ),
        ),
      ),
      menuChildren: [
        for (final (i, item) in widget.items.indexed)
          MenuItemButton(
            key: item.key,
            focusNode: i == 0 ? _first : null,
            onPressed: item.onPressed,
            style: MenuItemButton.styleFrom(
              minimumSize: const Size(220, PostinoSize.touchTargetAndroid),
              padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4),
              foregroundColor: c.ink,
              iconColor: c.inkMuted,
              textStyle: PostinoText.label,
            ),
            leadingIcon: item.icon == null ? null : PostinoIcon(item.icon!),
            child: Text(item.label),
          ),
      ],
      builder: (context, menu, _) => PostinoIconButton(
        key: widget.buttonKey,
        icon: widget.icon,
        label: widget.label,
        onPressed: () {
          if (menu.isOpen) return menu.close();
          menu.open();
          WidgetsBinding.instance.addPostFrameCallback((_) => _first.requestFocus());
        },
      ),
    );
  }
}
