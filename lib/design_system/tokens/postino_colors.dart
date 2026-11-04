// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

import 'postino_colors_lerp.dart';
import 'postino_palette.dart';

enum PostinoAccountColor {
  sky,
  blue,
  violet,
  magenta,
  rose,
  olive,
  slate,
  graphite,
}

/// Le tre tinte di un colore account in un tema.
@immutable
class PostinoAccountSwatch {
  const PostinoAccountSwatch(this.color, this.subtle, this.onColor);
  final Color color, subtle, onColor;
}

/// Livello 2 e 3 — token semantici e di componente, light e dark.
@immutable
class PostinoColors extends ThemeExtension<PostinoColors> {
  const PostinoColors({
    required this.surfaceGround,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.surfacePressed,
    required this.surfaceSelected,
    required this.surfaceInverse,
    required this.surfaceDisabled,
    required this.scrim,
    required this.overlayHover,
    required this.overlayPressed,
    required this.borderSubtle,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.inkDisabled,
    required this.inkInverse,
    required this.brand,
    required this.brandHover,
    required this.onBrand,
    required this.brandSubtle,
    required this.brandInverse,
    required this.unread,
    required this.star,
    required this.starFill,
    required this.onStar,
    required this.focusRing,
    required this.danger,
    required this.onDanger,
    required this.dangerSubtle,
    required this.success,
    required this.onSuccess,
    required this.successSubtle,
    required this.warning,
    required this.onWarning,
    required this.warningSubtle,
    required this.accountSky,
    required this.accountSkySubtle,
    required this.accountBlue,
    required this.accountBlueSubtle,
    required this.accountViolet,
    required this.accountVioletSubtle,
    required this.accountMagenta,
    required this.accountMagentaSubtle,
    required this.accountRose,
    required this.accountRoseSubtle,
    required this.accountOlive,
    required this.accountOliveSubtle,
    required this.accountSlate,
    required this.accountSlateSubtle,
    required this.accountGraphite,
    required this.accountGraphiteSubtle,
    required this.onAccount,
    required this.labelStoneBg,
    required this.labelStoneFg,
    required this.labelSandBg,
    required this.labelSandFg,
    required this.labelSageBg,
    required this.labelSageFg,
    required this.labelSeaBg,
    required this.labelSeaFg,
    required this.labelLilacBg,
    required this.labelLilacFg,
    required this.labelBlushBg,
    required this.labelBlushFg,
    required this.listItemBg,
    required this.listItemBgSelected,
    required this.listItemFgUnread,
    required this.listItemFgRead,
    required this.listItemMeta,
    required this.listItemDivider,
    required this.swipeArchiveBg,
    required this.swipeDeleteBg,
    required this.swipeSnoozeBg,
    required this.swipeReadBg,
    required this.swipeStarBg,
    required this.swipeStarFg,
    required this.swipeNeutralBg,
    required this.swipeFg,
    required this.swipeFgIdle,
    required this.drawerBg,
    required this.drawerItemBgActive,
    required this.drawerItemFg,
    required this.drawerItemIcon,
    required this.drawerItemIconActive,
    required this.avatarBadgeRing,
    required this.composerBg,
    required this.composerFieldDivider,
    required this.chipBg,
    required this.chipFg,
    required this.chipBgSelected,
    required this.inputBg,
    required this.inputBorder,
    required this.inputBorderFocus,
    required this.inputBorderError,
    required this.snackbarBg,
    required this.snackbarFg,
    required this.snackbarAction,
    required this.fabBg,
    required this.fabFg,
    required this.switchTrackOn,
    required this.switchTrackOff,
    required this.switchThumbOn,
    required this.switchThumbOff,
    required this.tabIndicator,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.bulkBarBg,
    required this.syncOk,
    required this.syncRunning,
    required this.syncError,
  });

  /// Fondo app: drawer, sidebar, finestra dietro i pannelli.
  final Color surfaceGround;

  /// Fondo dei pannelli: lista messaggi, thread, impostazioni.
  final Color surface;

  /// Superfici sopra i pannelli: composer, menu, card, bottom sheet, dialog, campo ricerca.
  final Color surfaceRaised;

  /// Hover di righe, voci di drawer e bottoni ghost (solo puntatore).
  final Color surfaceHover;

  /// Stato premuto di righe e voci di drawer; fondo dei chip neutri.
  final Color surfacePressed;

  /// Riga selezionata, voce di drawer attiva, chip filtro attivo.
  final Color surfaceSelected;

  /// Snackbar e tooltip: l’unica superficie invertita.
  final Color surfaceInverse;

  /// Fondo dei controlli disabilitati.
  final Color surfaceDisabled;

  /// Dietro dialog, bottom sheet e drawer modale.
  final Color scrim;

  /// Velo di hover su superfici colorate (bottoni pieni, chip account). Mappa su ButtonStyle.overlayColor.
  final Color overlayHover;

  /// Velo di pressione / ink splash su superfici colorate.
  final Color overlayPressed;

  /// Filetti decorativi tra righe, pannelli e header. Mai unico bordo di un controllo.
  final Color borderSubtle;

