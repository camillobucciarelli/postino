// PROTOTIPO (#106) — variante A: popover con ricerca, stile Gmail «Etichetta come».
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/postino_checkbox_tile.dart';
import 'ds_proposti/postino_text_field.dart';
import 'ds_proposti/proto_icons.dart';
import 'label_flow.dart';
import 'proto_state.dart';

/// The search field (focused), the Etichette filtered as you type with a checkbox each (applied at once),
/// «Crea «testo»» when the text is not an Etichetta. Up/Down move between the rows, Space/Enter tick.
class const PopoverPicker({super.key, required final FakeThread thread}) extends StatefulWidget {
  @override
  State<PopoverPicker> createState() => _PopoverPickerState();
}

class _PopoverPickerState() extends State<PopoverPicker> {
  final _query = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(String name, {required bool on}) {
    final t = widget.thread;
    applyLabels(t, on ? {...t.labels, name} : ({...t.labels}..remove(name)));
  }

  void _create() {
    final error = proto.nameError(_query.text);
    if (error != null) return setState(() => _error = error);
    final name = proto.create(_query.text);
    applyLabels(widget.thread, {...widget.thread.labels, name}, created: [name]);
    _query.clear();
    setState(() {});
  }

  /// Enter in the field: ticks the Etichetta named exactly so, or creates it.
  void _submit(String q) {
    final existing = proto.find(q);
    if (existing == null) return _create();
    _toggle(existing.name, on: !widget.thread.labels.contains(existing.name));
  }

  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final c = context.pc;
    final t = widget.thread;
    final q = _query.text.trim();
    final shown = s.labels.where((l) => l.name.toLowerCase().contains(q.toLowerCase())).toList();
    final canCreate = q.isNotEmpty && s.find(q) == null;
    final n = t.labels.length;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, PostinoSpacing.s3, PostinoSpacing.s4, 0),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: 'Etichette, $n ${n == 1 ? 'selezionata' : 'selezionate'}',
              child: ExcludeSemantics(
                child: Text(
                  'Etichetta come · $n ${n == 1 ? 'selezionata' : 'selezionate'}',
                  style: PostinoText.labelSm.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PostinoSpacing.s3),
            child: PostinoTextField(
              label: 'Cerca o crea un’Etichetta',
              icon: ProtoIcons.search,
              controller: _query,
              autofocus: true,
              helper: _error == null ? nestHelp : null,
              error: _error,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: _submit,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(PostinoSpacing.s2, 0, PostinoSpacing.s2, PostinoSpacing.s2),
              children: [
                for (final l in shown)
                  PostinoCheckboxTile(
                    label: l.name,
                    value: t.labels.contains(l.name),
                    onChanged: (on) => _toggle(l.name, on: on),
                  ),
                if (shown.isEmpty && !canCreate)
                  Padding(
                    padding: const EdgeInsets.all(PostinoSpacing.s3),
                    child: Text('Nessuna Etichetta', style: PostinoText.preview.copyWith(color: c.inkMuted)),
                  ),
                if (canCreate) _CreateRow(name: '«$q»', onTap: _create),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _CreateRow({required final String name, required final VoidCallback onTap}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: PostinoFocusRing(
          inset: true,
          borderRadius: BorderRadius.circular(PostinoRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3, vertical: PostinoSpacing.s2),
              child: Row(
                spacing: PostinoSpacing.s3,
                children: [
                  PostinoIcon(ProtoIcons.plus, color: c.brand),
                  Expanded(
                    child: Text('Crea $name', style: PostinoText.label.copyWith(color: c.brand)),
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
