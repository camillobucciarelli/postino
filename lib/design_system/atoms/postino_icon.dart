import 'package:flutter/widgets.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_tokens.dart';

/// An icon of [PostinoIcons], colored like the surrounding [IconTheme] unless [color] is given.
/// Decorative unless [label] is given.
class PostinoIcon extends StatelessWidget {
  const PostinoIcon(
    this.icon, {
    super.key,
    this.size = PostinoSize.iconMd,
    this.color,
    this.filled = false,
    this.label,
  });

  final PostinoIconData icon;
  final double size;
  final Color? color;

  /// Fills the shape too (the active Stella).
  final bool filled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(
        icon,
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
        filled,
      ),
    );
    return label == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: label, image: true, child: paint);
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.filled);
  final PostinoIconData icon;
  final Color color;
  final bool filled;

  static final _cache = <PostinoIconData, List<Path>>{};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in _cache.putIfAbsent(
      icon,
      () => icon.paths.map(parseSvgPath).toList(),
    )) {
      if (filled) canvas.drawPath(p, Paint()..color = color);
      canvas.drawPath(p, stroke);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.filled != filled;
}

final _token = RegExp(r'[MmLlHhVvAaZz]|-?(?:\d+\.?\d*|\.\d+)');

/// The subset of SVG path data the icon set uses: M L H V A Z, absolute and relative, with implicit repeats.
@visibleForTesting
Path parseSvgPath(String d) {
  final t = _token.allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  double n() => double.parse(t[i++]);
  while (i < t.length) {
    if (RegExp('[A-Za-z]').hasMatch(t[i])) cmd = t[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0;
    final oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        (startX, startY) = (x, y);
        cmd = rel ? 'l' : 'L'; // further pairs are lines
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
      case 'A':
        final rx = n();
        final ry = n();
        final rotation = n();
        final large = n() != 0;
        final sweep = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        (x, y) = (startX, startY);
    }
  }
  return path;
}
