import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../atoms/postino_selectable.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One suggestion: a display name, if any, and an address.
typedef PostinoSuggestion = ({String? name, String address});

/// The suggestions of a field while typing (Contatti, #216): a panel under [child], as wide as it, `surface-raised`,
/// `radius-md`, `border-subtle` like PostinoMenu, open while [suggestions] is not empty. It never takes the focus:
/// the field keeps it and moves [highlighted] (`surface-selected`) with its keys; a tap chooses too ([onSelected]).
/// The first Esc closes it ([onDismiss]) before the page it is on, like a selection (PostinoClearSelectionIntent).
/// Screen readers hear [countLabel] when the list opens or changes, and the highlighted entry as it moves, read as
/// «Name, address».
/// The panel opens and fades in, and closes and fades out still showing what it showed (#283, [PostinoMotion.state]);
/// its height follows the list. The opening is inside the Material, so its shadow is never cut; a closing panel takes
/// no taps and is not read.
class const PostinoSuggestions({
  super.key,

  /// Il campo sotto cui compare l'elenco.
  required final Widget child,

  /// I suggerimenti, il migliore per primo; vuoto: elenco chiuso.
  required final List<PostinoSuggestion> suggestions,

  /// L'indice del suggerimento evidenziato.
  required final int highlighted,

  /// Chiamata con l'indice del suggerimento scelto con un tocco.
  required final ValueChanged<int> onSelected,

  /// Quanti suggerimenti ci sono, già tradotto («3 suggerimenti»).
  required final String countLabel,

  /// Chiamata quando Esc chiude l'elenco.
  required final VoidCallback onDismiss,
}) extends StatefulWidget {
  /// Crea l'elenco dei suggerimenti di un campo.
  this;

  /// The spoken label of [s]: «Name, address», or the address alone.
  static String labelOf(PostinoSuggestion s) => s.name == null ? s.address : '${s.name}, ${s.address}';

  @override
  State<PostinoSuggestions> createState() => _PostinoSuggestionsState();
}

