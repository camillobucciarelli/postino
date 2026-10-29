import 'package:flutter/widgets.dart';

import '../tokens/postino_tokens.dart';

/// Material 3 "fade through" when [transitionKey] changes: a short gap, then [child] fades in and scales 0.96→1.
/// With reduced motion ([MediaQuery.disableAnimationsOf]) the swap is instant.
// ponytail: the outgoing content is not kept: routefly's RouterOutlet rebuilds in place and would show the new route
// during the fade-out, so the 90ms exit is an empty gap. Snapshot the old page here if a real cross-fade is wanted.
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
  static final _out = PostinoMotion.fadeThroughOut;
  static final _total =
      PostinoMotion.fadeThroughOut + PostinoMotion.fadeThroughIn;
  static final _enter = CurveTween(
    curve: Interval(
      _out.inMilliseconds / _total.inMilliseconds,
      1,
      curve: PostinoMotion.emphasizedDecelerate,
    ),
  );

  // Starts finished: the first build does not animate.
  late final _controller = AnimationController(
    vsync: this,
    duration: _total,
    value: 1,
  );
  late final _opacity = _controller.drive(_enter);
  late final _scale = _controller.drive(
    Tween(begin: PostinoMotion.fadeThroughScaleBegin, end: 1.0).chain(_enter),
  );

  @override
  void didUpdateWidget(PostinoFadeThrough old) {
    super.didUpdateWidget(old);
    if (old.transitionKey != widget.transitionKey &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}
