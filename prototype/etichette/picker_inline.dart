// PROTOTIPO (#106) — variante B: chip inline con × e «+ Etichetta» che diventa un campo con suggerimenti.
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/atoms/postino_selectable.dart' show PostinoClearSelectionIntent;
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/postino_add_chip.dart';
import 'ds_proposti/postino_removable_label_chip.dart';
import 'ds_proposti/postino_text_field.dart';
import 'ds_proposti/proto_icons.dart';
import 'label_flow.dart';
import 'proto_state.dart';

/// The Etichette of [thread] as chips with ×, then «+ Etichetta» (or `l`): a field with suggestions and
/// «Crea «testo»»; Enter assigns, Esc cancels. [inPopover]: opened from a list row, the field is open from the start
/// and Esc closes the popover.
class const InlineLabels({super.key, required final FakeThread thread, final bool inPopover = false})
    extends StatefulWidget {
  @override
  State<InlineLabels> createState() => InlineLabelsState();
}

class InlineLabelsState() extends State<InlineLabels> {
  /// Marks the «Crea» option among the names.
  static const _create = '\u0000';

  late bool _editing = widget.inPopover;
  final _field = TextEditingController();
  final _fieldFocus = FocusNode(debugLabel: 'Aggiungi Etichetta');
  final _addFocus = FocusNode(debugLabel: '+ Etichetta');
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    _fieldFocus.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void startEditing() {
    setState(() {
      _editing = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fieldFocus.requestFocus());
  }

  void _stop() {
    if (widget.inPopover) return Navigator.pop(context);
    setState(() {
      _editing = false;
      _error = null;
    });
    _field.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _addFocus.requestFocus());
  }

  Iterable<String> _options(TextEditingValue v) {
    final q = v.text.trim().toLowerCase();
    final t = widget.thread;
    return [
      for (final l in proto.labels)
        if (!t.labels.contains(l.name) && l.name.toLowerCase().contains(q)) l.name,
      if (q.isNotEmpty && proto.find(q) == null) '$_create${v.text.trim()}',
    ];
  }

  void _select(String option) {
    final t = widget.thread;
    if (option.startsWith(_create)) {
      final raw = option.substring(1);
      final error = proto.nameError(raw);
      if (error != null) {
        _field.text = raw;
        return setState(() => _error = error);
      }
      final name = proto.create(raw);
      applyLabels(t, {...t.labels, name}, created: [name]);
    } else {
      applyLabels(t, {...t.labels, option});
    }
    _field.clear();
    if (widget.inPopover) {
      _fieldFocus.requestFocus();
    } else {
      _stop();
    }
  }

  void _remove(String name) {
    final t = widget.thread;
    applyLabels(t, {...t.labels}..remove(name));
    // The × just pressed is gone: the focus goes to «+ Etichetta», or to the field.
    WidgetsBinding.instance.addPostFrameCallback((_) => (_editing ? _fieldFocus : _addFocus).requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    Proto.of(context);
    final c = context.pc;
    final t = widget.thread;
    final names = t.labels.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final n = names.length;
    final field = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: RawAutocomplete<String>(
        textEditingController: _field,
        focusNode: _fieldFocus,
        optionsBuilder: _options,
        displayStringForOption: (o) => o.startsWith(_create) ? o.substring(1) : o,
        onSelected: _select,
        fieldViewBuilder: (context, controller, focus, submit) => PostinoTextField(
          label: 'Aggiungi Etichetta',
          controller: controller,
          focusNode: focus,
          helper: _error == null ? nestHelp : null,
          error: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (v) {
            if (v.trim().isEmpty) return setState(() => _error = 'Scrivi un nome o scegli un’Etichetta.');
            if (proto.find(v) case final l? when t.labels.contains(l.name)) {
              return setState(() => _error = 'La Conversazione ha già l’Etichetta «${l.name}».');
            }
            submit();
          },
        ),
        optionsViewBuilder: (context, onSelected, options) {
          final highlighted = AutocompleteHighlightedOption.of(context);
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: c.surfaceRaised,
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
                side: BorderSide(color: c.borderSubtle),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280, maxWidth: 320),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: PostinoSpacing.s1),
                  children: [
                    for (final (i, o) in options.indexed)
                      Semantics(
                        selected: i == highlighted,
                        child: InkWell(
                          canRequestFocus: false,
                          onTap: () => onSelected(o),
                          child: Container(
                            color: i == highlighted ? c.surfaceHover : null,
                            constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
                            padding: const EdgeInsets.symmetric(
                              horizontal: PostinoSpacing.s4,
                              vertical: PostinoSpacing.s2,
                            ),
                            child: Row(
                              spacing: PostinoSpacing.s3,
                              children: [
                                PostinoIcon(
                                  o.startsWith(_create) ? ProtoIcons.plus : PostinoIcons.tag,
                                  color: o.startsWith(_create) ? c.brand : c.inkMuted,
                                ),
                                Expanded(
                                  child: Text(
                                    o.startsWith(_create) ? 'Crea «${o.substring(1)}»' : o,
                                    style: PostinoText.label.copyWith(color: o.startsWith(_create) ? c.brand : c.ink),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: PostinoSpacing.s1,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: 'Etichette, $n ${n == 1 ? 'selezionata' : 'selezionate'}',
          child: Wrap(
            spacing: PostinoSpacing.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final l in names) PostinoRemovableLabelChip(name: l, onRemove: () => _remove(l)),
              if (!_editing)
                PostinoAddChip(
                  label: 'Etichetta',
                  semanticLabel: 'Aggiungi Etichetta',
                  focusNode: _addFocus,
                  onPressed: startEditing,
                ),
            ],
          ),
        ),
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(top: PostinoSpacing.s2),
            child: field,
          ),
      ],
    );
    // Inside the Conversazione the layout's Esc closes it: while editing, Esc cancels the field first.
    return SelectionContainer.disabled(
      child: _editing && !widget.inPopover
          ? Actions(
              actions: {
                PostinoClearSelectionIntent: CallbackAction<PostinoClearSelectionIntent>(onInvoke: (_) => _stop()),
              },
              child: content,
            )
          : content,
    );
  }
}
