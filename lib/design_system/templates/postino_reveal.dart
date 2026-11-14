import 'package:flutter/widgets.dart';

import '../tokens/postino_tokens.dart';
import 'postino_fade_switcher.dart';
import 'postino_size_fade.dart';

/// An element of a column that comes and goes (#283), a banner above the list say: when [child] goes from null to a
/// widget it opens and fades in, when it goes back to null it closes and fades out, still drawn as it last was
/// ([PostinoSizeFade], over [duration]). What the first build shows is just there, unless [appear] (an element added
/// to a column already on screen) opens it. While shown, a new [contentKey]
/// fades the new content over the old ([PostinoFadeSwitcher]) and the height follows the content. Every duration
/// goes through [PostinoMotion.of]: with reduced motion all of it is instant.
class const PostinoReveal({
  super.key,

  /// L'elemento mostrato; null: nascosto.
  final Widget? child,

  /// Cosa mostra l'elemento: cambiandolo, il contenuto nuovo sfuma su quello vecchio.
  final Object? contentKey,

  /// Durata dell'entrata, dell'uscita e della dissolvenza, un token di [PostinoMotion].
  final Duration duration = PostinoMotion.snackbar,

  /// Apre anche il primo [child]: un elemento aggiunto a una colonna già sullo schermo.
  final bool appear = false,
}) extends StatefulWidget {
  /// Crea l'elemento che entra ed esce in una colonna.
  this;

  @override
  State<PostinoReveal> createState() => _PostinoRevealState();
}

class _PostinoRevealState() extends State<PostinoReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _visibility;

  /// The content keeps its State (a focused «Riprova») when AnimatedSize comes or goes with reduced motion.
  final _content = GlobalKey();

  /// What was shown last, drawn while it leaves.
  Widget? _last;
  Object? _lastKey;

  @override
  void initState() {
    super.initState();
    _last = widget.child;
    _lastKey = widget.contentKey;
    // At rest from the first build, unless asked to appear: what is there at the start does not animate.
    _visibility = AnimationController(vsync: this, value: widget.child == null || widget.appear ? 0 : 1)
      ..addStatusListener((s) {
        // Closed: the last content leaves the tree (a spinner in it would tick for nothing).
        if (s.isDismissed && mounted) setState(() {});
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The duration needs the MediaQuery, which initState cannot read.
    if (widget.appear && widget.child != null && _visibility.isDismissed) _move();
  }

  @override
  void didUpdateWidget(PostinoReveal old) {
    super.didUpdateWidget(old);
    _move();
  }

  void _move() {
    final d = PostinoMotion.of(context, widget.duration);
    _visibility
      ..duration = d
      ..reverseDuration = d;
    if (widget.child case final c?) {
      _last = c;
      _lastKey = widget.contentKey;
      _visibility.forward();
    } else {
      _visibility.reverse();
    }
  }

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? _last;
    if (child == null || _visibility.isDismissed) return const SizedBox.shrink();
    final content = KeyedSubtree(
      key: _content,
      child: PostinoFadeSwitcher(
        duration: widget.duration,
        child: KeyedSubtree(key: ValueKey(_lastKey), child: child),
      ),
    );
    return PostinoSizeFade(
      visibility: _visibility,
      leaving: widget.child == null,
      // ponytail: AnimatedSize cannot take a zero duration (it would relayout inside its own layout), so with reduced
      // motion it is left out; the content moves with its GlobalKey, State and focus kept.
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : AnimatedSize(
              duration: widget.duration,
              curve: PostinoMotion.standard,
              alignment: Alignment.topCenter,
              child: content,
            ),
    );
  }
}
