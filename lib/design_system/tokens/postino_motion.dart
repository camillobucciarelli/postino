// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Motion: durate e curve. Rispetta MediaQuery.disableAnimations (vedi PostinoMotion.of).
abstract final class PostinoMotion() {
  /// Non istanziabile: solo membri statici.
  this;

  /// Hover, pressione, selezione. Flutter: Durations.short2.
  static const Duration state = Durations.short2;

  /// Switch, checkbox, stella. Flutter: Durations.short3.
  static const Duration toggle = Durations.short3;

  /// Riga che torna in posizione se lo swipe non supera la soglia. Flutter: Durations.short4.
  static const Duration swipeSettle = Durations.short4;

  /// Riga che esce (azione con mouse, tastiera o swipe, o sparita col sync): sfuma e la lista si richiude. Flutter: Durations.medium1.
  static const Duration swipeDismiss = Durations.medium1;

  /// Riga che entra (posta nuova, «Annulla»): l’inverso di [swipeDismiss]. Flutter: Durations.medium1.
  static const Duration rowEnter = Durations.medium1;

  /// Messaggio del thread che si espande/collassa. Flutter: Durations.medium1.
  static const Duration threadExpand = Durations.medium1;

  /// Lista → dettaglio (push). Flutter: Durations.medium2.
  static const Duration routeForward = Durations.medium2;

  /// Dettaglio → lista (pop). Flutter: Durations.medium1.
  static const Duration routeBack = Durations.medium1;

  /// Bottom sheet, drawer modale, composer che sale. Flutter: Durations.medium3.
  static const Duration sheet = Durations.medium3;

  /// Entrata/uscita di snackbar e banner. Flutter: Durations.short4.
  static const Duration snackbar = Durations.short4;

  /// Cambio di vista (fade through, Material 3): uscita, di cui il contenuto non ha più nulla da mostrare (resta il vuoto).
  static const Duration fadeThroughOut = Duration(milliseconds: 90);

  /// Cambio di vista: il contenuto entra con dissolvenza e scala da [fadeThroughScaleBegin] a 1.
  static const Duration fadeThroughIn = Duration(milliseconds: 210);

  /// Scala iniziale del contenuto che entra.
  static const double fadeThroughScaleBegin = 0.96;

  /// L’evidenziazione della voce attiva del menu scorre da una voce all’altra. Curva: PostinoMotion.emphasized.
  static const Duration menuIndicator = Duration(milliseconds: 250);

  /// Ciclo del riflesso dello skeleton. Flutter: Duration(milliseconds: 1200).
  static const Duration skeleton = Duration(milliseconds: 1200);

  /// Un giro dell’icona di SyncStatus mentre la sincronizzazione è in corso; ferma con le animazioni ridotte.
  static const Duration syncSpin = Duration(milliseconds: 1000);

  /// Tempo in cui “Annulla” resta disponibile (invio, archivia, elimina): 10 s, mostrati in conto alla rovescia nella PostinoSnackbar. Flutter: SnackBar.duration.
  static const Duration undoWindow = Duration(seconds: 10);

  /// Default per cambi di stato e dimensione. Flutter: Easing.standard.
  static const Curve standard = Easing.standard;

  /// Elementi che entrano (snackbar, banner). Flutter: Easing.standardDecelerate.
  static const Curve standardDecelerate = Easing.standardDecelerate;

  /// Elementi che escono. Flutter: Easing.standardAccelerate.
  static const Curve standardAccelerate = Easing.standardAccelerate;

  /// Elementi che si spostano sullo schermo (indicatore del menu). Flutter: Curves.easeInOutCubicEmphasized.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Lista → dettaglio, apertura thread, sheet che sale. Flutter: Easing.emphasizedDecelerate.
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;

  /// Dettaglio → lista, sheet che scende. Flutter: Easing.emphasizedAccelerate.
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;

  /// Riga rilasciata dopo lo swipe (segue il dito, poi frena). Flutter: Curves.easeOutCubic.
  static const Curve swipeRelease = Curves.easeOutCubic;

  /// Solo per lo skeleton e le barre di avanzamento. Flutter: Curves.linear.
  static const Curve linear = Curves.linear;

  /// Durata effettiva: zero se l’utente ha chiesto meno animazioni.
  static Duration of(BuildContext context, Duration d) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
