import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The screen's root holds its shortcut (docs/agents/struttura-codice.md): Esc calls [onBack], from anywhere in it.
class const EscapeToGoBack({super.key, required final VoidCallback onBack, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): onBack},
    // Focus inside, so Esc works before anything was clicked.
    child: FocusScope(autofocus: true, child: child),
  );
}