  /// Bordo di input, bottoni secondari, checkbox: ≥3:1 su surface e surface-raised in entrambi i temi.
  final Color borderStrong;

  /// Testo primario (mittente non letto, oggetto, corpo) su ogni surface-*.
  final Color ink;

  /// Testo secondario: anteprima, mittente letto, destinatari, metadati. ≥4.5:1 su ogni surface-* tranne surface-inverse.
  final Color inkMuted;

  /// Ora, contatori, placeholder, didascalie. ≥4.5:1 su surface-ground, surface, surface-raised, surface-hover, surface-selected.
  final Color inkSubtle;

  /// Testo e icone dei controlli disabilitati (esente dal contrasto, sempre con fondo surface-disabled).
  final Color inkDisabled;

  /// Testo su surface-inverse (snackbar).
  final Color inkInverse;

  /// Colore di brand: bottone primario, FAB “Scrivi”, link, voce attiva. Non è mai un colore account.
  final Color brand;

  /// Hover/pressed dei riempimenti brand.
  final Color brandHover;

  /// Testo e icone su brand e brand-hover.
  final Color onBrand;

  /// Fondo tenue brand: banner informativi, onboarding.
  final Color brandSubtle;

  /// Azione dentro la snackbar (“Annulla”) su surface-inverse.
  final Color brandInverse;

  /// Pallino “non letto” e badge dei non letti.
  final Color unread;

  /// Stella piena dei messaggi speciali/importanti; solo icona, ≥3:1 su ogni surface. In dark coincide con star-fill.
  final Color star;

  /// Riempimento oro dell’azione Stella (swipe, smistamento). Distinto da warning/Posticipa: oro chiaro, non ambra. Testo sopra in on-star.
  final Color starFill;

  /// Testo e icone su star-fill (≥4.5:1 in entrambi i temi).
  final Color onStar;

  /// Anello di focus 2px su ogni elemento interattivo; ≥3:1 su ogni surface in entrambi i temi.
  final Color focusRing;

  /// Elimina, invio fallito, sync in errore. Testo/icona su surface-*, sempre con una parola o un’icona.
  final Color danger;

  /// Testo e icone su riempimenti danger.
  final Color onDanger;

  /// Fondo dei banner danger; testo in ink, icona in danger.
  final Color dangerSubtle;

  /// Inviato, account collegato, sincronizzato. Testo/icona su surface-*, sempre con una parola o un’icona.
  final Color success;

  /// Testo e icone su riempimenti success.
  final Color onSuccess;

  /// Fondo dei banner success; testo in ink, icona in success.
  final Color successSubtle;

  /// Offline, quota, riautenticazione richiesta. Testo/icona su surface-*, sempre con una parola o un’icona.
  final Color warning;

  /// Testo e icone su riempimenti warning.
  final Color onWarning;

  /// Fondo dei banner warning; testo in ink, icona in warning.
  final Color warningSubtle;

  /// Colore account “sky”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountSky;

  /// Fondo tenue dell’account “sky”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountSkySubtle;

  /// Colore account “blue”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountBlue;

  /// Fondo tenue dell’account “blue”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountBlueSubtle;

  /// Colore account “violet”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountViolet;

  /// Fondo tenue dell’account “violet”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountVioletSubtle;

  /// Colore account “magenta”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountMagenta;

  /// Fondo tenue dell’account “magenta”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountMagentaSubtle;

  /// Colore account “rose”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountRose;

  /// Fondo tenue dell’account “rose”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountRoseSubtle;

  /// Colore account “olive”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountOlive;

  /// Fondo tenue dell’account “olive”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountOliveSubtle;

  /// Colore account “slate”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountSlate;

  /// Fondo tenue dell’account “slate”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountSlateSubtle;

  /// Colore account “graphite”: barra sulla riga, badge avatar, selettore “Da”, chip filtro. ≥3:1 su ogni surface; testo sopra in on-account.
  final Color accountGraphite;

  /// Fondo tenue dell’account “graphite”: chip filtro selezionato, header del selettore “Da”. Testo in ink.
  final Color accountGraphiteSubtle;

  /// Iniziale/icona dentro un riempimento account-* (badge avatar, chip account).
  final Color onAccount;

  /// Fondo del chip etichetta “stone”.
  final Color labelStoneBg;

  /// Testo e icona tag del chip etichetta “stone” sul suo fondo (≥4.5:1).
  final Color labelStoneFg;

  /// Fondo del chip etichetta “sand”.
  final Color labelSandBg;

  /// Testo e icona tag del chip etichetta “sand” sul suo fondo (≥4.5:1).
  final Color labelSandFg;

  /// Fondo del chip etichetta “sage”.
  final Color labelSageBg;

  /// Testo e icona tag del chip etichetta “sage” sul suo fondo (≥4.5:1).
  final Color labelSageFg;

  /// Fondo del chip etichetta “sea”.
  final Color labelSeaBg;

  /// Testo e icona tag del chip etichetta “sea” sul suo fondo (≥4.5:1).
  final Color labelSeaFg;

