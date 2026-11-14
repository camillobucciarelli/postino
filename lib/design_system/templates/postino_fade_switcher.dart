import 'package:flutter/widgets.dart';

import '../tokens/postino_tokens.dart';

/// A [child] with a new key fades in over the one it replaces, which fades out (#283); the first child is just there.
/// [duration] goes through [PostinoMotion.of], so with reduced motion the swap is instant. The outgoing child is gone
/// already: no taps, no focus, nothing for the screen reader, so a fade never reads twice. Both are top-aligned and
/// take this widget's constraints (a stretched banner stays stretched); while they overlap the taller sets the height.
class const PostinoFadeSwitcher({
  super.key,

  /// Durata della dissolvenza, un token di [PostinoMotion].
  final Duration duration = PostinoMotion.state,

  /// Curva della dissolvenza, un token di [PostinoMotion].
  final Curve curve = PostinoMotion.standard,

  /// Il contenuto attuale: cambiandone la chiave parte la dissolvenza.
  required final Widget child,
}) extends StatelessWidget {
  /// Crea la dissolvenza incrociata tra un contenuto e il successivo.
  this;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: PostinoMotion.of(context, duration),
    switchInCurve: curve,
    switchOutCurve: curve,
    layoutBuilder: (current, previous) =>
        Stack(alignment: Alignment.topCenter, fit: StackFit.passthrough, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => _Fading(animation: animation, child: child),
    child: child,
  );
}

/// [child] fading with [animation]; once that runs backwards the child is on its way out. The status is followed
/// on its own: a reverse() announces it at once, a frame before the value moves.
class const _Fading({required final Animation<double> animation, required final Widget child}) extends StatefulWidget {
  @override
  State<_Fading> createState() => _FadingState();
}

class _FadingState() extends State<_Fading> {
  bool get _gone => widget.animation.status == AnimationStatus.reverse || widget.animation.isDismissed;

  void _changed(AnimationStatus _) => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_changed);
  }

  @override
  void didUpdateWidget(_Fading old) {
    super.didUpdateWidget(old);
    if (old.animation == widget.animation) return;
    old.animation.removeStatusListener(_changed);
    widget.animation.addStatusListener(_changed);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: _gone,
    child: ExcludeSemantics(
      excluding: _gone,
      child: ExcludeFocus(
        excluding: _gone,
        child: FadeTransition(opacity: widget.animation, child: widget.child),
      ),
    ),
  );
}
