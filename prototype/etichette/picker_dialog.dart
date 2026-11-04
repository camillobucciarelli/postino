// PROTOTIPO (#106) — variante C: pannello modale, le modifiche valgono solo con Applica.
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_button.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/postino_checkbox_tile.dart';
import 'ds_proposti/postino_dialog.dart';
import 'ds_proposti/postino_text_field.dart';
import 'label_flow.dart';
import 'proto_state.dart';

/// «Etichette della Conversazione»: every Etichetta with a checkbox, «Nuova Etichetta» + Crea at the bottom,
/// Annulla / Applica. A dialog from 600, a bottom sheet below.
Future<void> showLabelsDialog(BuildContext context, FakeThread t) => showPostinoDialog<void>(
  context,
  title: 'Etichette della Conversazione',
  child: _LabelsPanel(thread: t),
);

class const _LabelsPanel({required final FakeThread thread}) extends StatefulWidget {
  @override
  State<_LabelsPanel> createState() => _LabelsPanelState();
}

class _LabelsPanelState() extends State<_LabelsPanel> {
  late final _draft = {...widget.thread.labels};

  /// Created here, real only on Applica.
  final _pending = <String>[];
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final error = proto.nameError(_name.text, pending: _pending);
    if (error != null) return setState(() => _error = error);
    final name = ProtoState.normalize(_name.text);
    setState(() {
      _pending.add(name);
      _draft.add(name);
      _name.clear();
    });
  }

  void _apply() {
    for (final n in _pending) {
      proto.create(n);
    }
    applyLabels(widget.thread, _draft, created: _pending);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final c = context.pc;
    final names = [...s.labels.map((l) => l.name), ..._pending]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final n = _draft.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s3,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: 'Etichette, $n ${n == 1 ? 'selezionata' : 'selezionate'}',
          child: ExcludeSemantics(
            child: Text(
              '$n ${n == 1 ? 'selezionata' : 'selezionate'} · le modifiche valgono con Applica',
              style: PostinoText.caption.copyWith(color: c.inkMuted),
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final name in names)
                PostinoCheckboxTile(
                  label: _pending.contains(name) ? '$name (nuova)' : name,
                  value: _draft.contains(name),
                  onChanged: (on) => setState(() => on ? _draft.add(name) : _draft.remove(name)),
                ),
            ],
          ),
        ),
        Divider(color: c.borderSubtle),
        Wrap(
          spacing: PostinoSpacing.s2,
          runSpacing: PostinoSpacing.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: PostinoTextField(
                label: 'Nuova Etichetta',
                controller: _name,
                helper: _error == null ? nestHelp : null,
                error: _error,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _create(),
              ),
            ),
            PostinoButton(label: 'Crea', variant: PostinoButtonVariant.ghost, onPressed: _create),
          ],
        ),
        PostinoDialogActions(
          children: [
            PostinoButton(
              label: 'Annulla',
              variant: PostinoButtonVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
            PostinoButton(label: 'Applica', onPressed: _apply),
          ],
        ),
      ],
    );
  }
}
