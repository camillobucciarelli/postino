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

/// [child] fading with [animation]; once that runs backwards the child is on its way out.
class const _Fading({required final Animation<double> animation, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: animation,
    builder: (context, child) {
      final gone = animation.status == AnimationStatus.reverse || animation.isDismissed;
      return IgnorePointer(
        ignoring: gone,
        child: ExcludeSemantics(
          excluding: gone,
          child: ExcludeFocus(excluding: gone, child: child!),
        ),
      );
    },
    child: FadeTransition(opacity: animation, child: child),
  );
}
