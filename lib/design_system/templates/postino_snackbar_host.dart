// ignore: deprecated_member_use
import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:flutter/widgets.dart';

/// The one place where the snackbars of the app show, whatever the layout: a Scaffold above the panes, so the
/// ScaffoldMessenger presents a snackbar only in it (it skips the Scaffolds nested in another) — once beside the
/// list, and visible below 900 with a Conversazione over the list. It outlives the panes: an Annulla survives the
/// Conversazione changing or closing.
class const PostinoSnackbarHost({
  super.key,

  /// The panes the snackbars show above.
  required final Widget child,
}) extends StatelessWidget {
  /// Crea il contenitore degli snackbar attorno a `child`.
  this;

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Colors.transparent, resizeToAvoidBottomInset: false, body: child);
}
