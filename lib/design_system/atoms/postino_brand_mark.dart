// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'postino_brand_mark_painter.dart';

/// The mark of Postino opening once (#267): the flap rises and the letter comes out, ending as `assets/brand/mark.svg`.
/// Decorative: no semantics, no focus. With reduced motion it shows the final pose at once.
class const PostinoBrandMark({
  super.key,

  /// Lato in pixel logici; 128 come il marchio dello splash nativo.
  final double size = 128,

  /// Called once, when the mark has reached its final pose.
  final VoidCallback? onDone,
}) extends StatefulWidget {
  /// Crea il marchio animato.
  this;

  /// One cycle: the flap in 250 ms, the letter in the remaining 650.
  static const Duration duration = Duration(milliseconds: 900);

  @override
  State<PostinoBrandMark> createState() => _PostinoBrandMarkState();
}

class _PostinoBrandMarkState() extends State<PostinoBrandMark> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: PostinoBrandMark.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isDismissed) return;
    // ponytail: read once at the start; reduced motion turned on mid-cycle lets the 900 ms finish.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      // After the frame: onDone may rebuild the widget that is building this one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone?.call();
      });
    } else {
      _controller
        ..addStatusListener((status) {
          if (status.isCompleted) widget.onDone?.call();
        })
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(widget.size), painter: PostinoBrandMarkPainter(_controller)),
  );
}
