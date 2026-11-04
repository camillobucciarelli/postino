// PROTOTIPO (#106): the control bar of the prototype — not part of the design.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/proto_icons.dart';
import 'proto_state.dart';

/// A high-contrast pill fixed at the bottom center: variant, network, error, reset, chips, theme, text size, model state.
/// It sits outside the Navigator (no Overlay): no tooltips here.
class const ProtoBar({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final c = context.pc;
    final fg = c.inkInverse;
    void variant(int d) => s.update(() => s.variant = ProtoVariant.values[(s.variant.index + d) % 3]);
    Widget arrow(PostinoIconData icon, String label, int d) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(onPressed: () => variant(d), color: fg, icon: PostinoIcon(icon)),
    );
    Widget toggle(String label, {required bool value, required VoidCallback onTap}) => Semantics(
      toggled: value,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: fg, textStyle: PostinoText.labelSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: PostinoSpacing.s1,
          children: [
            Opacity(
              opacity: value ? 1 : 0,
              child: PostinoIcon(PostinoIcons.check, size: PostinoSize.iconSm, color: fg),
            ),
            Text(label),
          ],
        ),
      ),
    );
    return MediaQuery.withNoTextScaling(
      child: Material(
        color: c.surfaceInverse,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.xl))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3, vertical: PostinoSpacing.s1),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: PostinoSpacing.s1,
            children: [
              Text('PROTOTIPO', style: PostinoText.overline.copyWith(color: fg)),
              arrow(PostinoIcons.chevronLeft, 'Variante precedente', -1),
              Semantics(
                liveRegion: true,
                child: Text('Variante ${s.variant.label}', style: PostinoText.labelSm.copyWith(color: fg)),
              ),
              arrow(ProtoIcons.chevronRight, 'Variante successiva', 1),
              toggle(
                s.cellular ? 'Rete: cellulare' : 'Rete: Wi-Fi',
                value: s.cellular,
                onTap: () {
                  s.setCellular(value: !s.cellular);
                },
              ),
              toggle(
                'Simula errore',
                value: s.simulateError,
                onTap: () => s.update(() => s.simulateError = !s.simulateError),
              ),
              TextButton(
                onPressed: s.resetModel,
                style: TextButton.styleFrom(foregroundColor: fg, textStyle: PostinoText.labelSm),
                child: const Text('Reset modello'),
              ),
              toggle(
                'Chip in lista',
                value: s.chipsInList,
                onTap: () => s.update(() => s.chipsInList = !s.chipsInList),
              ),
              toggle('Tema scuro', value: s.dark, onTap: () => s.update(() => s.dark = !s.dark)),
              toggle('Testo 200%', value: s.large, onTap: () => s.update(() => s.large = !s.large)),
              Text('Modello: ${s.phase.label}', style: PostinoText.meta.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class const _VariantIntent(final int delta) extends Intent {}

class const _LabelsIntent() extends Intent {}

/// ←/→ change variant, `l` opens the Etichette of the open Conversazione: not while typing in a field,
/// not while a popover or dialog is open (Esc first).
class const ProtoShortcuts({super.key, required final Widget child}) extends StatelessWidget {
  static bool _free() {
    final focus = primaryFocus?.context;
    if (focus == null) return true;
    if (!(ModalRoute.of(focus)?.isFirst ?? true)) return false;
    var typing = false;
    focus.visitAncestorElements((e) {
      typing = e is StatefulElement && e.state is TextInputClient;
      return !typing;
    });
    return !typing && !(focus is StatefulElement && focus.state is TextInputClient);
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowLeft): _VariantIntent(-1),
      SingleActivator(LogicalKeyboardKey.arrowRight): _VariantIntent(1),
      SingleActivator(LogicalKeyboardKey.keyL): _LabelsIntent(),
    },
    child: Actions(
      actions: {
        _VariantIntent: _When<_VariantIntent>(
          _free,
          (i) => proto.update(() => proto.variant = ProtoVariant.values[(proto.variant.index + i.delta) % 3]),
        ),
        _LabelsIntent: _When<_LabelsIntent>(() => _free() && proto.openLabels != null, (_) => proto.openLabels!()),
      },
      child: child,
    ),
  );
}

/// An action enabled by [enabled]; disabled, the key goes on (typed in a field, moved in a list).
class _When<T extends Intent>(final bool Function() enabled, final void Function(T) run) extends Action<T> {
  @override
  bool isEnabled(T intent) => enabled();

  @override
  bool consumesKey(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    run(intent);
    return null;
  }
}
