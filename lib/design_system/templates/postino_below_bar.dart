import 'package:flutter/widgets.dart';

/// What sits under a PostinoAppBar in a Column: the bar has already taken the top inset (notch, status bar), so
/// [child] does not take it again, or its lists would start that far under the bar. The bottom inset stays: the
/// last row clears the home bar.
class const PostinoBelowBar({
  super.key,

  /// Contenuto sotto la barra, a cui si toglie l'inset superiore.
  required final Widget child,
}) extends StatelessWidget {
  /// Toglie l'inset superiore a [child].
  this;

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(context: context, removeTop: true, child: child);
}
