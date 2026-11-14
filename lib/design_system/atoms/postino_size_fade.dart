import 'package:flutter/widgets.dart';

import '../tokens/postino_tokens.dart';

/// An element that enters or leaves in a column: it fades while its height opens from zero or closes to it, as
/// [visibility] goes 0→1 or 1→0 (curve [PostinoMotion.standard]). Fits `AnimatedList`'s animations, or a controller
/// the owner drives; [kAlwaysCompleteAnimation] for an element at rest. The owner picks the durations from
/// [PostinoMotion] through [PostinoMotion.of], so with reduced motion it skips the animation.
/// A [leaving] element is gone already: no taps, no focus, nothing for the screen reader.
class const PostinoSizeFade({
  super.key,

  /// 1 shown, 0 gone.
  required final Animation<double> visibility,

  /// The element is on its way out.
  final bool leaving = false,

  /// L'elemento che entra o esce.
  required final Widget child,
}) extends StatelessWidget {
  /// Crea l'elemento che entra o esce sfumando e aprendo o chiudendo l'altezza.
  this;

  @override
  Widget build(BuildContext context) {
    final shown = visibility.drive(CurveTween(curve: PostinoMotion.standard));
    return SizeTransition(
      sizeFactor: shown,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: shown,
        child: IgnorePointer(
          ignoring: leaving,
          child: ExcludeSemantics(
            excluding: leaving,
            child: ExcludeFocus(excluding: leaving, child: child),
          ),
        ),
      ),
    );
  }
}