  /// Fondo del chip etichetta “lilac”.
  final Color labelLilacBg;

  /// Testo e icona tag del chip etichetta “lilac” sul suo fondo (≥4.5:1).
  final Color labelLilacFg;

  /// Fondo del chip etichetta “blush”.
  final Color labelBlushBg;

  /// Testo e icona tag del chip etichetta “blush” sul suo fondo (≥4.5:1).
  final Color labelBlushFg;

  /// MessageListItem: fondo a riposo.
  final Color listItemBg;

  /// MessageListItem: selezionato o in multi-selezione.
  final Color listItemBgSelected;

  /// MessageListItem: mittente e oggetto non letti.
  final Color listItemFgUnread;

  /// MessageListItem: mittente e oggetto letti, anteprima.
  final Color listItemFgRead;

  /// MessageListItem: ora e conteggio thread.
  final Color listItemMeta;

  /// MessageListItem: filetto inferiore.
  final Color listItemDivider;

  /// SwipeActions: Archivia.
  final Color swipeArchiveBg;

  /// SwipeActions: Elimina.
  final Color swipeDeleteBg;

  /// SwipeActions: Posticipa.
  final Color swipeSnoozeBg;

  /// SwipeActions: Segna come letto/non letto.
  final Color swipeReadBg;

  /// SwipeActions e smistamento: Stella (timbro, bordo della scheda, bottone, bussola).
  final Color swipeStarBg;

  /// Icona e testo sopra swipe-star-bg (al posto di swipe-fg).
  final Color swipeStarFg;

  /// SwipeActions: azione sotto soglia (non ancora armata).
  final Color swipeNeutralBg;

  /// SwipeActions: icona e testo sopra ogni swipe-*-bg armato.
  final Color swipeFg;

  /// SwipeActions: icona su swipe-neutral-bg.
  final Color swipeFgIdle;

  /// NavigationDrawer: fondo.
  final Color drawerBg;

  /// DrawerItem attivo (indicatore M3).
  final Color drawerItemBgActive;

  /// DrawerItem: etichetta.
  final Color drawerItemFg;

  /// DrawerItem: icona a riposo.
  final Color drawerItemIcon;

  /// DrawerItem: icona attiva.
  final Color drawerItemIconActive;

  /// Avatar: anello che stacca il badge account dalla foto (deve uguagliare il fondo).
  final Color avatarBadgeRing;

  /// Composer: fondo.
  final Color composerBg;

  /// Composer: filetti tra Da/A/Cc/Oggetto.
  final Color composerFieldDivider;

  /// Chip contatto e chip neutri.
  final Color chipBg;

  /// Testo dei chip neutri.
  final Color chipFg;

  /// FilterChip selezionato.
  final Color chipBgSelected;

  /// TextField / SearchBar: fondo.
  final Color inputBg;

  /// TextField: bordo a riposo.
  final Color inputBorder;

  /// TextField: bordo con focus (più focus-ring da tastiera).
  final Color inputBorderFocus;

  /// TextField: bordo in errore, con messaggio.
  final Color inputBorderError;

  /// Snackbar: fondo.
  final Color snackbarBg;

  /// Snackbar: testo.
  final Color snackbarFg;

  /// Snackbar: azione “Annulla”.
  final Color snackbarAction;

  /// FAB “Scrivi”: fondo.
  final Color fabBg;

  /// FAB “Scrivi”: icona ed etichetta.
  final Color fabFg;

  /// Switch acceso: traccia.
  final Color switchTrackOn;

  /// Switch spento: traccia (con bordo border-strong).
  final Color switchTrackOff;

  /// Switch acceso: pallino.
  final Color switchThumbOn;

  /// Switch spento: pallino.
  final Color switchThumbOff;

  /// Tabs: indicatore sotto la scheda attiva.
  final Color tabIndicator;

  /// Skeleton: blocchi segnaposto.
  final Color skeletonBase;

  /// Skeleton: riflesso dell’animazione.
  final Color skeletonHighlight;

  /// BulkActionBar: fondo (con elevation-2).
  final Color bulkBarBg;

  /// SyncStatus: sincronizzato.
  final Color syncOk;

  /// SyncStatus: in corso (icona che ruota).
  final Color syncRunning;

  /// SyncStatus: errore.
  final Color syncError;

