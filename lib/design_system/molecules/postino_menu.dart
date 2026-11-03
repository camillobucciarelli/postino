import 'package:flutter/material.dart';

import '../atoms/postino_icon.dart';
import '../atoms/postino_icon_button.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One entry of a [PostinoMenu]: [label] (a verb), an optional leading [icon], [onPressed].
class PostinoMenuItem {
  const PostinoMenuItem({
    required this.label,
    required this.onPressed,
    this.icon,
    this.key,
  });

  final String label;
  final VoidCallback onPressed;
  final PostinoIconData? icon;

  /// For the tests, on the item's button.
  final Key? key;
}

/// A menu (Menu molecule) behind an icon button: [label] is the button's name («Altre azioni»,
/// «Azioni del messaggio»), [icon] its glyph. Opening it (click, Enter, Space) focuses the first item,
/// so the keyboard lands inside; Esc closes it. The items are at least 220 wide and 48 high.
class PostinoMenu extends StatefulWidget {
  const PostinoMenu({
    super.key,
    required this.label,
    required this.items,
    this.icon = PostinoIcons.moreVertical,
    this.buttonKey,
  });

  final String label;
  final PostinoIconData icon;
  final List<PostinoMenuItem> items;

  /// For the tests, on the trigger button.
  final Key? buttonKey;

  @override
  State<PostinoMenu> createState() => _PostinoMenuState();
}

class _PostinoMenuState extends State<PostinoMenu> {
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
        for (final (i, item) in widget.items.indexed)
          MenuItemButton(
            key: item.key,
            focusNode: i == 0 ? _first : null,
            onPressed: item.onPressed,
            style: MenuItemButton.styleFrom(
              minimumSize: const Size(220, PostinoSize.touchTargetAndroid),
              padding: const EdgeInsets.symmetric(
                horizontal: PostinoSpacing.s4,
              ),
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
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _first.requestFocus(),
          );
        },
      ),
    );
  }
}
