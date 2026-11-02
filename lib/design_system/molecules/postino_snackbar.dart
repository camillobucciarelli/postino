import 'dart:async';

import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Undo snackbar: a message, a countdown and one action; the content of a Material SnackBar.
/// The action sits in the content (not in SnackBar.action), so the component owns its styling and focus.
class PostinoSnackbar extends StatefulWidget {
  const PostinoSnackbar({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.duration = PostinoMotion.undoWindow,
    this.semanticsLabel,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  /// How long the action stays available; the countdown shows its whole seconds.
  final Duration duration;

  /// What the screen reader announces; defaults to the message and the countdown.
  final String? semanticsLabel;

  /// Shows it through the nearest ScaffoldMessenger; returns the controller so the caller can dismiss it.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = PostinoMotion.undoWindow,
    String? semanticsLabel,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    return messenger.showSnackBar(
      SnackBar(
        duration: duration,
        padding: const EdgeInsets.symmetric(
          horizontal: PostinoSpacing.s4,
          vertical: PostinoSpacing.s1,
        ),
        content: PostinoSnackbar(
          message: message,
          actionLabel: actionLabel,
          duration: duration,
          semanticsLabel: semanticsLabel,
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
  late int _left = widget.duration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The tick count, not the elapsed clock: a periodic Timer re-aligns to its start, so no drift.
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left = widget.duration.inSeconds - t.tick);
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
      label: widget.semanticsLabel ?? '${widget.message}, $countdown',
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
                      child: Text(
                        widget.message,
                        style: PostinoText.label.copyWith(color: c.snackbarFg),
                      ),
                    ),
                    Text(
                      countdown,
                      style: PostinoText.metaStrong.copyWith(
                        color: c.snackbarFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The design's snackbar action: a ghost button in snackbar-action (as the Banner restyles its ghost).
          TextButtonTheme(
            data: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: c.snackbarAction),
            ),
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
