import 'package:flutter/widgets.dart';

/// How far above the bottom (its safe area aside) the snackbars show, and the bar that holds them there: a
/// PostinoSnackbarHost provides it, a bar fixed at the bottom of a pane (PostinoActionBar) sets it while it is there.
class const PostinoSnackbarLift({
  super.key,

  /// Il sollevamento e la barra che lo tiene.
  required final ValueNotifier<(Object?, double)> lift,
  required super.child,
}) extends InheritedWidget {
  /// Fornisce il sollevamento degli snackbar a `child`.
  this;

  /// The lift under [context], null outside a host. Read without depending: a bar keeps it to let go of it when it
  /// goes (no lookups in dispose).
  static ValueNotifier<(Object?, double)>? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PostinoSnackbarLift>()?.lift;

  @override
  bool updateShouldNotify(PostinoSnackbarLift old) => old.lift != lift;
}
