import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/auto_label.dart';
import '../../../core/domain/auto_labels_repository.dart';
import '../../../core/domain/message.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/auto_label_switch_use_case.dart';

/// One Etichetta of the page: the «Automatica» switch, named by the Etichetta, and, with it on, the optional description,
/// which opens and closes (#283).
class const AutoLabelTile({
  super.key,
  required final String accountId,
  required final Label label,
  required final AutoLabel config,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PostinoSwitchRow(
        title: label.name,
        description: context.t.etichetteAutomatiche.automatic,
        value: config.automatic,
        onChanged: (on) =>
            unawaited(GetIt.I<AutoLabelSwitchUseCase>().setAutomatic(accountId, label.id, automatic: on)),
      ),
      PostinoReveal(
        duration: PostinoMotion.toggle,
        child: config.automatic
            ? Padding(
                padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, 0, PostinoSpacing.s4, PostinoSpacing.s3),
                child: _DescriptionField(accountId: accountId, labelId: label.id, saved: config.description),
              )
            : null,
      ),
    ],
  );
}

/// «Descrizione (facoltativa)»: saved when it loses the focus, then «Descrizione salvata» in a live region.
class const _DescriptionField({
  required final String accountId,
  required final String labelId,
  required final String? saved,
}) extends StatefulWidget {
  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState() extends State<_DescriptionField> {
  late final _text = TextEditingController(text: widget.saved);
  final _focus = FocusNode();

  /// What was last saved (or read); only a different text is saved again. Set in [initState], not lazily: read
  /// first after an update, a lazy initializer would take the new value.
  late String _kept;
  var _announce = false;

  @override
  void initState() {
    super.initState();
    _kept = widget.saved ?? '';
    _focus.addListener(() {
      if (!_focus.hasFocus) unawaited(_save());
    });
  }

  @override
  void didUpdateWidget(_DescriptionField old) {
    super.didUpdateWidget(old);
    // A description synced from another device shows here, unless the user is editing a different one.
    final saved = widget.saved ?? '';
    if (saved == (old.saved ?? '') || _text.text.trim() != _kept) return;
    _kept = saved;
    if (_text.text != saved) _text.text = saved;
  }

  /// Saves a changed text; false when there was nothing new.
  Future<bool> _persist() async {
    final text = _text.text.trim();
    if (text == _kept) return false;
    _kept = text;
    await GetIt.I<AutoLabelsRepository>().setDescription(widget.accountId, widget.labelId, text);
    return true;
  }

  Future<void> _save() async {
    if (await _persist() && mounted) setState(() => _announce = true);
  }

  @override
  void dispose() {
    // Switched off while typing: the field goes away without a blur, and the description is kept.
    unawaited(_persist());
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.etichetteAutomatiche;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s1,
      children: [
        PostinoTextField(
          label: t.description,
          helper: t.descriptionHelp,
          controller: _text,
          focusNode: _focus,
          multiline: true,
          onChanged: (_) {
            if (_announce) setState(() => _announce = false);
          },
        ),
        Semantics(
          container: true,
          liveRegion: true,
          child: PostinoReveal(
            duration: PostinoMotion.state,
            child: _announce
                ? Text(t.descriptionSaved, style: PostinoText.caption.copyWith(color: context.pc.inkMuted))
                : null,
          ),
        ),
      ],
    );
  }
}
