import 'package:flutter/widgets.dart';

import '../../../design_system/design_system.dart';
import 'row_motion.dart';

/// A column of [children] that come and go (#283), each told apart by its key: a new one opens and fades in, one
/// gone stays drawn at its place while it fades and closes, out of reach ([RowMotion], [PostinoSizeFade]). What the
/// first build shows is just there; a column empty at first opens its first children too. [duration] goes through
/// [PostinoMotion.of]: with reduced motion all of it is instant.
class const RevealColumn({
  super.key,

  /// Entrata e uscita, un token di [PostinoMotion].
  final Duration duration = PostinoMotion.snackbar,

  /// Each with a key of its own (a ValueKey), stable while it is shown.
  required final List<Widget> children,
}) extends StatefulWidget {
  @override
  State<RevealColumn> createState() => _RevealColumnState();
}

class _RevealColumnState() extends State<RevealColumn> with TickerProviderStateMixin {
  late final _motion = RowMotion<Widget>(this, () => mounted ? setState(() {}) : null, (w) => w.key!, fromEmpty: true);

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = PostinoMotion.of(context, widget.duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in _motion.update(widget.children, enter: d, leave: d)!)
          PostinoSizeFade(key: w.key, visibility: _motion.of(w.key!), leaving: _motion.leaving(w.key!), child: w),
      ],
    );
  }
}
