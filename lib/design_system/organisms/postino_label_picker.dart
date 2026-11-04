import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/postino_checkbox_tile.dart';
import '../atoms/postino_text_field.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_label_create_row.dart';
import 'postino_label_picker_strings.dart';

export 'postino_label_picker_strings.dart';

/// The picker of the etichette of a Conversazione, the content of a showPostinoPopover: the field
/// «Cerca o crea un'Etichetta» (focused), then [labels] filtered as you type, a PostinoCheckboxTile each,
/// ticked when in [selected]; when the text is not exactly an etichetta (ignoring case) the last row creates it.
/// Pure UI: [onToggle] and [onCreate] apply at once, the caller rebuilds it with the new [selected].
/// Keyboard: Tab goes from the field to the list, Up/Down move between the rows, Space/Enter tick; Enter in the
/// field ticks the exact match or creates. A name refused by [validateName] shows its error (a live region);
/// the count of the selected is a live region too, «Etichette, 2 selezionate».
class const PostinoLabelPicker({
  super.key,

  /// Le etichette dell'Account, nell'ordine mostrato.
  required final List<PostinoLabelOption> labels,

  /// Id delle etichette spuntate.
  required final Set<String> selected,

  /// Spunta o toglie la spunta all'etichetta con questo id.
  required final ValueChanged<String> onToggle,

  /// Crea l'etichetta con questo nome (già valido) e la assegna.
  required final ValueChanged<String> onCreate,

  /// The error that refuses a new name (empty, existing, an empty level), null when it is valid.
  required final String? Function(String name) validateName,

  /// I testi del selettore.
  required final PostinoLabelPickerStrings strings,
}) extends StatefulWidget {
  /// Crea il selettore.
  this;

  @override
  State<PostinoLabelPicker> createState() => _PostinoLabelPickerState();
}

class _PostinoLabelPickerState() extends State<PostinoLabelPicker> {
  final _query = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  PostinoLabelOption? _exact(String q) =>
      widget.labels.where((l) => l.name.toLowerCase() == q.toLowerCase()).firstOrNull;

  void _create() {
    final error = widget.validateName(_query.text);
    if (error != null) return setState(() => _error = error);
    widget.onCreate(_query.text.trim());
    _query.clear();
    setState(() {});
  }

  /// Enter in the field: ticks the etichetta named exactly so (one already ticked stays so), or creates it.
  void _submit(String text) {
    final exact = _exact(text.trim());
    if (exact == null) return _create();
    if (!widget.selected.contains(exact.id)) widget.onToggle(exact.id);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final c = context.pc;
    final s = w.strings;
    final q = _query.text.trim();
    final shown = w.labels.where((l) => l.name.toLowerCase().contains(q.toLowerCase())).toList();
    final canCreate = q.isNotEmpty && _exact(q) == null;
    final count = s.selected(w.labels.where((l) => w.selected.contains(l.id)).length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, PostinoSpacing.s3, PostinoSpacing.s4, 0),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: count,
            child: ExcludeSemantics(
              child: SelectionContainer.disabled(
                child: Text(count, style: PostinoText.labelSm.copyWith(color: c.inkMuted)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(PostinoSpacing.s3),
          child: PostinoTextField(
            key: const ValueKey('label-search'),
            label: s.search,
            icon: PostinoIcons.search,
            controller: _query,
            autofocus: true,
            helper: s.nestHelp,
            error: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: _submit,
          ),
        ),
        Flexible(
          // Up/Down move between the rows (and from the first back to the field); Tab still works.
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
            },
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(PostinoSpacing.s2, 0, PostinoSpacing.s2, PostinoSpacing.s2),
              children: [
                for (final l in shown)
                  PostinoCheckboxTile(
                    key: ValueKey('label-${l.id}'),
                    label: l.name,
                    value: w.selected.contains(l.id),
                    onChanged: (_) => w.onToggle(l.id),
                  ),
                if (shown.isEmpty && !canCreate)
                  Padding(
                    padding: const EdgeInsets.all(PostinoSpacing.s3),
                    child: Text(s.empty, style: PostinoText.preview.copyWith(color: c.inkMuted)),
                  ),
                if (canCreate)
                  PostinoLabelCreateRow(key: const ValueKey('label-create'), label: s.create(q), onTap: _create),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
