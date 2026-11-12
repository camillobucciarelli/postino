import 'package:flutter/foundation.dart' show listEquals;
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

class _PostinoSuggestionsState() extends State<PostinoSuggestions> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Always shown, empty while there is nothing to suggest: show() may not be called while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  void didUpdateWidget(PostinoSuggestions old) {
    super.didUpdateWidget(old);
    final s = widget.suggestions;
    if (s.isEmpty) return;
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => widget.suggestions.isEmpty
          ? const SizedBox.shrink()
          : CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              showWhenUnlinked: false,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: box.maxWidth, child: _panel(context)),
              ),
            ),
      child: Actions(
        actions: {PostinoClearSelectionIntent: _Dismiss(() => widget.suggestions.isNotEmpty, () => widget.onDismiss())},
        child: CompositedTransformTarget(link: _link, child: widget.child),
      ),
    ),
  );

  Widget _panel(BuildContext context) {
    final c = context.pc;
    final s = widget.suggestions;
    // A tap here is inside the field: it keeps the focus (and its keyboard on a phone).
    return TextFieldTapRegion(
      child: Material(
        color: c.surfaceRaised,
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
          side: BorderSide(color: c.borderSubtle),
        ),
        // At text 200% the rows grow: the panel scrolls, the highlighted row kept in view.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
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
                      key: ValueKey(('suggestion', i, i == widget.highlighted)),
                      suggestion: item,
                      highlighted: i == widget.highlighted,
                      onTap: () => widget.onSelected(i),
                    ),
                ],
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
