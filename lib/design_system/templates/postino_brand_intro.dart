import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_brand_mark.dart';
import '../tokens/postino_tokens.dart';

/// At the start of the app (#267): over [child], the verderame of the native splash with [PostinoBrandMark] opening
/// once, then a fade to [child]. The cover takes no input, no focus and no semantics: [child] builds, reads and
/// answers under it from the first frame, so the start is not delayed. With reduced motion there is no cover.
class const PostinoBrandIntro({
  super.key,

  /// L'app sotto la copertura.
  required final Widget child,
}) extends StatefulWidget {
  /// Crea l'intro del marchio.
  this;

  /// Il verderame dello splash nativo (`values/colors.xml`, `LaunchScreen.storyboard`), in chiaro come in scuro.
  static const Color splash = Color(0xFF0E6456);

  @override
  State<PostinoBrandIntro> createState() => _PostinoBrandIntroState();
}

class _PostinoBrandIntroState() extends State<PostinoBrandIntro> {
  /// null until read from the first context: reduced motion skips the cover.
  bool? _covered;
  bool _fading = false;

  /// Wall clock, not frames: a window started hidden in the tray (#239) draws none, and when shown much later it
  /// finds the app uncovered instead of a launch animation.
  Timer? _deadline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_covered != null) return;
    _covered = !MediaQuery.disableAnimationsOf(context);
    if (_covered!) {
      _deadline = Timer(PostinoBrandMark.duration + PostinoMotion.fadeThroughOut, _uncover);
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  void _uncover() {
    _deadline?.cancel();
    setState(() => _covered = false);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_covered!)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ExcludeFocus(
                child: AnimatedOpacity(
                  opacity: _fading ? 0 : 1,
                  duration: PostinoMotion.fadeThroughOut,
                  onEnd: _uncover,
                  child: ColoredBox(
                    color: PostinoBrandIntro.splash,
                    child: Center(child: PostinoBrandMark(onDone: () => setState(() => _fading = true))),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