  static const light = PostinoColors(
    surfaceGround: PostinoPrimitives.pNeutral100,
    surface: PostinoPrimitives.pNeutral50,
    surfaceRaised: PostinoPrimitives.pNeutral0,
    surfaceHover: PostinoPrimitives.pNeutral150,
    surfacePressed: PostinoPrimitives.pNeutral200,
    surfaceSelected: PostinoPrimitives.pVerdigris100,
    surfaceInverse: PostinoPrimitives.pNeutral900,
    surfaceDisabled: PostinoPrimitives.pNeutral150,
    scrim: Color(0x66131312),
    overlayHover: Color(0x0F131312),
    overlayPressed: Color(0x14131312),
    borderSubtle: PostinoPrimitives.pNeutral200,
    borderStrong: PostinoPrimitives.pNeutral500,
    ink: PostinoPrimitives.pNeutral900,
    inkMuted: PostinoPrimitives.pNeutral600,
    inkSubtle: Color(0xFF67635A),
    inkDisabled: PostinoPrimitives.pNeutral400,
    inkInverse: PostinoPrimitives.pNeutral50,
    brand: Color(0xFF0E6456),
    brandHover: PostinoPrimitives.pVerdigris800,
    onBrand: PostinoPrimitives.pNeutral0,
    brandSubtle: PostinoPrimitives.pVerdigris50,
    brandInverse: PostinoPrimitives.pVerdigris300,
    unread: PostinoPrimitives.pVerdigris700,
    star: PostinoPrimitives.pGold700,
    starFill: PostinoPrimitives.pGold400,
    onStar: PostinoPrimitives.pNeutral950,
    focusRing: PostinoPrimitives.pOrange700,
    danger: PostinoPrimitives.pRed700,
    onDanger: PostinoPrimitives.pNeutral0,
    dangerSubtle: PostinoPrimitives.pRed100,
    success: PostinoPrimitives.pGreen700,
    onSuccess: PostinoPrimitives.pNeutral0,
    successSubtle: PostinoPrimitives.pGreen100,
    warning: PostinoPrimitives.pAmber700,
    onWarning: PostinoPrimitives.pNeutral0,
    warningSubtle: PostinoPrimitives.pAmber100,
    accountSky: PostinoPrimitives.pSky600,
    accountSkySubtle: PostinoPrimitives.pSky100,
    accountBlue: PostinoPrimitives.pBlue600,
    accountBlueSubtle: PostinoPrimitives.pBlue100,
    accountViolet: PostinoPrimitives.pViolet600,
    accountVioletSubtle: PostinoPrimitives.pViolet100,
    accountMagenta: PostinoPrimitives.pMagenta600,
    accountMagentaSubtle: PostinoPrimitives.pMagenta100,
    accountRose: PostinoPrimitives.pRose600,
    accountRoseSubtle: PostinoPrimitives.pRose100,
    accountOlive: PostinoPrimitives.pOlive600,
    accountOliveSubtle: PostinoPrimitives.pOlive100,
    accountSlate: PostinoPrimitives.pSlate600,
    accountSlateSubtle: PostinoPrimitives.pSlate100,
    accountGraphite: PostinoPrimitives.pGraphite600,
    accountGraphiteSubtle: PostinoPrimitives.pGraphite100,
    onAccount: PostinoPrimitives.pNeutral0,
    labelStoneBg: PostinoPrimitives.pLabelStoneBgLight,
    labelStoneFg: PostinoPrimitives.pLabelStoneFgLight,
    labelSandBg: PostinoPrimitives.pLabelSandBgLight,
    labelSandFg: PostinoPrimitives.pLabelSandFgLight,
    labelSageBg: PostinoPrimitives.pLabelSageBgLight,
    labelSageFg: PostinoPrimitives.pLabelSageFgLight,
    labelSeaBg: PostinoPrimitives.pLabelSeaBgLight,
    labelSeaFg: PostinoPrimitives.pLabelSeaFgLight,
    labelLilacBg: PostinoPrimitives.pLabelLilacBgLight,
    labelLilacFg: PostinoPrimitives.pLabelLilacFgLight,
    labelBlushBg: PostinoPrimitives.pLabelBlushBgLight,
    labelBlushFg: PostinoPrimitives.pLabelBlushFgLight,
    listItemBg: PostinoPrimitives.pNeutral50,
    listItemBgSelected: PostinoPrimitives.pVerdigris100,
    listItemFgUnread: PostinoPrimitives.pNeutral900,
    listItemFgRead: Color(0xFF5C5850),
    listItemMeta: Color(0xFF5C5950),
    listItemDivider: PostinoPrimitives.pNeutral200,
    swipeArchiveBg: PostinoPrimitives.pGreen700,
    swipeDeleteBg: PostinoPrimitives.pRed700,
    swipeSnoozeBg: PostinoPrimitives.pAmber700,
    swipeReadBg: PostinoPrimitives.pVerdigris700,
    swipeStarBg: PostinoPrimitives.pGold400,
    swipeStarFg: PostinoPrimitives.pNeutral950,
    swipeNeutralBg: PostinoPrimitives.pNeutral200,
    swipeFg: PostinoPrimitives.pNeutral0,
    swipeFgIdle: PostinoPrimitives.pNeutral600,
    drawerBg: PostinoPrimitives.pNeutral100,
    drawerItemBgActive: PostinoPrimitives.pVerdigris100,
    drawerItemFg: PostinoPrimitives.pNeutral900,
    drawerItemIcon: PostinoPrimitives.pNeutral600,
    drawerItemIconActive: PostinoPrimitives.pVerdigris700,
    avatarBadgeRing: PostinoPrimitives.pNeutral50,
    composerBg: PostinoPrimitives.pNeutral0,
    composerFieldDivider: PostinoPrimitives.pNeutral200,
    chipBg: PostinoPrimitives.pNeutral200,
    chipFg: PostinoPrimitives.pNeutral900,
    chipBgSelected: PostinoPrimitives.pVerdigris100,
    inputBg: PostinoPrimitives.pNeutral0,
    inputBorder: PostinoPrimitives.pNeutral500,
    inputBorderFocus: PostinoPrimitives.pVerdigris700,
    inputBorderError: PostinoPrimitives.pRed700,
    snackbarBg: PostinoPrimitives.pNeutral900,
    snackbarFg: PostinoPrimitives.pNeutral50,
    snackbarAction: PostinoPrimitives.pVerdigris300,
    fabBg: PostinoPrimitives.pVerdigris700,
    fabFg: PostinoPrimitives.pNeutral0,
    switchTrackOn: PostinoPrimitives.pVerdigris700,
    switchTrackOff: PostinoPrimitives.pNeutral200,
    switchThumbOn: PostinoPrimitives.pNeutral0,
    switchThumbOff: PostinoPrimitives.pNeutral600,
    tabIndicator: PostinoPrimitives.pVerdigris700,
    skeletonBase: PostinoPrimitives.pNeutral200,
    skeletonHighlight: PostinoPrimitives.pNeutral150,
    bulkBarBg: PostinoPrimitives.pNeutral0,
    syncOk: PostinoPrimitives.pGreen700,
    syncRunning: PostinoPrimitives.pNeutral600,
    syncError: PostinoPrimitives.pRed700,
  );

