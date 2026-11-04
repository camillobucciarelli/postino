import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../tokens/postino_theme.dart';
import 'postino_menu_item.dart';
import 'postino_menu_panel.dart';

/// The context menu of [child], a single control such as a row of the list: right click or long press open it
/// at the pointer, the menu key or Shift+F10 (with the focus inside [child]) at its top left corner. Like
/// PostinoMenu the first item takes the focus and Esc closes it. Screen readers get the items as custom actions
/// of [child], merged into its node.
class const PostinoContextMenu({
  super.key,

  /// Le voci, nell'ordine mostrato.
  required final List<PostinoMenuItem> items,

  /// Il contenuto su cui si apre il menu.
  required final Widget child,
}) extends StatefulWidget {
  /// Crea il menu contestuale attorno a `child`.
  this;

  @override
  State<PostinoContextMenu> createState() => PostinoContextMenuState();
}

/// The state of a PostinoContextMenu: [open] opens it at a given position, for a caller with its own trigger.
class PostinoContextMenuState() extends State<PostinoContextMenu> {
  /// Creato da `PostinoContextMenu`.
  this;

  final _controller = MenuController();

  /// The first item: focused when the menu opens.
  final _first = FocusNode(debugLabel: 'Menu contestuale');

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  /// Opens the menu at [position], in the child's coordinates (its top left corner by default).
  void open([Offset position = Offset.zero]) {
    _controller.open(position: position);
    WidgetsBinding.instance.addPostFrameCallback((_) => _first.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    // The anchor is an empty box over the child, not its parent: MenuAnchor binds the arrows to its own traversal
    // for everything under it, which would take them from the list (j/k and the arrows, ADR 0014).
    return Stack(
      fit: StackFit.passthrough,
      children: [
        MergeSemantics(
          child: Semantics(
            customSemanticsActions: {
              for (final item in widget.items) CustomSemanticsAction(label: item.label): item.onPressed,
            },
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.contextMenu): open,
                const SingleActivator(LogicalKeyboardKey.f10, shift: true): open,
              },
              child: GestureDetector(
                onSecondaryTapUp: (d) => open(d.localPosition),
                onLongPressStart: (d) => open(d.localPosition),
                child: widget.child,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: MenuAnchor(
            controller: _controller,
            style: postinoMenuStyle(c),
            menuChildren: postinoMenuChildren(c, widget.items, _first),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
