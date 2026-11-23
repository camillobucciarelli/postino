// ignore: deprecated_member_use
import 'package:flutter/material.dart' show Colors, Scaffold, Theme;
import 'package:flutter/widgets.dart';

import '../molecules/postino_snackbar_lift.dart';

/// The one place where the snackbars of the app show, whatever the layout: a Scaffold above the panes, so the
/// ScaffoldMessenger presents a snackbar only in it (it skips the Scaffolds nested in another) — once beside the
/// list, and visible below 900 with a Conversazione over the list. It outlives the panes: an Annulla survives the
/// Conversazione changing or closing. A bar fixed at the bottom of a pane (PostinoActionBar) lifts the snackbars
/// above itself while it is there (PostinoSnackbarLift).
class const PostinoSnackbarHost({
  super.key,

  /// The panes the snackbars show above.
  required final Widget child,
}) extends StatefulWidget {
  /// Crea il contenitore degli snackbar attorno a `child`.
  this;

  @override
  State<PostinoSnackbarHost> createState() => _PostinoSnackbarHostState();
}

class _PostinoSnackbarHostState() extends State<PostinoSnackbarHost> {
  // ponytail: never disposed: a bar going with the host lets go of it in the frame after; nothing listens by then.
  final _lift = ValueNotifier<(Object?, double)>((null, 0));

  @override
  Widget build(BuildContext context) => PostinoSnackbarLift(
    lift: _lift,
    child: ValueListenableBuilder(
      valueListenable: _lift,
      child: Scaffold(backgroundColor: Colors.transparent, resizeToAvoidBottomInset: false, body: widget.child),
      builder: (context, lift, scaffold) {
        // Always a Theme, so the Scaffold (and a snackbar on screen) stays when the lift changes.
        final theme = Theme.of(context);
        final inset = theme.snackBarTheme.insetPadding ?? _floatingInset;
        return Theme(
          data: theme.copyWith(
            snackBarTheme: theme.snackBarTheme.copyWith(insetPadding: inset.copyWith(bottom: inset.bottom + lift.$2)),
          ),
          child: scaffold!,
        );
      },
    ),
  );
}

/// Material's margin of a floating snackbar.
const _floatingInset = EdgeInsets.fromLTRB(15, 5, 15, 10);
