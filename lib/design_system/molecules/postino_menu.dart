// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_icon_button.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import 'postino_menu_item.dart';
import 'postino_menu_panel.dart';

export 'postino_menu_item.dart';

/// A menu (Menu molecule) behind an icon button: [label] is the button's name («Altre azioni»,
/// «Azioni del messaggio»), [icon] its glyph. Opening it (click, Enter, Space) focuses the first item,
/// so the keyboard lands inside; Esc closes it. The items are at least 220 wide and 48 high.
/// The same menu opened on a content (right click, long press, menu key) is PostinoContextMenu.
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
      style: postinoMenuStyle(c),
      menuChildren: postinoMenuChildren(c, widget.items, _first),
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
