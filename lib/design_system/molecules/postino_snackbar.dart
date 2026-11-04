import 'dart:async';

import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Undo snackbar: a message, a countdown and one action; the content of a Material SnackBar.
/// The action sits in the content (not in SnackBar.action), so the component owns its styling and focus.
class PostinoSnackbar extends StatefulWidget {
  /// Crea lo snackbar con il conto alla rovescia fino a `until`.
  const PostinoSnackbar({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.until,
    this.now = DateTime.now,
  });

  /// Cosa è appena successo («Messaggio archiviato»).
  final String message;

  /// Nome dell'azione (Annulla).
  final String actionLabel;

  /// Chiamata all'azione; lo snackbar poi si chiude.
  final VoidCallback onAction;

  /// When the action stops being available; the countdown shows the whole seconds left to it.
  final DateTime until;

  /// The clock the countdown reads (the app's, so a test can move it).
  final DateTime Function() now;

  /// Shows it through the nearest ScaffoldMessenger, replacing the one on screen (a second Annulla never
  /// waits behind the first); returns the controller so the caller can dismiss it.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    required DateTime until,
    DateTime Function() now = DateTime.now,
  }) {
    final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
    final left = until.difference(now());
    return messenger.showSnackBar(
      SnackBar(
        duration: left.isNegative ? Duration.zero : left,
        padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: PostinoSpacing.s1),
        content: PostinoSnackbar(
          message: message,
          actionLabel: actionLabel,
          until: until,
          now: now,
          onAction: () {
            onAction();
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  State<PostinoSnackbar> createState() => _PostinoSnackbarState();
}

class _PostinoSnackbarState extends State<PostinoSnackbar> {
  late int _left = _seconds();
  Timer? _timer;

  int _seconds() {
    final ms = widget.until.difference(widget.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left = _seconds());
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final countdown = '$_left s';
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${widget.message}, $countdown',
      child: Row(
        spacing: PostinoSpacing.s3,
        children: [
          Expanded(
            // The texts are in the container's label: only the button adds a node.
            child: ExcludeSemantics(
              child: PostinoSelectable(
                child: Row(
                  spacing: PostinoSpacing.s3,
                  children: [
                    Flexible(
                      child: Text(widget.message, style: PostinoText.label.copyWith(color: c.snackbarFg)),
                    ),
                    Text(countdown, style: PostinoText.metaStrong.copyWith(color: c.snackbarFg)),
                  ],
                ),
              ),
            ),
          ),
          // The design's snackbar action: a ghost button in snackbar-action (as the Banner restyles its ghost).
          TextButtonTheme(
            data: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.snackbarAction)),
            child: PostinoButton(
              label: widget.actionLabel,
              onPressed: widget.onAction,
              variant: PostinoButtonVariant.ghost,
              size: PostinoButtonSize.sm,
            ),
          ),
        ],
      ),
    );
  }
}