class _PostinoSuggestionsState() extends State<PostinoSuggestions> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _scroll = ScrollController();

  late final AnimationController _open;
  late final CurvedAnimation _shown;

  /// The list drawn: the suggestions, or the last ones while the panel closes.
  late ({List<PostinoSuggestion> list, int highlighted}) _drawn;

  @override
  void initState() {
    super.initState();
    _drawn = (list: widget.suggestions, highlighted: widget.highlighted);
    // Open from the first build if there is something to suggest: it does not animate.
    _open = AnimationController(vsync: this, value: widget.suggestions.isEmpty ? 0 : 1)
      ..addStatusListener((s) {
        if (s.isDismissed && mounted) setState(() {});
      });
    _shown = CurvedAnimation(
      parent: _open,
      curve: PostinoMotion.standardDecelerate,
      reverseCurve: PostinoMotion.standardAccelerate,
    );
    // Always shown, empty while there is nothing to suggest: show() may not be called while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  void didUpdateWidget(PostinoSuggestions old) {
    super.didUpdateWidget(old);
    final s = widget.suggestions;
    final d = PostinoMotion.of(context, PostinoMotion.state);
    _open
      ..duration = d
      ..reverseDuration = d;
    if (s.isEmpty) {
      _open.reverse();
      return;
    }
    _drawn = (list: s, highlighted: widget.highlighted);
    _open.forward();
    if (!listEquals(s, old.suggestions)) {
      _announce(widget.countLabel);
    } else if (widget.highlighted != old.highlighted) {
      _announce(PostinoSuggestions.labelOf(s[widget.highlighted]));
    }
  }

  void _announce(String message) =>
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));

  @override
  void dispose() {
    _shown.dispose();
    _open.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  // The layout builder runs at every layout of the field: the panel follows it while the composer scrolls.
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _portal,
    overlayChildBuilder: (context, info) {
      if (_open.isDismissed) return const SizedBox.shrink();
      final field = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
      final (:above, :height) = _room(MediaQuery.of(context), field, info.overlaySize);
      return Stack(
        children: [
          Positioned(
            left: field.left,
            width: field.width,
            top: above ? null : field.bottom,
            bottom: above ? info.overlaySize.height - field.top : null,
            child: _panel(context, height, above: above),
          ),
        ],
      );
    },
    child: Actions(
      actions: {PostinoClearSelectionIntent: _Dismiss(() => widget.suggestions.isNotEmpty, () => widget.onDismiss())},
      child: widget.child,
    ),
  );

  static const _maxHeight = 360.0;

  /// Where the panel fits next to the [field] (in the overlay): under it, down to the keyboard (or the window's
  /// bottom); above it when there is less room under it than three rows and more above (Cc and Ccn on a phone with
  /// the keyboard open). Never behind the keyboard or the status bar; at least one row.
  static ({bool above, double height}) _room(MediaQueryData mq, Rect field, Size overlay) {
    final below = overlay.height - mq.viewInsets.bottom - PostinoSpacing.s2 - field.bottom;
    final over = field.top - mq.padding.top - PostinoSpacing.s2;
    final above = below < math.min(_maxHeight, 3 * PostinoSize.touchTargetAndroid) && over > below;
    return (above: above, height: (above ? over : below).clamp(PostinoSize.touchTargetAndroid, _maxHeight));
  }

  /// The list's height follows it; not with reduced motion (AnimatedSize cannot take a zero duration).
  static Widget _sized(BuildContext context, Alignment from, Widget child) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(duration: PostinoMotion.state, curve: PostinoMotion.standard, alignment: from, child: child);

  Widget _panel(BuildContext context, double maxHeight, {required bool above}) {
    // It opens from the field: down from its top under it, up from its bottom above it.
    final from = above ? Alignment.bottomCenter : Alignment.topCenter;
    final c = context.pc;
    final (list: s, :highlighted) = _drawn;
    final closing = widget.suggestions.isEmpty;
    // A tap here is inside the field: it keeps the focus (and its keyboard on a phone).
    return TextFieldTapRegion(
      child: FadeTransition(
        opacity: _shown,
        child: IgnorePointer(
          ignoring: closing,
          child: ExcludeSemantics(
            excluding: closing,
            child: Material(
              color: c.surfaceRaised,
              elevation: PostinoElevation.e3,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
                side: BorderSide(color: c.borderSubtle),
              ),
              // At text 200% the rows grow: the panel scrolls, the highlighted row kept in view.
              child: SizeTransition(
                sizeFactor: _shown,
                alignment: from,
                child: _sized(
                  context,
                  from,
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: PostinoSpacing.s1),
                      child: Semantics(
                        explicitChildNodes: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, item) in s.indexed)
                              _Row(
                                key: ValueKey(('suggestion', i, i == highlighted)),
                                suggestion: item,
                                highlighted: i == highlighted,
                                onTap: () => widget.onSelected(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dismiss(final bool Function() _open, final VoidCallback _close) extends Action<PostinoClearSelectionIntent> {
  @override
  bool isEnabled(PostinoClearSelectionIntent intent) => _open();

  @override
  Object? invoke(PostinoClearSelectionIntent intent) {
    _close();
    return null;
  }
}

class const _Row({
  super.key,
  required final PostinoSuggestion suggestion,
  required final bool highlighted,
  required final VoidCallback onTap,
}) extends StatefulWidget {
  @override
  State<_Row> createState() => _RowState();
}

class _RowState() extends State<_Row> {
  @override
  void initState() {
    super.initState();
    // The key changes with the highlight: a newly highlighted row scrolls into view.
    if (widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final s = widget.suggestion;
    return Semantics(
      button: true,
      selected: widget.highlighted,
      label: PostinoSuggestions.labelOf(s),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
            color: widget.highlighted ? c.surfaceSelected : null,
            padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: PostinoSpacing.s2),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.name case final name?) Text(name, style: PostinoText.label.copyWith(color: c.ink)),
                Text(s.address, style: PostinoText.preview.copyWith(color: s.name == null ? c.ink : c.inkMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
