// postino_theme.dart — costruisce ThemeData dai token. Scritto a mano, usa postino_tokens.dart.
// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'postino_tokens.dart';

/// Costruisce i `ThemeData` chiaro e scuro dai token.
abstract final class PostinoTheme() {
  /// Non istanziabile: solo membri statici.
  this;

  /// Tema chiaro con la densità data.
  static ThemeData light({PostinoDensity density = PostinoDensity.comfortable}) =>
      _build(Brightness.light, PostinoColors.light, density);

  /// Tema scuro con la densità data.
  static ThemeData dark({PostinoDensity density = PostinoDensity.comfortable}) =>
      _build(Brightness.dark, PostinoColors.dark, density);

  static ThemeData _build(Brightness b, PostinoColors c, PostinoDensity d) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandSubtle,
      onPrimaryContainer: c.ink,
      secondary: c.brandHover,
      onSecondary: c.onBrand,
      secondaryContainer: c.surfaceSelected,
      onSecondaryContainer: c.ink, // indicatore di NavigationDrawer/NavigationBar
      tertiary: c.star,
      onTertiary: c.onWarning,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerSubtle,
      onErrorContainer: c.ink,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceDim: c.surfaceGround,
      surfaceBright: c.surfaceRaised,
      surfaceContainerLowest: c.surfaceRaised,
      surfaceContainerLow: c.surfaceRaised,
      surfaceContainer: c.surfaceGround,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfacePressed,
      outline: c.borderStrong,
      outlineVariant: c.borderSubtle,
      inverseSurface: c.surfaceInverse,
      onInverseSurface: c.inkInverse,
      inversePrimary: c.brandInverse,
      scrim: c.scrim,
      shadow: const Color(0xFF000000),
      surfaceTint: Colors.transparent,
    );
    final text = PostinoText.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: PostinoText.sans,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      dividerTheme: DividerThemeData(
        color: c.borderSubtle,
        thickness: PostinoBorder.borderWidthHairline,
        space: PostinoBorder.borderWidthHairline,
      ),
      // A light veil under the focus ring; with hover or pressed over it the row texts keep 4.5:1.
      focusColor: c.focusRing.withValues(alpha: 0.06),
      hoverColor: c.overlayHover,
      splashColor: c.overlayPressed,
      highlightColor: Colors.transparent,
      materialTapTargetSize: MaterialTapTargetSize.padded, // 48dp su Android
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: PostinoElevation.e0,
        scrolledUnderElevation: 3,
        toolbarHeight: PostinoSize.appBarHeight,
        titleTextStyle: PostinoText.appBarTitle.copyWith(color: c.ink),
      ),
      drawerTheme: const DrawerThemeData(
        width: PostinoSize.drawerWidth,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(PostinoRadius.lg))),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: c.drawerBg,
        indicatorColor: c.drawerItemBgActive,
        indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.sm))),
        tileHeight: PostinoSize.touchTargetAndroid,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        elevation: PostinoElevation.e2,
        extendedTextStyle: PostinoText.label,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.lg))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          minimumSize: const Size(64, PostinoSize.controlMd),
          textStyle: PostinoText.label,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.sm))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.borderStrong),
          minimumSize: const Size(64, PostinoSize.controlMd),
          textStyle: PostinoText.label,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.sm))),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.brand, textStyle: PostinoText.label),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputBg,
        hintStyle: TextStyle(color: c.inkSubtle),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
          borderSide: BorderSide(color: c.inputBorderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
          borderSide: BorderSide(color: c.inputBorderError),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(c.inputBg),
        elevation: const WidgetStatePropertyAll(PostinoElevation.e1),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        hintStyle: WidgetStatePropertyAll(PostinoText.preview.copyWith(color: c.inkSubtle)),
        constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.chipBg,
        selectedColor: c.chipBgSelected,
        labelStyle: PostinoText.labelSm.copyWith(color: c.chipFg),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.snackbarBg,
        contentTextStyle: PostinoText.label.copyWith(color: c.snackbarFg),
        actionTextColor: c.snackbarAction,
        behavior: SnackBarBehavior.floating,
        elevation: PostinoElevation.e3,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.md))),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: c.warningSubtle,
        contentTextStyle: PostinoText.preview.copyWith(color: c.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: PostinoElevation.e3,
        titleTextStyle: PostinoText.sheetTitle.copyWith(color: c.ink),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.lg))),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalElevation: 8,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(PostinoRadius.xl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: PostinoElevation.e3,
        textStyle: PostinoText.label.copyWith(color: c.ink),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.md))),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          elevation: const WidgetStatePropertyAll(PostinoElevation.e3),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: c.tabIndicator,
        labelColor: c.ink,
        unselectedLabelColor: c.inkMuted,
        labelStyle: PostinoText.label,
        dividerColor: c.borderSubtle,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.switchTrackOn : c.switchTrackOff,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.switchThumbOn : c.switchThumbOff,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onBrand),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.xs))),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: c.listItemBg,
        selectedTileColor: c.listItemBgSelected,
        iconColor: c.inkMuted,
        minTileHeight: d.rowHeight,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceInverse,
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.xs)),
        ),
        textStyle: PostinoText.labelSm.copyWith(color: c.inkInverse),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [c, d],
    );
  }
}

/// Scorciatoie per leggere i token dal tema corrente.
extension PostinoContext on BuildContext {
  /// Colori semantici del tema corrente.
  PostinoColors get pc => Theme.of(this).extension<PostinoColors>()!;

  /// Densità della lista del tema corrente.
  PostinoDensity get density => Theme.of(this).extension<PostinoDensity>()!;
}
