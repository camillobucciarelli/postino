import 'package:flutter/material.dart';

import '../atoms/postino_icon.dart';
import '../tokens/postino_tokens.dart';
import 'postino_menu_item.dart';

/// The panel of a menu: `surface-raised` (theme), `radius-md`, `border-subtle`.
MenuStyle postinoMenuStyle(PostinoColors c) => MenuStyle(
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: PostinoSpacing.s1)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
      side: BorderSide(color: c.borderSubtle),
    ),
  ),
);

/// The entries of a menu, at least 220 wide and 48 high; [first] is the first one's focus, taken on opening.
List<Widget> postinoMenuChildren(PostinoColors c, List<PostinoMenuItem> items, FocusNode first) => [
  for (final (i, item) in items.indexed)
    MenuItemButton(
      key: item.key,
      focusNode: i == 0 ? first : null,
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
];
