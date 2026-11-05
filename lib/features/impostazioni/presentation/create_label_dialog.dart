import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/label_name.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// «Crea Etichetta»: asks for the name, refuses an invalid one in place, and creates the Etichetta on the Provider
/// (not queued: offline it says so and stays open). [existing] are the names already in use.
Future<void> showCreateLabelDialog(BuildContext context, String accountId, Iterable<String> existing) =>
    showPostinoDialog<void>(
      context,
      title: context.t.etichetteAutomatiche.createTitle,
      child: _CreateLabelForm(accountId: accountId, existing: existing),
    );

class const _CreateLabelForm({required final String accountId, required final Iterable<String> existing})
    extends StatefulWidget {
  @override
  State<_CreateLabelForm> createState() => _CreateLabelFormState();
}

class _CreateLabelFormState() extends State<_CreateLabelForm> {
  final _name = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final t = context.t.etichetteAutomatiche;
    final navigator = Navigator.of(context);
    final invalid = labelNameError(_name.text, widget.existing);
    if (invalid != null) {
      setState(
        () => _error = switch (invalid) {
          LabelNameError.empty => t.errorEmpty,
          LabelNameError.emptyLevel => t.errorEmptyLevel,
          LabelNameError.duplicate => t.errorDuplicate,
        },
      );
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final result = await GetIt.I<MailSync>().createLabel(widget.accountId, _name.text.trim());
    if (!mounted) return;
    switch (result) {
      case Ok():
        navigator.pop();
      case Err():
        setState(() {
          _busy = false;
          _error = t.createFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.etichetteAutomatiche;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        PostinoTextField(
          label: t.createName,
          controller: _name,
          helper: t.createHelp,
          error: _error,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _busy ? null : _create(),
        ),
        PostinoDialogActions(
          children: [
            PostinoButton(
              label: t.createCancel,
              variant: PostinoButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
            PostinoButton(label: t.createAction, onPressed: _busy ? null : _create),
          ],
        ),
      ],
    );
  }
}
