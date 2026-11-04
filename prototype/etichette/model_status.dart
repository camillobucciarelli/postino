// PROTOTIPO (#106): the on-device model's download — the flow, the Impostazioni card, the Posta banner.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_button.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/molecules/postino_banner.dart' show PostinoBannerTone;
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'ds_proposti/postino_dialog.dart';
import 'ds_proposti/postino_progress_banner.dart';
import 'ds_proposti/postino_progress_bar.dart';
import 'proto_state.dart';

/// First activation of an Etichetta automatica: prepares, then downloads on Wi-Fi or asks on cellular.
Future<void> ensureModel(BuildContext context) async {
  if (proto.phase != ModelPhase.assente) return;
  await proto.prepare();
  if (!proto.cellular) return proto.startDownload();
  proto.askCellular();
  if (context.mounted) await confirmCellular(context);
}

/// «Scaricare 310 MB su rete cellulare?»: Scarica ora / Aspetta il Wi-Fi; closed without a choice it stays waiting.
Future<void> confirmCellular(BuildContext context) async {
  final back = FocusManager.instance.primaryFocus;
  final now = await showPostinoDialog<bool>(
    context,
    title: 'Scaricare $modelMb MB su rete cellulare?',
    child: Builder(
      builder: (context) {
        final c = context.pc;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PostinoSpacing.s4,
          children: [
            Text(
              'Le Etichette automatiche usano un modello che gira sul dispositivo. Puoi scaricarlo ora '
              'o aspettare il Wi-Fi: intanto l’interruttore resta attivo e l’Etichettatura parte quando il modello è pronto.',
              style: PostinoText.preview.copyWith(color: c.ink),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: PostinoSpacing.s2,
              runSpacing: PostinoSpacing.s2,
              children: [
                PostinoButton(
                  label: 'Aspetta il Wi-Fi',
                  variant: PostinoButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context, false),
                ),
                PostinoButton(label: 'Scarica ora', onPressed: () => Navigator.pop(context, true)),
              ],
            ),
          ],
        );
      },
    ),
  );
  if (now == true) proto.startDownload();
  if (now == false) proto.waitWifi();
  if (back?.context?.mounted ?? false) back!.requestFocus();
}

/// Title, message (null in download: the bar says it), action of a phase.
({String title, String? message, String? action, VoidCallback? onAction}) _describe(
  BuildContext context,
  ProtoState s,
) => switch (s.phase) {
  ModelPhase.assente => (
    title: 'Modello non scaricato',
    message: 'Si scarica ($modelMb MB) alla prima attivazione di un’Etichetta automatica.',
    action: null,
    onAction: null,
  ),
  ModelPhase.preparazione => (
    title: 'Preparazione del download…',
    message: 'Modello per le Etichette automatiche, $modelMb MB.',
    action: null,
    onAction: null,
  ),
  ModelPhase.confermaCellulare => (
    title: 'In attesa di conferma',
    message: 'Sei su rete cellulare: scaricare $modelMb MB adesso?',
    action: 'Scegli',
    onAction: () => unawaited(confirmCellular(context)),
  ),
  ModelPhase.attesaWifi => (
    title: 'In attesa del Wi-Fi',
    message: 'Il modello ($modelMb MB) si scarica appena sei su Wi-Fi.',
    action: 'Scarica ora',
    onAction: s.startDownload,
  ),
  ModelPhase.download => (
    title: 'Download del modello per le Etichette automatiche',
    message: null,
    action: null,
    onAction: null,
  ),
  ModelPhase.errore => (
    title: 'Download non riuscito: connessione interrotta',
    message: 'Riprova: il download riprende da dove si è fermato.',
    action: 'Riprova',
    onAction: s.startDownload,
  ),
  ModelPhase.pronto => (
    title: 'Modello pronto: le nuove email verranno etichettate',
    message: null,
    action: null,
    onAction: null,
  ),
};

