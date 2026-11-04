// PROTOTIPO (#106): what the three variants share — applying with Annulla, opening the picker, creating.
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_button.dart';
import 'package:postino/design_system/molecules/postino_snackbar.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/postino_dialog.dart';
import 'ds_proposti/postino_popover.dart';
import 'ds_proposti/postino_text_field.dart';
import 'picker_dialog.dart';
import 'picker_inline.dart';
import 'picker_popover.dart';
import 'proto_state.dart';

const nestHelp = 'Usa «/» per annidarla, es. Progetti/Postino.';

/// Sets [next] as the Etichette of [t] at once (optimistic), with the snackbar that undoes it;
/// [created] were created for this, and Annulla deletes them too.
void applyLabels(FakeThread t, Set<String> next, {List<String> created = const []}) {
  final before = {...t.labels};
  final added = next.difference(before);
  final removed = before.difference(next);
  if (added.isEmpty && removed.isEmpty) return;
  proto.update(() {
    t.labels
      ..clear()
      ..addAll(next);
  });
  final message = switch ((added.length, removed.length)) {
    (1, 0) when created.contains(added.single) => 'Etichetta «${added.single}» creata e aggiunta',
    (1, 0) => 'Etichetta «${added.single}» aggiunta',
    (0, 1) => 'Etichetta «${removed.single}» tolta',
    _ => 'Etichette aggiornate: ${added.length} aggiunte, ${removed.length} tolte',
  };
  showUndo(message, () {
    proto.update(() {
      t.labels
        ..clear()
        ..addAll(before);
    });
    if (created.isNotEmpty) proto.deleteLabels(created);
  });
}

void showUndo(String message, VoidCallback undo) => PostinoSnackbar.show(
  appContext,
  message: message,
  actionLabel: 'Annulla',
  onAction: undo,
  until: DateTime.now().add(PostinoMotion.undoWindow),
);

/// The picker of the current variant for [t], anchored to [anchor] (A, and B from the list) or modal (C).
/// When it closes the focus goes back to [returnFocus] (default: the focus when it opened).
Future<void> openLabelPicker(BuildContext anchor, FakeThread t, {FocusNode? returnFocus}) async {
  final back = returnFocus ?? FocusManager.instance.primaryFocus;
  switch (proto.variant) {
    case ProtoVariant.a:
      await showPostinoPopover<void>(
        anchor,
        label: 'Etichette',
        builder: (_) => PopoverPicker(thread: t),
      );
    case ProtoVariant.b:
      await showPostinoPopover<void>(
        anchor,
        label: 'Etichette',
        builder: (_) => Padding(
          padding: const EdgeInsets.all(PostinoSpacing.s3),
          child: InlineLabels(thread: t, inPopover: true),
        ),
      );
    case ProtoVariant.c:
      await showLabelsDialog(anchor, t);
  }
  if (back?.context?.mounted ?? false) back!.requestFocus();
}

/// «Crea Etichetta» outside a Conversazione (Impostazioni): name, «/» help, errors; Annulla in the snackbar.
Future<void> showCreateLabelDialog(BuildContext context) async {
  final back = FocusManager.instance.primaryFocus;
  await showPostinoDialog<void>(context, title: 'Nuova Etichetta', child: const _CreateLabel());
  if (back?.context?.mounted ?? false) back!.requestFocus();
}

class const _CreateLabel() extends StatefulWidget {
  @override
  State<_CreateLabel> createState() => _CreateLabelState();
}

class _CreateLabelState() extends State<_CreateLabel> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final error = proto.nameError(_name.text);
    if (error != null) return setState(() => _error = error);
    final name = proto.create(_name.text);
    Navigator.pop(context);
    showUndo('Etichetta «$name» creata', () => proto.deleteLabels([name]));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: PostinoSpacing.s4,
    children: [
      PostinoTextField(
        label: 'Nome',
        controller: _name,
        autofocus: true,
        helper: nestHelp,
        error: _error,
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _create(),
      ),
      PostinoDialogActions(
        children: [
          PostinoButton(label: 'Annulla', variant: PostinoButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
          PostinoButton(label: 'Crea', onPressed: _create),
        ],
      ),
    ],
  );
}