  static const dark = PostinoColors(
    surfaceGround: PostinoPrimitives.pNeutral950,
    surface: PostinoPrimitives.pNeutral900,
    surfaceRaised: PostinoPrimitives.pNeutral850,
    surfaceHover: PostinoPrimitives.pNeutral800,
    surfacePressed: PostinoPrimitives.pNeutral750,
    surfaceSelected: PostinoPrimitives.pVerdigris900,
    surfaceInverse: PostinoPrimitives.pNeutral100,
    surfaceDisabled: PostinoPrimitives.pNeutral800,
    scrim: Color(0x9E000000),
    overlayHover: Color(0x12FFFFFF),
    overlayPressed: Color(0x14FFFFFF),
    borderSubtle: PostinoPrimitives.pNeutral800,
    borderStrong: PostinoPrimitives.pNeutral500,
    ink: PostinoPrimitives.pNeutral100,
    inkMuted: PostinoPrimitives.pNeutral400,
    inkSubtle: Color(0xFFA39E93),
    inkDisabled: PostinoPrimitives.pNeutral600,
    inkInverse: PostinoPrimitives.pNeutral900,
    brand: PostinoPrimitives.pVerdigris300,
    brandHover: PostinoPrimitives.pVerdigris200,
    onBrand: PostinoPrimitives.pVerdigris950,
    brandSubtle: PostinoPrimitives.pVerdigris950,
    brandInverse: PostinoPrimitives.pVerdigris700,
    unread: PostinoPrimitives.pVerdigris300,
    star: PostinoPrimitives.pGold300,
    starFill: PostinoPrimitives.pGold300,
    onStar: PostinoPrimitives.pNeutral950,
    focusRing: PostinoPrimitives.pOrange300,
    danger: PostinoPrimitives.pRed300,
    onDanger: PostinoPrimitives.pNeutral950,
    dangerSubtle: PostinoPrimitives.pRed900,
    success: PostinoPrimitives.pGreen300,
    onSuccess: PostinoPrimitives.pNeutral950,
    successSubtle: PostinoPrimitives.pGreen900,
    warning: PostinoPrimitives.pAmber300,
    onWarning: PostinoPrimitives.pNeutral950,
    warningSubtle: PostinoPrimitives.pAmber900,
    accountSky: PostinoPrimitives.pSky300,
    accountSkySubtle: PostinoPrimitives.pSky900,
    accountBlue: PostinoPrimitives.pBlue300,
    accountBlueSubtle: PostinoPrimitives.pBlue900,
    accountViolet: PostinoPrimitives.pViolet300,
    accountVioletSubtle: PostinoPrimitives.pViolet900,
    accountMagenta: PostinoPrimitives.pMagenta300,
    accountMagentaSubtle: PostinoPrimitives.pMagenta900,
    accountRose: PostinoPrimitives.pRose300,
    accountRoseSubtle: PostinoPrimitives.pRose900,
    accountOlive: PostinoPrimitives.pOlive300,
    accountOliveSubtle: PostinoPrimitives.pOlive900,
    accountSlate: PostinoPrimitives.pSlate300,
    accountSlateSubtle: PostinoPrimitives.pSlate900,
    accountGraphite: PostinoPrimitives.pGraphite300,
    accountGraphiteSubtle: PostinoPrimitives.pGraphite900,
    onAccount: PostinoPrimitives.pNeutral950,
    labelStoneBg: PostinoPrimitives.pLabelStoneBgDark,
    labelStoneFg: PostinoPrimitives.pLabelStoneFgDark,
    labelSandBg: PostinoPrimitives.pLabelSandBgDark,
    labelSandFg: PostinoPrimitives.pLabelSandFgDark,
    labelSageBg: PostinoPrimitives.pLabelSageBgDark,
    labelSageFg: PostinoPrimitives.pLabelSageFgDark,
    labelSeaBg: PostinoPrimitives.pLabelSeaBgDark,
    labelSeaFg: PostinoPrimitives.pLabelSeaFgDark,
    labelLilacBg: PostinoPrimitives.pLabelLilacBgDark,
    labelLilacFg: PostinoPrimitives.pLabelLilacFgDark,
    labelBlushBg: PostinoPrimitives.pLabelBlushBgDark,
    labelBlushFg: PostinoPrimitives.pLabelBlushFgDark,
    listItemBg: PostinoPrimitives.pNeutral900,
    listItemBgSelected: PostinoPrimitives.pVerdigris900,
    listItemFgUnread: PostinoPrimitives.pNeutral100,
    listItemFgRead: Color(0xFFBDB8AE),
    listItemMeta: Color(0xFFBCB8B0),
    listItemDivider: PostinoPrimitives.pNeutral800,
    swipeArchiveBg: PostinoPrimitives.pGreen300,
    swipeDeleteBg: PostinoPrimitives.pRed300,
    swipeSnoozeBg: PostinoPrimitives.pAmber300,
    swipeReadBg: PostinoPrimitives.pVerdigris300,
    swipeStarBg: PostinoPrimitives.pGold300,
    swipeStarFg: PostinoPrimitives.pNeutral950,
    swipeNeutralBg: PostinoPrimitives.pNeutral750,
    swipeFg: PostinoPrimitives.pNeutral950,
    swipeFgIdle: PostinoPrimitives.pNeutral400,
    drawerBg: PostinoPrimitives.pNeutral950,
    drawerItemBgActive: PostinoPrimitives.pVerdigris900,
    drawerItemFg: PostinoPrimitives.pNeutral100,
    drawerItemIcon: PostinoPrimitives.pNeutral400,
    drawerItemIconActive: PostinoPrimitives.pVerdigris300,
    avatarBadgeRing: PostinoPrimitives.pNeutral900,
    composerBg: PostinoPrimitives.pNeutral850,
    composerFieldDivider: PostinoPrimitives.pNeutral800,
    chipBg: PostinoPrimitives.pNeutral750,
    chipFg: PostinoPrimitives.pNeutral100,
    chipBgSelected: PostinoPrimitives.pVerdigris900,
    inputBg: PostinoPrimitives.pNeutral850,
    inputBorder: PostinoPrimitives.pNeutral500,
    inputBorderFocus: PostinoPrimitives.pVerdigris300,
    inputBorderError: PostinoPrimitives.pRed300,
    snackbarBg: PostinoPrimitives.pNeutral100,
    snackbarFg: PostinoPrimitives.pNeutral900,
    snackbarAction: PostinoPrimitives.pVerdigris700,
    fabBg: PostinoPrimitives.pVerdigris300,
    fabFg: PostinoPrimitives.pVerdigris950,
    switchTrackOn: PostinoPrimitives.pVerdigris300,
    switchTrackOff: PostinoPrimitives.pNeutral750,
    switchThumbOn: PostinoPrimitives.pVerdigris950,
    switchThumbOff: PostinoPrimitives.pNeutral400,
    tabIndicator: PostinoPrimitives.pVerdigris300,
    skeletonBase: PostinoPrimitives.pNeutral750,
    skeletonHighlight: PostinoPrimitives.pNeutral800,
    bulkBarBg: PostinoPrimitives.pNeutral850,
    syncOk: PostinoPrimitives.pGreen300,
    syncRunning: PostinoPrimitives.pNeutral400,
    syncError: PostinoPrimitives.pRed300,
  );

