// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

/// Scala tipografica (come KeyVault): Caprasimo per i titoli, Figtree per il testo, monospace di sistema per header grezzi. Il colore viene dal tema.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract final class PostinoText() {
  /// Famiglia dei titoli (serif).
  static const serif = 'Caprasimo';

  /// Famiglia del testo (sans).
  static const sans = 'Figtree';

  /// Famiglia monospace per header grezzi.
  static const mono = 'monospace';

  /// Font di ripiego per la monospace.
  static const monoFallback = ['SFMono-Regular', 'Menlo', 'Consolas'];

  /// Titolo grande della schermata, onboarding. Flutter: textTheme.displaySmall.
  static const largeTitle = TextStyle(
    fontFamily: serif,
    fontSize: 34,
    height: 1.1765,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.51,
  );

  /// Titoli di empty state e onboarding. Flutter: headlineMedium.
  static const display = TextStyle(
    fontFamily: serif,
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.45,
  );

  /// Oggetto del thread, titoli di sezione delle impostazioni. Flutter: headlineSmall.
  static const title = TextStyle(
    fontFamily: serif,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.36,
  );

  /// Titolo di dialog e bottom sheet. Flutter: titleLarge.
  static const sheetTitle = TextStyle(
    fontFamily: serif,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
  );

  /// Titolo dell’AppBar compatta, Caprasimo come gli altri titoli. AppBarTheme.titleTextStyle.
  static const appBarTitle = TextStyle(
    fontFamily: serif,
    fontSize: 17,
    height: 1.2941,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.255,
  );

  /// Mittente non letto in lista e header del messaggio. Flutter: titleMedium.
  static const sender = TextStyle(fontFamily: sans, fontSize: 16, height: 1.375, fontWeight: FontWeight.w600);

  /// Mittente letto in lista. Flutter: PostinoText.senderRead.
  static const senderRead = TextStyle(fontFamily: sans, fontSize: 16, height: 1.375, fontWeight: FontWeight.w400);

  /// Oggetto non letto in lista. Flutter: titleSmall.
  static const subject = TextStyle(fontFamily: sans, fontSize: 15, height: 1.3333, fontWeight: FontWeight.w600);

  /// Oggetto letto in lista. Flutter: PostinoText.subjectRead.
  static const subjectRead = TextStyle(fontFamily: sans, fontSize: 15, height: 1.3333, fontWeight: FontWeight.w400);

  /// Anteprima sotto l’oggetto, in ink-muted, 1 riga (Comfortable). Flutter: bodyMedium.
  static const preview = TextStyle(fontFamily: sans, fontSize: 14, height: 1.4286, fontWeight: FontWeight.w400);

  /// Corpo del messaggio e del composer: interlinea 1.625 e misura max reading-max-width per la lettura lunga. Flutter: bodyLarge.
  static const body = TextStyle(fontFamily: sans, fontSize: 16, height: 1.625, fontWeight: FontWeight.w400);

  /// Testo citato, firma e intestazioni di citazione, in ink-muted. Flutter: PostinoText.bodyQuote.
  static const bodyQuote = TextStyle(fontFamily: sans, fontSize: 15, height: 1.6, fontWeight: FontWeight.w400);

  /// Ora, dimensione allegato, conteggio thread; cifre tabellari. Flutter: labelSmall.
  static const meta = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 1.3333,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Ora di un messaggio non letto. Flutter: PostinoText.metaStrong.
  static const metaStrong = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 1.3333,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Bottoni, voci di drawer, tab, voci di menu. Flutter: labelLarge.
  static const label = TextStyle(fontFamily: sans, fontSize: 15, height: 1.3333, fontWeight: FontWeight.w600);

  /// Chip, badge, bottoni piccoli. Flutter: labelMedium.
  static const labelSm = TextStyle(fontFamily: sans, fontSize: 13, height: 1.3846, fontWeight: FontWeight.w600);

  /// Testo di aiuto sotto i campi, stati di sync. Flutter: bodySmall.
  static const caption = TextStyle(fontFamily: sans, fontSize: 12, height: 1.3333, fontWeight: FontWeight.w400);

  /// Intestazioni di gruppo nel drawer, maiuscolo. Flutter: PostinoText.overline.
  static const overline = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 1.2727,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
  );

  /// Header grezzi, codice nel corpo. Famiglia mono. Flutter: PostinoText.code.
  static const code = TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: 13,
    height: 1.5385,
    fontWeight: FontWeight.w400,
  );

  /// `TextTheme` del tema Material costruito dagli stili sopra.
  static const textTheme = TextTheme(
    displaySmall: largeTitle,
    headlineMedium: display,
    headlineSmall: title,
    titleLarge: sheetTitle,
    titleMedium: sender,
    titleSmall: subject,
    bodyLarge: body,
    bodyMedium: preview,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: labelSm,
    labelSmall: meta,
  );
}
