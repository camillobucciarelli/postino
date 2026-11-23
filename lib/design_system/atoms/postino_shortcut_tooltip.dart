import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// The tooltip of a command with a keyboard shortcut: «Nome · scorciatoia» for the pointer and the keyboard, the bare
/// [label] after a touch (a long press: no keyboard at hand). Out of the semantics: the command names itself, so the
/// screen reader hears the name only.
class const PostinoShortcutTooltip({
  super.key,

  /// Nome del comando.
  required final String label,

  /// Scorciatoia da tastiera («R», «⌘R»), mostrata dopo il nome con puntatore e tastiera.
  required final String shortcut,

  /// Il comando.
  required final Widget child,
}) extends StatefulWidget {
  /// Crea il tooltip con la scorciatoia.
  this;

  @override
  State<PostinoShortcutTooltip> createState() => _PostinoShortcutTooltipState();
}

class _PostinoShortcutTooltipState() extends State<PostinoShortcutTooltip> {
  /// The last pointer on it was a finger. Before any, the pointer's (and the keyboard's) form.
  bool _touch = false;

  void _seen(PointerEvent e) {
    final touch = e.kind == PointerDeviceKind.touch;
    if (touch != _touch) setState(() => _touch = touch);
  }

  @override
  Widget build(BuildContext context) => Listener(
    // The pointer goes down before a long press shows the tooltip: the message is the touch's by then.
    onPointerDown: _seen,
    onPointerHover: _seen,
    child: Tooltip(
      message: _touch ? widget.label : '${widget.label} · ${widget.shortcut}',
      excludeFromSemantics: true,
      child: widget.child,
    ),
  );
}
