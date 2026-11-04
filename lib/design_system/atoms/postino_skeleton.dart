import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The shape of the message list while the first page loads: Comfortable rows, avatar and three bars.
/// Still with reduced motion.
class PostinoSkeleton extends StatefulWidget {
  /// Crea lo scheletro della lista.
  const PostinoSkeleton({super.key, required this.label, this.rows = 4});

  /// Accessible name, e.g. “Caricamento dei messaggi”.
  final String label;

  /// Numero di righe mostrate.
  final int rows;

  @override
  State<PostinoSkeleton> createState() => _PostinoSkeletonState();
}

class _PostinoSkeletonState extends State<PostinoSkeleton> with SingleTickerProviderStateMixin {
  late final _shimmer = AnimationController(vsync: this, duration: PostinoMotion.skeleton);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PostinoMotion.of(context, PostinoMotion.skeleton) == Duration.zero) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = context.density;
    Widget bar({double? size, bool circle = false}) => AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final t = _shimmer.value * 2 - 1; // the highlight sweeps left to right
        return Container(
          width: size,
          height: size ?? PostinoSpacing.s3,
          decoration: BoxDecoration(
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : const BorderRadius.all(Radius.circular(PostinoRadius.xs)),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [c.skeletonBase, c.skeletonHighlight, c.skeletonBase],
            ),
          ),
        );
      },
    );
    return Semantics(
      label: widget.label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              Container(
                constraints: BoxConstraints(minHeight: d.rowHeight),
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: PostinoSpacing.s3),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.borderSubtle)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: d.gap,
                  children: [
                    bar(size: d.avatar, circle: true),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: PostinoSpacing.s1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: PostinoSpacing.s2,
                          children: [
                            for (final f in [
                              .40 + (i * 13) % 30 / 100,
                              .65 + (i * 17) % 25 / 100,
                              .80 + (i * 7) % 15 / 100,
                            ])
                              FractionallySizedBox(widthFactor: f, child: bar()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