/// The bar and «142 MB di 310 MB · 46%»; the text is out of semantics (it changes at every tick),
/// the bar's value speaks every 25%.
class const _Progress({final Color? track}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final c = context.pc;
    final busy = s.phase == ModelPhase.download;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PostinoSpacing.s1,
      children: [
        PostinoProgressBar(
          label: 'Download del modello',
          value: busy ? s.progress : null,
          semanticsValue: busy ? '${s.steppedPercent}%' : null,
          track: track,
        ),
        if (busy)
          ExcludeSemantics(
            child: Text(s.progressText, style: PostinoText.meta.copyWith(color: c.ink)),
          ),
      ],
    );
  }
}

/// The card on top of Impostazioni › Etichette automatiche: always there, every phase.
class const ModelStatusCard({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final c = context.pc;
    final d = _describe(context, s);
    final progress = s.phase == ModelPhase.download || s.phase == ModelPhase.preparazione;
    final (icon, color) = switch (s.phase) {
      ModelPhase.errore => (PostinoIcons.alert, c.danger),
      ModelPhase.pronto => (PostinoIcons.check, c.success),
      _ => (PostinoIcons.download, c.inkMuted),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(PostinoSpacing.s4),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          border: Border.all(color: s.phase == ModelPhase.errore ? c.danger : c.borderSubtle),
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: PostinoSpacing.s3,
          children: [
            SizedBox.square(
              dimension: PostinoSize.iconLg,
              child: Center(
                child: s.phase == ModelPhase.preparazione
                    ? const PostinoSpinner(label: 'In preparazione')
                    : PostinoIcon(icon, size: PostinoSize.iconLg, color: color),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: PostinoSpacing.s1,
                children: [
                  Text(d.title, style: PostinoText.subject.copyWith(color: c.ink)),
                  if (d.message case final m?) Text(m, style: PostinoText.preview.copyWith(color: c.inkMuted)),
                  if (progress)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: PostinoSpacing.s1),
                      child: _Progress(),
                    ),
                  if (s.phase == ModelPhase.confermaCellulare)
                    Wrap(
                      spacing: PostinoSpacing.s2,
                      runSpacing: PostinoSpacing.s2,
                      children: [
                        PostinoButton(label: 'Scarica ora', size: PostinoButtonSize.sm, onPressed: s.startDownload),
                        PostinoButton(
                          label: 'Aspetta il Wi-Fi',
                          variant: PostinoButtonVariant.ghost,
                          size: PostinoButtonSize.sm,
                          onPressed: s.waitWifi,
                        ),
                      ],
                    )
                  else if (d.action case final a?)
                    PostinoButton(label: a, size: PostinoButtonSize.sm, onPressed: d.onAction),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner above the Posta list: info while preparing, waiting or downloading, danger on error;
/// gone when absent or ready (ready shows the snackbar instead).
class const ModelBanner({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    if (s.phase == ModelPhase.assente || s.phase == ModelPhase.pronto) return const SizedBox.shrink();
    final c = context.pc;
    final d = _describe(context, s);
    final error = s.phase == ModelPhase.errore;
    final cellular = s.phase == ModelPhase.confermaCellulare;
    return PostinoProgressBanner(
      tone: error ? PostinoBannerTone.danger : PostinoBannerTone.info,
      title: d.title,
      message: d.message,
      icon: error ? PostinoIcons.alert : PostinoIcons.download,
      leading: s.phase == ModelPhase.preparazione ? const PostinoSpinner(label: 'In preparazione') : null,
      progress: s.phase == ModelPhase.download || s.phase == ModelPhase.preparazione
          ? _Progress(track: c.surface)
          : null,
      actionLabel: cellular ? 'Scarica ora' : d.action,
      onAction: cellular ? s.startDownload : d.onAction,
      secondaryActionLabel: cellular ? 'Aspetta il Wi-Fi' : null,
      onSecondaryAction: cellular ? s.waitWifi : null,
    );
  }
}
