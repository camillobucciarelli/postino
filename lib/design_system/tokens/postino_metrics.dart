// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.

/// Scala di spaziatura (padding, gap, margini).
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract final class PostinoSpacing() {
  /// Distanza fra badge account e avatar; micro-aggiustamenti.
  static const double s0_5 = 2;

  /// Gap icona–testo in chip e badge.
  static const double s1 = 4;

  /// Gap fra icona ed etichetta nei bottoni; padding verticale Compact.
  static const double s2 = 8;

  /// Gap fra colonne della riga; padding verticale Comfortable.
  static const double s3 = 12;

  /// Margine laterale mobile; padding di card e sheet.
  static const double s4 = 16;

  /// Padding orizzontale del composer.
  static const double s5 = 20;

  /// Margine laterale tablet/desktop; padding dei dialog.
  static const double s6 = 24;

  /// Fra messaggi espansi di un thread; padding degli empty state.
  static const double s8 = 32;

  /// Spazio sopra gli empty state.
  static const double s10 = 40;

  /// Padding superiore del dettaglio su desktop.
  static const double s12 = 48;

  /// Onboarding: aria fra blocchi.
  static const double s16 = 64;
}

/// Raggi degli angoli.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract final class PostinoRadius() {
  /// Checkbox, tasti scorciatoia.
  static const double xs = 4;

  /// Bottoni, input, voci di drawer, chip etichetta.
  static const double sm = 8;

  /// Card, menu, snackbar, chip allegato, banner.
  static const double md = 12;

  /// FAB, composer, dialog.
  static const double lg = 16;

  /// Angoli superiori del bottom sheet; SearchBar M3.
  static const double xl = 28;

  /// Avatar, badge, chip contatto e filtro, pallino non letto.
  static const double full = 999;
}

/// Dimensioni fisse di componenti e breakpoint.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract final class PostinoSize() {
  /// Area minima di tocco su iOS (HIG). Flutter: kMinInteractiveDimensionCupertino.
  static const double touchTargetIos = 44;

  /// Area minima di tocco su Android (M3). Flutter: kMinInteractiveDimension.
  static const double touchTargetAndroid = 48;

  /// Icone dentro chip, righe e meta.
  static const double iconSm = 16;

  /// Icone in bottoni e campi.
  static const double iconMd = 20;

  /// Icone di AppBar, drawer, swipe, bulk bar.
  static const double iconLg = 24;

  /// Bottoni piccoli e chip (area di tocco estesa a 44/48 con padding).
  static const double controlSm = 32;

  /// Bottoni, input, SearchBar.
  static const double controlMd = 40;

  /// Bottoni di onboarding e dialog su mobile.
  static const double controlLg = 48;

  /// Altezza AppBar (Android 64 con titolo grande: usa large-title).
  static const double appBarHeight = 56;

  /// FAB “Scrivi” esteso.
  static const double fabHeight = 56;

  /// Avatar in chip contatto e riga Compact.
  static const double avatarSm = 24;

  /// Avatar in riga Comfortable e header del messaggio.
  static const double avatarMd = 40;

  /// Avatar nel selettore account e nelle impostazioni.
  static const double avatarLg = 56;

  /// Badge account sull’avatar (iniziale a 10px).
  static const double accountBadge = 16;

  /// AccountMark standalone: drawer, selettore “Da”, filtri.
  static const double accountMark = 24;

  /// NavigationDrawer modale su mobile.
  static const double drawerWidth = 304;

  /// Drawer fisso su desktop.
  static const double sidebarWidth = 280;

  /// Barra laterale ridotta a sole icone (sotto breakpoint-sidebar-collapse).
  static const double sidebarCollapsedWidth = 72;

  /// Colonna lista su tablet/desktop (min 320).
  static const double listWidth = 380;

  /// Larghezza minima della lista ridimensionabile (list-width-min).
  static const double listWidthMin = 280;

  /// Massimo della lista: questa frazione della finestra (list-width-max-fraction).
  static const double listWidthMaxFraction = 0.5;

  /// Passo del divisore da tastiera e VoiceOver (list-width-step).
  static const double listWidthStep = 16;

  /// Area attiva del divisore tra lista e dettaglio (resize-handle-width).
  static const double resizeHandleWidth = 8;

  /// Maniglia visibile al centro del divisore (resize-grip).
  static const double resizeGripWidth = 4;

  /// Altezza della maniglia visibile del divisore.
  static const double resizeGripHeight = 32;

  /// Larghezza massima della colonna di lettura (testata e testo; i corpi HTML la superano).
  static const double readingMaxWidth = 800;

  /// Da qui: lista + dettaglio (tablet). Window size class “medium”.
  static const double breakpointMedium = 600;

  /// Da qui: drawer fisso + lista. Size class “expanded”.
  static const double breakpointExpanded = 840;

  /// Da qui: lista + dettaglio affiancati (desktop e tablet). È anche la larghezza minima della finestra desktop.
  static const double breakpointListDetail = 900;

  /// Da qui la barra laterale è estesa (280); sotto, a sole icone (72).
  static const double breakpointSidebarCollapse = 1440;
}

/// Spessori dei bordi.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract final class PostinoBorder() {
  /// Filetti border-subtle tra righe e pannelli.
  static const double borderWidthHairline = 1;

  /// Bordo di input e bottoni secondari (border-strong).
  static const double borderWidthControl = 1;

  /// Anello focus-ring.
  static const double borderWidthFocus = 2;

  /// Distanza dell’anello dal controllo.
  static const double focusOffset = 2;

  /// Barra colore account sul bordo sinistro della riga in inbox unificata.
  static const double accountBarWidth = 3;

  /// Anello avatar-badge-ring attorno al badge account.
  static const double accountBadgeRing = 2;
}
