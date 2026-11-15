import 'package:flutter/widgets.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The unread dot of the drawer (8 px, `unread`; not in the barrel): where the semantics around it already say it,
/// decorative; else it reads [label] itself.
class const PostinoUnreadDot({
  super.key,

  /// Nome letto dallo screen reader; nullo: decorativo.
  final String? label,
}) extends StatelessWidget {
  /// Crea il puntino dei non letti.
  this;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      key: const ValueKey('unread-dot'),
      width: PostinoSpacing.s2,
      height: PostinoSpacing.s2,
      decoration: BoxDecoration(color: context.pc.unread, shape: BoxShape.circle),
    );
    return label == null ? ExcludeSemantics(child: dot) : Semantics(label: label, child: dot);
  }
}
