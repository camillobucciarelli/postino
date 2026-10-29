import 'package:flutter/widgets.dart';

import '../tokens/postino_tokens.dart';

/// Material 3 "fade through" when [transitionKey] changes: the previous child fades out (90ms),
/// then [child] fades in and scales 0.96→1 (210ms). Only one of them is in the tree at a time.
/// The previous child is the widget given before, so it must carry its own params.
/// With reduced motion ([MediaQuery.disableAnimationsOf]) the swap is instant.
class PostinoFadeThrough extends StatefulWidget {
  const PostinoFadeThrough({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  State<PostinoFadeThrough> createState() => _PostinoFadeThroughState();
}

class _PostinoFadeThroughState extends State<PostinoFadeThrough>
    with SingleTickerProviderStateMixin {
  static final _total =
      PostinoMotion.fadeThroughOut + PostinoMotion.fadeThroughIn;
  static final _split =
      PostinoMotion.fadeThroughOut.inMicroseconds / _total.inMicroseconds;

  // Starts finished: the first build does not animate.
  late final _controller =
      AnimationController(vsync: this, duration: _total, value: 1)
        ..addStatusListener((s) {
          if (s.isCompleted) setState(() => _outgoing = null);
        });
  Widget? _outgoing;

  @override
  void didUpdateWidget(PostinoFadeThrough old) {
    super.didUpdateWidget(old);
    if (old.transitionKey != widget.transitionKey &&
        !MediaQuery.disableAnimationsOf(context)) {
      _outgoing = KeyedSubtree(
        key: ValueKey(old.transitionKey),
        child: old.child,
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      final out = _outgoing;
      if (out != null && t < _split) {
        final k = PostinoMotion.standardAccelerate.transform(t / _split);
        return FadeTransition(
          opacity: AlwaysStoppedAnimation(1 - k),
          child: out,
        );
      }
      final k = PostinoMotion.emphasizedDecelerate.transform(
        ((t - _split) / (1 - _split)).clamp(0.0, 1.0),
      );
      return FadeTransition(
        opacity: AlwaysStoppedAnimation(k),
        child: ScaleTransition(
          scale: AlwaysStoppedAnimation(
            PostinoMotion.fadeThroughScaleBegin +
                (1 - PostinoMotion.fadeThroughScaleBegin) * k,
          ),
          child: KeyedSubtree(
            key: ValueKey(widget.transitionKey),
            child: widget.child,
          ),
        ),
      );
    },
  );
}
