// postino_tokens.dart — copiato dal design system Postino (artifact https://claude.ai/artifact/NHTah8veqH7f9q2BbEcBKs,
// sezione 04-flutter). Nessun generatore nel repo: va tenuto allineato a mano con quella fonte.
import 'package:flutter/material.dart';

/// Livello 1 — primitivi. Non usarli nei widget: passa da PostinoColors.
abstract final class PostinoPrimitives {
  static const pNeutral0 = Color(0xFFFFFFFF);
  static const pNeutral50 = Color(0xFFFBFAF7);
  static const pNeutral100 = Color(0xFFF4F2EC);
  static const pNeutral150 = Color(0xFFECE9E1);
  static const pNeutral200 = Color(0xFFE2DED4);
  static const pNeutral300 = Color(0xFFCDC8BB);
  static const pNeutral400 = Color(0xFFA6A093);
  static const pNeutral500 = Color(0xFF7F7A6E);
  static const pNeutral600 = Color(0xFF625E55);
  static const pNeutral700 = Color(0xFF4A4740);
  static const pNeutral750 = Color(0xFF3A3833);
  static const pNeutral800 = Color(0xFF2D2C29);
  static const pNeutral850 = Color(0xFF242422);
  static const pNeutral900 = Color(0xFF1C1C1A);
  static const pNeutral950 = Color(0xFF131312);
  static const pVerdigris50 = Color(0xFFEBF6F2);
  static const pVerdigris100 = Color(0xFFD6EDE5);
  static const pVerdigris200 = Color(0xFFA9D9CB);
  static const pVerdigris300 = Color(0xFF79C9B3);
  static const pVerdigris400 = Color(0xFF4FAE96);
  static const pVerdigris500 = Color(0xFF2A917A);
  static const pVerdigris600 = Color(0xFF167A66);
  static const pVerdigris700 = Color(0xFF0F6B5C);
  static const pVerdigris800 = Color(0xFF0B5649);
  static const pVerdigris900 = Color(0xFF143A33);
  static const pVerdigris950 = Color(0xFF0B231E);
  static const pRed100 = Color(0xFFFDE8E4);
  static const pRed300 = Color(0xFFFF9384);
  static const pRed700 = Color(0xFFB42318);
  static const pRed900 = Color(0xFF40140F);
  static const pGreen100 = Color(0xFFE2F3E6);
  static const pGreen300 = Color(0xFF74D293);
  static const pGreen700 = Color(0xFF1E6B3A);
  static const pGreen900 = Color(0xFF12301D);
  static const pAmber100 = Color(0xFFFBEFD4);
  static const pAmber300 = Color(0xFFEBB84E);
  static const pAmber700 = Color(0xFF855700);
  static const pAmber900 = Color(0xFF3A2A08);
  static const pOrange100 = Color(0xFFFDE9DA);
  static const pOrange300 = Color(0xFFF2A65E);
  static const pOrange700 = Color(0xFFB0500A);
  static const pOrange900 = Color(0xFF3D220C);
  static const pGold300 = Color(0xFFFFE02E);
  static const pGold400 = Color(0xFFF0C419);
  static const pGold700 = Color(0xFF9C5900);
  static const pSky100 = Color(0xFFDAF4FD);
  static const pSky300 = Color(0xFF5CD5FC);
  static const pSky600 = Color(0xFF00779E);
  static const pSky900 = Color(0xFF003443);
  static const pBlue100 = Color(0xFFE5EFFF);
  static const pBlue300 = Color(0xFF84A8FD);
  static const pBlue600 = Color(0xFF3559C3);
  static const pBlue900 = Color(0xFF1F2C4C);
  static const pViolet100 = Color(0xFFF0EBFF);
  static const pViolet300 = Color(0xFFC8ABFF);
  static const pViolet600 = Color(0xFF6C3FAF);
  static const pViolet900 = Color(0xFF322748);
  static const pMagenta100 = Color(0xFFFBE8F8);
  static const pMagenta300 = Color(0xFFD782CB);
  static const pMagenta600 = Color(0xFF95388B);
  static const pMagenta900 = Color(0xFF3F223B);
  static const pRose100 = Color(0xFFFFE7ED);
  static const pRose300 = Color(0xFFFFA9C7);
  static const pRose600 = Color(0xFFB43C6B);
  static const pRose900 = Color(0xFF46202D);
  static const pOlive100 = Color(0xFFEEF1DA);
  static const pOlive300 = Color(0xFFD3D979);
  static const pOlive600 = Color(0xFF6B6F00);
  static const pOlive900 = Color(0xFF2F3106);
  static const pSlate100 = Color(0xFFE9EFF6);
  static const pSlate300 = Color(0xFF95A7BA);
  static const pSlate600 = Color(0xFF445465);
  static const pSlate900 = Color(0xFF262F38);
  static const pGraphite100 = Color(0xFFF3EEE6);
  static const pGraphite300 = Color(0xFFE2DDD5);
  static const pGraphite600 = Color(0xFF403D36);
  static const pGraphite900 = Color(0xFF332D23);
  static const pLabelStoneBgLight = Color(0xFFEBE8E1);
  static const pLabelStoneFgLight = Color(0xFF4A4740);
  static const pLabelStoneBgDark = Color(0xFF34332F);
  static const pLabelStoneFgDark = Color(0xFFD6D2C8);
  static const pLabelSandBgLight = Color(0xFFF5EAD2);
  static const pLabelSandFgLight = Color(0xFF6B4D10);
  static const pLabelSandBgDark = Color(0xFF3B3222);
  static const pLabelSandFgDark = Color(0xFFE8CF9A);
  static const pLabelSageBgLight = Color(0xFFE1ECDF);
  static const pLabelSageFgLight = Color(0xFF355230);
  static const pLabelSageBgDark = Color(0xFF26332A);
  static const pLabelSageFgDark = Color(0xFFB9D4B3);
  static const pLabelSeaBgLight = Color(0xFFDCECF0);
  static const pLabelSeaFgLight = Color(0xFF1F4F5C);
  static const pLabelSeaBgDark = Color(0xFF1D3238);
  static const pLabelSeaFgDark = Color(0xFFA9D3DE);
  static const pLabelLilacBgLight = Color(0xFFECE5F3);
  static const pLabelLilacFgLight = Color(0xFF553F70);
  static const pLabelLilacBgDark = Color(0xFF302A3B);
  static const pLabelLilacFgDark = Color(0xFFD2C3E6);
  static const pLabelBlushBgLight = Color(0xFFF6E3E1);
  static const pLabelBlushFgLight = Color(0xFF77352D);
  static const pLabelBlushBgDark = Color(0xFF3D2826);
  static const pLabelBlushFgDark = Color(0xFFECBDB6);
}

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
    overlayPressed: Color(0x1F131312),
    borderSubtle: PostinoPrimitives.pNeutral200,
    borderStrong: PostinoPrimitives.pNeutral500,
    ink: PostinoPrimitives.pNeutral900,
    inkMuted: PostinoPrimitives.pNeutral600,
    inkSubtle: Color(0xFF6A665C),
    inkDisabled: PostinoPrimitives.pNeutral400,
    inkInverse: PostinoPrimitives.pNeutral50,
    brand: PostinoPrimitives.pVerdigris700,
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
    listItemFgRead: PostinoPrimitives.pNeutral600,
    listItemMeta: Color(0xFF6A665C),
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
    overlayPressed: Color(0x1FFFFFFF),
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
    listItemFgRead: PostinoPrimitives.pNeutral400,
    listItemMeta: Color(0xFFA39E93),
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
  PostinoColors lerp(PostinoColors? other, double t) {
    if (other == null) return this;
    return PostinoColors(
      surfaceGround: Color.lerp(surfaceGround, other.surfaceGround, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      surfaceDisabled: Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      overlayHover: Color.lerp(overlayHover, other.overlayHover, t)!,
      overlayPressed: Color.lerp(overlayPressed, other.overlayPressed, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSubtle: Color.lerp(inkSubtle, other.inkSubtle, t)!,
      inkDisabled: Color.lerp(inkDisabled, other.inkDisabled, t)!,
      inkInverse: Color.lerp(inkInverse, other.inkInverse, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      brandInverse: Color.lerp(brandInverse, other.brandInverse, t)!,
      unread: Color.lerp(unread, other.unread, t)!,
      star: Color.lerp(star, other.star, t)!,
      starFill: Color.lerp(starFill, other.starFill, t)!,
      onStar: Color.lerp(onStar, other.onStar, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      accountSky: Color.lerp(accountSky, other.accountSky, t)!,
      accountSkySubtle: Color.lerp(
        accountSkySubtle,
        other.accountSkySubtle,
        t,
      )!,
      accountBlue: Color.lerp(accountBlue, other.accountBlue, t)!,
      accountBlueSubtle: Color.lerp(
        accountBlueSubtle,
        other.accountBlueSubtle,
        t,
      )!,
      accountViolet: Color.lerp(accountViolet, other.accountViolet, t)!,
      accountVioletSubtle: Color.lerp(
        accountVioletSubtle,
        other.accountVioletSubtle,
        t,
      )!,
      accountMagenta: Color.lerp(accountMagenta, other.accountMagenta, t)!,
      accountMagentaSubtle: Color.lerp(
        accountMagentaSubtle,
        other.accountMagentaSubtle,
        t,
      )!,
      accountRose: Color.lerp(accountRose, other.accountRose, t)!,
      accountRoseSubtle: Color.lerp(
        accountRoseSubtle,
        other.accountRoseSubtle,
        t,
      )!,
      accountOlive: Color.lerp(accountOlive, other.accountOlive, t)!,
      accountOliveSubtle: Color.lerp(
        accountOliveSubtle,
        other.accountOliveSubtle,
        t,
      )!,
      accountSlate: Color.lerp(accountSlate, other.accountSlate, t)!,
      accountSlateSubtle: Color.lerp(
        accountSlateSubtle,
        other.accountSlateSubtle,
        t,
      )!,
      accountGraphite: Color.lerp(accountGraphite, other.accountGraphite, t)!,
      accountGraphiteSubtle: Color.lerp(
        accountGraphiteSubtle,
        other.accountGraphiteSubtle,
        t,
      )!,
      onAccount: Color.lerp(onAccount, other.onAccount, t)!,
      labelStoneBg: Color.lerp(labelStoneBg, other.labelStoneBg, t)!,
      labelStoneFg: Color.lerp(labelStoneFg, other.labelStoneFg, t)!,
      labelSandBg: Color.lerp(labelSandBg, other.labelSandBg, t)!,
      labelSandFg: Color.lerp(labelSandFg, other.labelSandFg, t)!,
      labelSageBg: Color.lerp(labelSageBg, other.labelSageBg, t)!,
      labelSageFg: Color.lerp(labelSageFg, other.labelSageFg, t)!,
      labelSeaBg: Color.lerp(labelSeaBg, other.labelSeaBg, t)!,
      labelSeaFg: Color.lerp(labelSeaFg, other.labelSeaFg, t)!,
      labelLilacBg: Color.lerp(labelLilacBg, other.labelLilacBg, t)!,
      labelLilacFg: Color.lerp(labelLilacFg, other.labelLilacFg, t)!,
      labelBlushBg: Color.lerp(labelBlushBg, other.labelBlushBg, t)!,
      labelBlushFg: Color.lerp(labelBlushFg, other.labelBlushFg, t)!,
      listItemBg: Color.lerp(listItemBg, other.listItemBg, t)!,
      listItemBgSelected: Color.lerp(
        listItemBgSelected,
        other.listItemBgSelected,
        t,
      )!,
      listItemFgUnread: Color.lerp(
        listItemFgUnread,
        other.listItemFgUnread,
        t,
      )!,
      listItemFgRead: Color.lerp(listItemFgRead, other.listItemFgRead, t)!,
      listItemMeta: Color.lerp(listItemMeta, other.listItemMeta, t)!,
      listItemDivider: Color.lerp(listItemDivider, other.listItemDivider, t)!,
      swipeArchiveBg: Color.lerp(swipeArchiveBg, other.swipeArchiveBg, t)!,
      swipeDeleteBg: Color.lerp(swipeDeleteBg, other.swipeDeleteBg, t)!,
      swipeSnoozeBg: Color.lerp(swipeSnoozeBg, other.swipeSnoozeBg, t)!,
      swipeReadBg: Color.lerp(swipeReadBg, other.swipeReadBg, t)!,
      swipeStarBg: Color.lerp(swipeStarBg, other.swipeStarBg, t)!,
      swipeStarFg: Color.lerp(swipeStarFg, other.swipeStarFg, t)!,
      swipeNeutralBg: Color.lerp(swipeNeutralBg, other.swipeNeutralBg, t)!,
      swipeFg: Color.lerp(swipeFg, other.swipeFg, t)!,
      swipeFgIdle: Color.lerp(swipeFgIdle, other.swipeFgIdle, t)!,
      drawerBg: Color.lerp(drawerBg, other.drawerBg, t)!,
      drawerItemBgActive: Color.lerp(
        drawerItemBgActive,
        other.drawerItemBgActive,
        t,
      )!,
      drawerItemFg: Color.lerp(drawerItemFg, other.drawerItemFg, t)!,
      drawerItemIcon: Color.lerp(drawerItemIcon, other.drawerItemIcon, t)!,
      drawerItemIconActive: Color.lerp(
        drawerItemIconActive,
        other.drawerItemIconActive,
        t,
      )!,
      avatarBadgeRing: Color.lerp(avatarBadgeRing, other.avatarBadgeRing, t)!,
      composerBg: Color.lerp(composerBg, other.composerBg, t)!,
      composerFieldDivider: Color.lerp(
        composerFieldDivider,
        other.composerFieldDivider,
        t,
      )!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipFg: Color.lerp(chipFg, other.chipFg, t)!,
      chipBgSelected: Color.lerp(chipBgSelected, other.chipBgSelected, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputBorderFocus: Color.lerp(
        inputBorderFocus,
        other.inputBorderFocus,
        t,
      )!,
      inputBorderError: Color.lerp(
        inputBorderError,
        other.inputBorderError,
        t,
      )!,
      snackbarBg: Color.lerp(snackbarBg, other.snackbarBg, t)!,
      snackbarFg: Color.lerp(snackbarFg, other.snackbarFg, t)!,
      snackbarAction: Color.lerp(snackbarAction, other.snackbarAction, t)!,
      fabBg: Color.lerp(fabBg, other.fabBg, t)!,
      fabFg: Color.lerp(fabFg, other.fabFg, t)!,
      switchTrackOn: Color.lerp(switchTrackOn, other.switchTrackOn, t)!,
      switchTrackOff: Color.lerp(switchTrackOff, other.switchTrackOff, t)!,
      switchThumbOn: Color.lerp(switchThumbOn, other.switchThumbOn, t)!,
      switchThumbOff: Color.lerp(switchThumbOff, other.switchThumbOff, t)!,
      tabIndicator: Color.lerp(tabIndicator, other.tabIndicator, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      bulkBarBg: Color.lerp(bulkBarBg, other.bulkBarBg, t)!,
      syncOk: Color.lerp(syncOk, other.syncOk, t)!,
      syncRunning: Color.lerp(syncRunning, other.syncRunning, t)!,
      syncError: Color.lerp(syncError, other.syncError, t)!,
    );
  }
}

abstract final class PostinoSpacing {
  /// Distanza fra badge account e avatar; micro-aggiustamenti.
  static const double s0_5 = 2.0;

  /// Gap icona–testo in chip e badge.
  static const double s1 = 4.0;

  /// Gap fra icona ed etichetta nei bottoni; padding verticale Compact.
  static const double s2 = 8.0;

  /// Gap fra colonne della riga; padding verticale Comfortable.
  static const double s3 = 12.0;

  /// Margine laterale mobile; padding di card e sheet.
  static const double s4 = 16.0;

  /// Padding orizzontale del composer.
  static const double s5 = 20.0;

  /// Margine laterale tablet/desktop; padding dei dialog.
  static const double s6 = 24.0;

  /// Fra messaggi espansi di un thread; padding degli empty state.
  static const double s8 = 32.0;

  /// Spazio sopra gli empty state.
  static const double s10 = 40.0;

  /// Padding superiore del dettaglio su desktop.
  static const double s12 = 48.0;

  /// Onboarding: aria fra blocchi.
  static const double s16 = 64.0;
}

abstract final class PostinoRadius {
  /// Checkbox, tasti scorciatoia.
  static const double xs = 4.0;

  /// Bottoni, input, voci di drawer, chip etichetta.
  static const double sm = 8.0;

  /// Card, menu, snackbar, chip allegato, banner.
  static const double md = 12.0;

  /// FAB, composer, dialog.
  static const double lg = 16.0;

  /// Angoli superiori del bottom sheet; SearchBar M3.
  static const double xl = 28.0;

  /// Avatar, badge, chip contatto e filtro, pallino non letto.
  static const double full = 999.0;
}

abstract final class PostinoSize {
  /// Area minima di tocco su iOS (HIG). Flutter: kMinInteractiveDimensionCupertino.
  static const double touchTargetIos = 44.0;

  /// Area minima di tocco su Android (M3). Flutter: kMinInteractiveDimension.
  static const double touchTargetAndroid = 48.0;

  /// Icone dentro chip, righe e meta.
  static const double iconSm = 16.0;

  /// Icone in bottoni e campi.
  static const double iconMd = 20.0;

  /// Icone di AppBar, drawer, swipe, bulk bar.
  static const double iconLg = 24.0;

  /// Bottoni piccoli e chip (area di tocco estesa a 44/48 con padding).
  static const double controlSm = 32.0;

  /// Bottoni, input, SearchBar.
  static const double controlMd = 40.0;

  /// Bottoni di onboarding e dialog su mobile.
  static const double controlLg = 48.0;

  /// Altezza AppBar (Android 64 con titolo grande: usa large-title).
  static const double appBarHeight = 56.0;

  /// FAB “Scrivi” esteso.
  static const double fabHeight = 56.0;

  /// Avatar in chip contatto e riga Compact.
  static const double avatarSm = 24.0;

  /// Avatar in riga Comfortable e header del messaggio.
  static const double avatarMd = 40.0;

  /// Avatar nel selettore account e nelle impostazioni.
  static const double avatarLg = 56.0;

  /// Badge account sull’avatar (iniziale a 10px).
  static const double accountBadge = 16.0;

  /// AccountMark standalone: drawer, selettore “Da”, filtri.
  static const double accountMark = 24.0;

  /// NavigationDrawer modale su mobile.
  static const double drawerWidth = 304.0;

  /// Drawer fisso su desktop.
  static const double sidebarWidth = 280.0;

  /// Colonna lista su tablet/desktop (min 320).
  static const double listWidth = 380.0;

  /// Larghezza massima della colonna di lettura (testata e testo; i corpi HTML la superano).
  static const double readingMaxWidth = 800.0;

  /// Da qui: lista + dettaglio (tablet). Window size class “medium”.
  static const double breakpointMedium = 600.0;

  /// Da qui: drawer fisso + lista. Size class “expanded”.
  static const double breakpointExpanded = 840.0;

  /// Da qui: drawer fisso + lista + dettaglio affiancato.
  static const double breakpointLarge = 1400.0;
}

abstract final class PostinoBorder {
  /// Filetti border-subtle tra righe e pannelli.
  static const double borderWidthHairline = 1.0;

  /// Bordo di input e bottoni secondari (border-strong).
  static const double borderWidthControl = 1.0;

  /// Anello focus-ring.
  static const double borderWidthFocus = 2.0;

  /// Distanza dell’anello dal controllo.
  static const double focusOffset = 2.0;

  /// Barra colore account sul bordo sinistro della riga in inbox unificata.
  static const double accountBarWidth = 3.0;

  /// Anello avatar-badge-ring attorno al badge account.
  static const double accountBadgeRing = 2.0;
}

/// Densità della lista: Comfortable (default) e Compact.
@immutable
class PostinoDensity extends ThemeExtension<PostinoDensity> {
  const PostinoDensity({
    required this.rowHeight,
    required this.padY,
    required this.avatar,
    required this.previewLines,
    required this.gap,
  });
  final double rowHeight, padY, avatar, gap;
  final int previewLines;

  static const comfortable = PostinoDensity(
    rowHeight: 88.0,
    padY: 12.0,
    avatar: 40.0,
    previewLines: 1,
    gap: 12.0,
  );
  static const compact = PostinoDensity(
    rowHeight: 60.0,
    padY: 8.0,
    avatar: 0.0,
    previewLines: 0,
    gap: 8.0,
  );

  /// Compact col puntatore (desktop).
  static const compactPointer = PostinoDensity(
    rowHeight: 40.0,
    padY: 8.0,
    avatar: 0.0,
    previewLines: 0,
    gap: 8.0,
  );

  @override
  PostinoDensity copyWith({
    double? rowHeight,
    double? padY,
    double? avatar,
    int? previewLines,
    double? gap,
  }) => PostinoDensity(
    rowHeight: rowHeight ?? this.rowHeight,
    padY: padY ?? this.padY,
    avatar: avatar ?? this.avatar,
    previewLines: previewLines ?? this.previewLines,
    gap: gap ?? this.gap,
  );

  @override
  PostinoDensity lerp(PostinoDensity? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Motion: durate e curve. Rispetta MediaQuery.disableAnimations (vedi PostinoMotion.of).
abstract final class PostinoMotion {
  /// Hover, pressione, selezione. Flutter: Durations.short2.
  static const Duration state = Durations.short2;

  /// Switch, checkbox, stella. Flutter: Durations.short3.
  static const Duration toggle = Durations.short3;

  /// Riga che torna in posizione se lo swipe non supera la soglia. Flutter: Durations.short4.
  static const Duration swipeSettle = Durations.short4;

  /// Riga che esce e lista che si richiude dopo un’azione. Flutter: Durations.medium1.
  static const Duration swipeDismiss = Durations.medium1;

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

  /// Tempo in cui “Annulla” resta disponibile (invio, archivia, elimina). Flutter: SnackBar.duration.
  static const Duration undoWindow = Duration(milliseconds: 8000);

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
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Scala tipografica (come KeyVault): Caprasimo per i titoli, Figtree per il testo, monospace di sistema per header grezzi. Il colore viene dal tema.
abstract final class PostinoText {
  static const serif = 'Caprasimo';
  static const sans = 'Figtree';
  static const mono = 'monospace';
  static const monoFallback = ['SFMono-Regular', 'Menlo', 'Consolas'];

  /// Titolo grande della schermata, onboarding. Flutter: textTheme.displaySmall.
  static const largeTitle = TextStyle(
    fontFamily: serif,
    fontSize: 34.0,
    height: 1.1765,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.51,
  );

  /// Titoli di empty state e onboarding. Flutter: headlineMedium.
  static const display = TextStyle(
    fontFamily: serif,
    fontSize: 30.0,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.45,
  );

  /// Oggetto del thread, titoli di sezione delle impostazioni. Flutter: headlineSmall.
  static const title = TextStyle(
    fontFamily: serif,
    fontSize: 24.0,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.36,
  );

  /// Titolo di dialog e bottom sheet. Flutter: titleLarge.
  static const sheetTitle = TextStyle(
    fontFamily: serif,
    fontSize: 20.0,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
  );

  /// Titolo dell’AppBar compatta, Caprasimo come gli altri titoli. AppBarTheme.titleTextStyle.
  static const appBarTitle = TextStyle(
    fontFamily: serif,
    fontSize: 17.0,
    height: 1.2941,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.255,
  );

  /// Mittente non letto in lista e header del messaggio. Flutter: titleMedium.
  static const sender = TextStyle(
    fontFamily: sans,
    fontSize: 16.0,
    height: 1.375,
    fontWeight: FontWeight.w600,
  );

  /// Mittente letto in lista. Flutter: PostinoText.senderRead.
  static const senderRead = TextStyle(
    fontFamily: sans,
    fontSize: 16.0,
    height: 1.375,
    fontWeight: FontWeight.w400,
  );

  /// Oggetto non letto in lista. Flutter: titleSmall.
  static const subject = TextStyle(
    fontFamily: sans,
    fontSize: 15.0,
    height: 1.3333,
    fontWeight: FontWeight.w600,
  );

  /// Oggetto letto in lista. Flutter: PostinoText.subjectRead.
  static const subjectRead = TextStyle(
    fontFamily: sans,
    fontSize: 15.0,
    height: 1.3333,
    fontWeight: FontWeight.w400,
  );

  /// Anteprima sotto l’oggetto, in ink-muted, 1 riga (Comfortable). Flutter: bodyMedium.
  static const preview = TextStyle(
    fontFamily: sans,
    fontSize: 14.0,
    height: 1.4286,
    fontWeight: FontWeight.w400,
  );

  /// Corpo del messaggio e del composer: interlinea 1.625 e misura max reading-max-width per la lettura lunga. Flutter: bodyLarge.
  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 16.0,
    height: 1.625,
    fontWeight: FontWeight.w400,
  );

  /// Testo citato, firma e intestazioni di citazione, in ink-muted. Flutter: PostinoText.bodyQuote.
  static const bodyQuote = TextStyle(
    fontFamily: sans,
    fontSize: 15.0,
    height: 1.6,
    fontWeight: FontWeight.w400,
  );

  /// Ora, dimensione allegato, conteggio thread; cifre tabellari. Flutter: labelSmall.
  static const meta = TextStyle(
    fontFamily: sans,
    fontSize: 12.0,
    height: 1.3333,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Ora di un messaggio non letto. Flutter: PostinoText.metaStrong.
  static const metaStrong = TextStyle(
    fontFamily: sans,
    fontSize: 12.0,
    height: 1.3333,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Bottoni, voci di drawer, tab, voci di menu. Flutter: labelLarge.
  static const label = TextStyle(
    fontFamily: sans,
    fontSize: 15.0,
    height: 1.3333,
    fontWeight: FontWeight.w600,
  );

  /// Chip, badge, bottoni piccoli. Flutter: labelMedium.
  static const labelSm = TextStyle(
    fontFamily: sans,
    fontSize: 13.0,
    height: 1.3846,
    fontWeight: FontWeight.w600,
  );

  /// Testo di aiuto sotto i campi, stati di sync. Flutter: bodySmall.
  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 12.0,
    height: 1.3333,
    fontWeight: FontWeight.w400,
  );

  /// Intestazioni di gruppo nel drawer, maiuscolo. Flutter: PostinoText.overline.
  static const overline = TextStyle(
    fontFamily: sans,
    fontSize: 11.0,
    height: 1.2727,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
  );

  /// Header grezzi, codice nel corpo. Famiglia mono. Flutter: PostinoText.code.
  static const code = TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: 13.0,
    height: 1.5385,
    fontWeight: FontWeight.w400,
  );

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
