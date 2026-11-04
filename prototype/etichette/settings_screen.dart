// PROTOTIPO (#106): Impostazioni › Account › Etichette automatiche.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_button.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/atoms/postino_selectable.dart';
import 'package:postino/design_system/organisms/postino_app_bar.dart';
import 'package:postino/design_system/templates/postino_single_pane_layout.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/postino_settings_item.dart';
import 'ds_proposti/postino_switch.dart';
import 'ds_proposti/postino_text_field.dart';
import 'label_flow.dart';
import 'model_status.dart';
import 'proto_state.dart';

class const SettingsScreen({super.key, required final Widget drawer}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final c = context.pc;
    final docked = MediaQuery.sizeOf(context).width >= PostinoSize.breakpointExpanded;
    return PostinoSinglePaneLayout(
      appBar: PostinoAppBar(
        title: 'Etichette automatiche',
        subtitle: 'Impostazioni · $accountName',
        account: account,
        onBack: () => s.update(() => s.page = ProtoPage.posta),
      ),
      drawer: docked ? null : drawer,
      body: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth < PostinoSize.breakpointMedium ? PostinoSpacing.s4 : PostinoSpacing.s6;
          final extra = ((box.maxWidth - PostinoSize.readingMaxWidth) / 2).clamp(0.0, double.infinity);
          return ListView(
            padding: EdgeInsets.fromLTRB(side + extra, PostinoSpacing.s4, side + extra, PostinoSpacing.s16 * 2),
            children: [
              PostinoSelectable(
                child: Text(
                  'Postino può dare un’Etichetta alle email nuove da solo. Il modello gira sul dispositivo: '
                  'le email non escono dal telefono o dal computer. Vale solo per le email che arrivano dopo '
                  'l’attivazione, al massimo un’Etichetta per email, e salta quelle che hanno già un’Etichetta. '
                  'L’Etichetta viene scritta su Gmail, quindi la vedi anche negli altri client.',
                  style: PostinoText.preview.copyWith(color: c.inkMuted),
                ),
              ),
              const SizedBox(height: PostinoSpacing.s4),
              const ModelStatusCard(),
              const SizedBox(height: PostinoSpacing.s6),
              Semantics(
                header: true,
                child: Text('ETICHETTE', style: PostinoText.overline.copyWith(color: c.inkSubtle)),
              ),
              const SizedBox(height: PostinoSpacing.s2),
              for (final l in s.labels) _AutoLabel(key: ValueKey(l.name), label: l),
              const SizedBox(height: PostinoSpacing.s2),
              Align(
                alignment: Alignment.centerLeft,
                child: PostinoButton(
                  label: 'Crea Etichetta',
                  variant: PostinoButtonVariant.ghost,
                  onPressed: () => unawaited(showCreateLabelDialog(context)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One Etichetta: the switch «Automatica»; on, the description field, saved when it loses the focus.
class const _AutoLabel({super.key, required final ProtoLabel label}) extends StatefulWidget {
  @override
  State<_AutoLabel> createState() => _AutoLabelState();
}

class _AutoLabelState() extends State<_AutoLabel> {
  late final _text = TextEditingController(text: widget.label.description);
  final _focus = FocusNode(debugLabel: 'Descrizione');
  Timer? _hide;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_save);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_focus.hasFocus || _text.text == widget.label.description) return;
    widget.label.description = _text.text;
    setState(() => _saved = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _set({required bool on}) {
    proto.update(() => widget.label.auto = on);
    if (on) unawaited(ensureModel(context));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final l = widget.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PostinoSettingsItem(
          title: l.name,
          onTap: () => _set(on: !l.auto),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: PostinoSpacing.s2,
            children: [
              Text('Automatica', style: PostinoText.caption.copyWith(color: c.inkMuted)),
              PostinoSwitch(
                value: l.auto,
                focusable: false,
                onChanged: (on) => _set(on: on),
              ),
            ],
          ),
        ),
        if (l.auto)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PostinoSpacing.s3,
              PostinoSpacing.s1,
              PostinoSpacing.s3,
              PostinoSpacing.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PostinoSpacing.s1,
              children: [
                PostinoTextField(
                  label: 'Descrizione (facoltativa)',
                  helper: 'Descrivi che email ci vanno, es. fatture e ricevute dei fornitori.',
                  controller: _text,
                  focusNode: _focus,
                  multiline: true,
                ),
                Semantics(
                  liveRegion: true,
                  child: _saved
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: PostinoSpacing.s1,
                          children: [
                            PostinoIcon(PostinoIcons.check, size: PostinoSize.iconSm, color: c.success),
                            Text('Descrizione salvata', style: PostinoText.caption.copyWith(color: c.inkMuted)),
                          ],
                        )
                      : const SizedBox(height: PostinoSize.iconSm),
                ),
              ],
            ),
          ),
        Divider(color: c.borderSubtle),
      ],
    );
  }
}