  PostinoAccountSwatch account(PostinoAccountColor c) => switch (c) {
    PostinoAccountColor.sky => PostinoAccountSwatch(
      accountSky,
      accountSkySubtle,
      onAccount,
    ),
    PostinoAccountColor.blue => PostinoAccountSwatch(
      accountBlue,
      accountBlueSubtle,
      onAccount,
    ),
    PostinoAccountColor.violet => PostinoAccountSwatch(
      accountViolet,
      accountVioletSubtle,
      onAccount,
    ),
    PostinoAccountColor.magenta => PostinoAccountSwatch(
      accountMagenta,
      accountMagentaSubtle,
      onAccount,
    ),
    PostinoAccountColor.rose => PostinoAccountSwatch(
      accountRose,
      accountRoseSubtle,
      onAccount,
    ),
    PostinoAccountColor.olive => PostinoAccountSwatch(
      accountOlive,
      accountOliveSubtle,
      onAccount,
    ),
    PostinoAccountColor.slate => PostinoAccountSwatch(
      accountSlate,
      accountSlateSubtle,
      onAccount,
    ),
    PostinoAccountColor.graphite => PostinoAccountSwatch(
      accountGraphite,
      accountGraphiteSubtle,
      onAccount,
    ),
  };

  @override
  PostinoColors copyWith({
    Color? surfaceGround,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceHover,
    Color? surfacePressed,
    Color? surfaceSelected,
    Color? surfaceInverse,
    Color? surfaceDisabled,
    Color? scrim,
    Color? overlayHover,
    Color? overlayPressed,
    Color? borderSubtle,
    Color? borderStrong,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? inkDisabled,
    Color? inkInverse,
    Color? brand,
    Color? brandHover,
    Color? onBrand,
    Color? brandSubtle,
    Color? brandInverse,
    Color? unread,
    Color? star,
    Color? starFill,
    Color? onStar,
    Color? focusRing,
    Color? danger,
    Color? onDanger,
    Color? dangerSubtle,
    Color? success,
    Color? onSuccess,
    Color? successSubtle,
    Color? warning,
    Color? onWarning,
    Color? warningSubtle,
    Color? accountSky,
    Color? accountSkySubtle,
    Color? accountBlue,
    Color? accountBlueSubtle,
    Color? accountViolet,
    Color? accountVioletSubtle,
    Color? accountMagenta,
    Color? accountMagentaSubtle,
    Color? accountRose,
    Color? accountRoseSubtle,
    Color? accountOlive,
    Color? accountOliveSubtle,
    Color? accountSlate,
    Color? accountSlateSubtle,
    Color? accountGraphite,
    Color? accountGraphiteSubtle,
    Color? onAccount,
    Color? labelStoneBg,
    Color? labelStoneFg,
    Color? labelSandBg,
    Color? labelSandFg,
    Color? labelSageBg,
    Color? labelSageFg,
    Color? labelSeaBg,
    Color? labelSeaFg,
    Color? labelLilacBg,
    Color? labelLilacFg,
    Color? labelBlushBg,
    Color? labelBlushFg,
    Color? listItemBg,
    Color? listItemBgSelected,
    Color? listItemFgUnread,
    Color? listItemFgRead,
    Color? listItemMeta,
    Color? listItemDivider,
    Color? swipeArchiveBg,
    Color? swipeDeleteBg,
    Color? swipeSnoozeBg,
    Color? swipeReadBg,
    Color? swipeStarBg,
    Color? swipeStarFg,
    Color? swipeNeutralBg,
    Color? swipeFg,
    Color? swipeFgIdle,
    Color? drawerBg,
    Color? drawerItemBgActive,
    Color? drawerItemFg,
    Color? drawerItemIcon,
    Color? drawerItemIconActive,
    Color? avatarBadgeRing,
    Color? composerBg,
    Color? composerFieldDivider,
    Color? chipBg,
    Color? chipFg,
    Color? chipBgSelected,
    Color? inputBg,
    Color? inputBorder,
    Color? inputBorderFocus,
    Color? inputBorderError,
    Color? snackbarBg,
    Color? snackbarFg,
    Color? snackbarAction,
    Color? fabBg,
    Color? fabFg,
    Color? switchTrackOn,
    Color? switchTrackOff,
    Color? switchThumbOn,
    Color? switchThumbOff,
    Color? tabIndicator,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? bulkBarBg,
    Color? syncOk,
    Color? syncRunning,
    Color? syncError,
  }) => PostinoColors(
    surfaceGround: surfaceGround ?? this.surfaceGround,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceHover: surfaceHover ?? this.surfaceHover,
    surfacePressed: surfacePressed ?? this.surfacePressed,
    surfaceSelected: surfaceSelected ?? this.surfaceSelected,
    surfaceInverse: surfaceInverse ?? this.surfaceInverse,
    surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
    scrim: scrim ?? this.scrim,
    overlayHover: overlayHover ?? this.overlayHover,
    overlayPressed: overlayPressed ?? this.overlayPressed,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    borderStrong: borderStrong ?? this.borderStrong,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkSubtle: inkSubtle ?? this.inkSubtle,
    inkDisabled: inkDisabled ?? this.inkDisabled,
    inkInverse: inkInverse ?? this.inkInverse,
    brand: brand ?? this.brand,
    brandHover: brandHover ?? this.brandHover,
    onBrand: onBrand ?? this.onBrand,
    brandSubtle: brandSubtle ?? this.brandSubtle,
    brandInverse: brandInverse ?? this.brandInverse,
    unread: unread ?? this.unread,
    star: star ?? this.star,
    starFill: starFill ?? this.starFill,
    onStar: onStar ?? this.onStar,
    focusRing: focusRing ?? this.focusRing,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    dangerSubtle: dangerSubtle ?? this.dangerSubtle,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successSubtle: successSubtle ?? this.successSubtle,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    warningSubtle: warningSubtle ?? this.warningSubtle,
    accountSky: accountSky ?? this.accountSky,
    accountSkySubtle: accountSkySubtle ?? this.accountSkySubtle,
    accountBlue: accountBlue ?? this.accountBlue,
    accountBlueSubtle: accountBlueSubtle ?? this.accountBlueSubtle,
    accountViolet: accountViolet ?? this.accountViolet,
    accountVioletSubtle: accountVioletSubtle ?? this.accountVioletSubtle,
    accountMagenta: accountMagenta ?? this.accountMagenta,
    accountMagentaSubtle: accountMagentaSubtle ?? this.accountMagentaSubtle,
    accountRose: accountRose ?? this.accountRose,
    accountRoseSubtle: accountRoseSubtle ?? this.accountRoseSubtle,
    accountOlive: accountOlive ?? this.accountOlive,
    accountOliveSubtle: accountOliveSubtle ?? this.accountOliveSubtle,
    accountSlate: accountSlate ?? this.accountSlate,
    accountSlateSubtle: accountSlateSubtle ?? this.accountSlateSubtle,
    accountGraphite: accountGraphite ?? this.accountGraphite,
    accountGraphiteSubtle: accountGraphiteSubtle ?? this.accountGraphiteSubtle,
    onAccount: onAccount ?? this.onAccount,
    labelStoneBg: labelStoneBg ?? this.labelStoneBg,
    labelStoneFg: labelStoneFg ?? this.labelStoneFg,
    labelSandBg: labelSandBg ?? this.labelSandBg,
    labelSandFg: labelSandFg ?? this.labelSandFg,
    labelSageBg: labelSageBg ?? this.labelSageBg,
    labelSageFg: labelSageFg ?? this.labelSageFg,
    labelSeaBg: labelSeaBg ?? this.labelSeaBg,
    labelSeaFg: labelSeaFg ?? this.labelSeaFg,
    labelLilacBg: labelLilacBg ?? this.labelLilacBg,
    labelLilacFg: labelLilacFg ?? this.labelLilacFg,
    labelBlushBg: labelBlushBg ?? this.labelBlushBg,
    labelBlushFg: labelBlushFg ?? this.labelBlushFg,
    listItemBg: listItemBg ?? this.listItemBg,
    listItemBgSelected: listItemBgSelected ?? this.listItemBgSelected,
    listItemFgUnread: listItemFgUnread ?? this.listItemFgUnread,
    listItemFgRead: listItemFgRead ?? this.listItemFgRead,
    listItemMeta: listItemMeta ?? this.listItemMeta,
    listItemDivider: listItemDivider ?? this.listItemDivider,
    swipeArchiveBg: swipeArchiveBg ?? this.swipeArchiveBg,
    swipeDeleteBg: swipeDeleteBg ?? this.swipeDeleteBg,
    swipeSnoozeBg: swipeSnoozeBg ?? this.swipeSnoozeBg,
    swipeReadBg: swipeReadBg ?? this.swipeReadBg,
    swipeStarBg: swipeStarBg ?? this.swipeStarBg,
    swipeStarFg: swipeStarFg ?? this.swipeStarFg,
    swipeNeutralBg: swipeNeutralBg ?? this.swipeNeutralBg,
    swipeFg: swipeFg ?? this.swipeFg,
    swipeFgIdle: swipeFgIdle ?? this.swipeFgIdle,
    drawerBg: drawerBg ?? this.drawerBg,
    drawerItemBgActive: drawerItemBgActive ?? this.drawerItemBgActive,
    drawerItemFg: drawerItemFg ?? this.drawerItemFg,
    drawerItemIcon: drawerItemIcon ?? this.drawerItemIcon,
    drawerItemIconActive: drawerItemIconActive ?? this.drawerItemIconActive,
    avatarBadgeRing: avatarBadgeRing ?? this.avatarBadgeRing,
    composerBg: composerBg ?? this.composerBg,
    composerFieldDivider: composerFieldDivider ?? this.composerFieldDivider,
    chipBg: chipBg ?? this.chipBg,
    chipFg: chipFg ?? this.chipFg,
    chipBgSelected: chipBgSelected ?? this.chipBgSelected,
    inputBg: inputBg ?? this.inputBg,
    inputBorder: inputBorder ?? this.inputBorder,
    inputBorderFocus: inputBorderFocus ?? this.inputBorderFocus,
    inputBorderError: inputBorderError ?? this.inputBorderError,
    snackbarBg: snackbarBg ?? this.snackbarBg,
    snackbarFg: snackbarFg ?? this.snackbarFg,
    snackbarAction: snackbarAction ?? this.snackbarAction,
    fabBg: fabBg ?? this.fabBg,
    fabFg: fabFg ?? this.fabFg,
    switchTrackOn: switchTrackOn ?? this.switchTrackOn,
    switchTrackOff: switchTrackOff ?? this.switchTrackOff,
    switchThumbOn: switchThumbOn ?? this.switchThumbOn,
    switchThumbOff: switchThumbOff ?? this.switchThumbOff,
    tabIndicator: tabIndicator ?? this.tabIndicator,
    skeletonBase: skeletonBase ?? this.skeletonBase,
    skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    bulkBarBg: bulkBarBg ?? this.bulkBarBg,
    syncOk: syncOk ?? this.syncOk,
    syncRunning: syncRunning ?? this.syncRunning,
    syncError: syncError ?? this.syncError,
  );

  @override
  PostinoColors lerp(PostinoColors? other, double t) => lerpColors(other, t);
}
