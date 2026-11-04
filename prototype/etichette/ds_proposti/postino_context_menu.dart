// PROTOTIPO (#106) — modifica proposta a molecules/postino_menu.dart: lo stesso menu aperto
// sul contenuto (clic destro, pressione lunga, tasto menu, Maiusc+F10) invece che da un pulsante.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/molecules/postino_menu.dart' show PostinoMenuItem;
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// The context menu of [child]: right click or long press opens it at the pointer, the menu key or
/// Shift+F10 (with the focus inside [child]) at its corner; the first item takes the focus, Esc closes.
/// Screen readers get the items as custom actions of [child].
class const PostinoContextMenu({super.key, required final List<PostinoMenuItem> items, required final Widget child})
    extends StatefulWidget {
  @override
  State<PostinoContextMenu> createState() => _PostinoContextMenuState();
}

class _PostinoContextMenuState() extends State<PostinoContextMenu> {
  final _controller = MenuController();
  final _first = FocusNode(debugLabel: 'Menu contestuale');

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  void _open([Offset? at]) {
    _controller.open(position: at ?? const Offset(PostinoSpacing.s4, PostinoSpacing.s4));
    WidgetsBinding.instance.addPostFrameCallback((_) => _first.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MenuAnchor(
      controller: _controller,
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
      child: Semantics(
        customSemanticsActions: {
          for (final item in widget.items) CustomSemanticsAction(label: item.label): item.onPressed,
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.contextMenu): _open,
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): _open,
          },
          child: GestureDetector(
            onSecondaryTapUp: (d) => _open(d.localPosition),
            onLongPressStart: (d) => _open(d.localPosition),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
