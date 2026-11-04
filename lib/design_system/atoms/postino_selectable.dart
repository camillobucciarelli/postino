import 'package:flutter/material.dart';

/// Esc over a selection: the first press clears it (the layout asks the focus for this intent
/// before it closes the Conversazione, so the second press closes).
class PostinoClearSelectionIntent extends Intent {
  /// Crea l'intent.
  const PostinoClearSelectionIntent();
}

/// Makes the informational text below selectable and copiable. Inside a [SelectionArea] already
/// (the Conversazione) it adds nothing, so there is a single area and the selection can cross parts.
// ponytail: one area per standalone view (empty state, banner), no selection across views.
class PostinoSelectable extends StatefulWidget {
  /// Crea il contenitore selezionabile.
  const PostinoSelectable({super.key, required this.child});

  /// Testo informativo da rendere selezionabile.
  final Widget child;

  @override
  State<PostinoSelectable> createState() => _PostinoSelectableState();
}

class _PostinoSelectableState extends State<PostinoSelectable> {
  /// Out of the Tab order, so the area adds no invisible stop before the button.
  final _focus = FocusNode(debugLabel: 'Testo', skipTraversal: true);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionContainer.maybeOf(context) == null
      ? SelectionArea(focusNode: _focus, child: widget.child)
      : widget.child;
}
