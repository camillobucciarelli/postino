import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_icon_button.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The bar on top of a list: `menu` opening the drawer, title and a `meta` subtitle saying where you are.
/// Inside one Account its mark sits next to the title. With [onBack] (a detail) it leads with `arrow-left` instead;
/// [actions] sit at the end («Chiudi» of the composer).
class const PostinoAppBar({
  super.key,

  /// Titolo mostrato nella barra.
  required final String title,

  /// Sottotitolo facoltativo che indica dove si trova l'utente.
  final String? subtitle,

  /// Account a cui appartiene la schermata: se presente ne mostra il contrassegno accanto al titolo.
  final PostinoAccountRef? account,

  /// Azione del pulsante indietro: se presente sostituisce il menu con la freccia.
  final VoidCallback? onBack,

  /// Widget posti a fine barra, per esempio il pulsante «Chiudi» del compositore.
  final List<Widget> actions = const [],
}) extends StatelessWidget implements PreferredSizeWidget {
  /// Barra superiore di una lista o di un dettaglio.
  this;

  /// The height at 100%; with enlarged text the bar grows.
  @override
  Size get preferredSize => const Size.fromHeight(PostinoSize.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = account;
    // No `menu` where the drawer is docked beside the list.
    final scaffold = Scaffold.maybeOf(context);
    final menu = onBack == null && scaffold != null && scaffold.hasDrawer;
    final back = onBack;
    final leading = back != null || menu;
    final spacing = leading ? PostinoSpacing.s1 : PostinoSpacing.s4;
    final scaler = MediaQuery.textScalerOf(context);
    // Enlarged text wraps instead of being cut, and the bar grows to hold it.
    final wrap = scaler.scale(1) > 1;
    final titleStyle = PostinoText.appBarTitle.copyWith(color: c.ink);
    // The title's DefaultTextStyle is the AppBar's, so the subtitle inherits what `meta` leaves out.
    final subtitleStyle = PostinoText.appBarTitle.merge(PostinoText.meta.copyWith(color: c.inkSubtle));
    return LayoutBuilder(
      builder: (context, box) {
        // The title's room in the NavigationToolbar: no leading square, spacing on both sides.
        final room =
            box.maxWidth - MediaQuery.paddingOf(context).horizontal - (leading ? kToolbarHeight : 0) - 2 * spacing;
        double height(String text, TextStyle style, double width) {
          final p = TextPainter(
            text: TextSpan(text: text, style: style),
            textScaler: scaler,
            textDirection: Directionality.of(context),
            maxLines: wrap ? null : 1,
          )..layout(maxWidth: width);
          final h = p.height;
          p.dispose();
          return h;
        }

        final content =
            height(title, titleStyle, room - (a == null ? 0 : _markSize + PostinoSpacing.s2)) +
            (subtitle == null ? 0 : height(subtitle!, subtitleStyle, room));
        return AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: wrap
              ? (content + 2 * PostinoSpacing.s2).clamp(PostinoSize.appBarHeight, double.infinity)
              : PostinoSize.appBarHeight,
          leading: back != null
              ? PostinoIconButton(
                  icon: PostinoIcons.arrowLeft,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: back,
                )
              : menu
              ? PostinoIconButton(
                  icon: PostinoIcons.menu,
                  label: MaterialLocalizations.of(context).openAppDrawerTooltip,
                  onPressed: scaffold.openDrawer,
                )
              : null,
          actions: actions,
          titleSpacing: spacing,
          // The AppBar clamps its title to 1.34 and sets `softWrap: false`: undo both, the text is at the user's size.
          title: MediaQuery(
            data: MediaQuery.of(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: PostinoSpacing.s2,
                  children: [
                    if (a != null) PostinoAccountMark(color: a.color, initial: a.initial, size: _markSize),
                    Flexible(
                      child: Text(
                        title,
                        softWrap: true,
                        maxLines: wrap ? null : 1,
                        overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                  ],
                ),
                if (subtitle case final s?)
                  Text(
                    s,
                    softWrap: true,
                    maxLines: wrap ? null : 1,
                    overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: PostinoText.meta.copyWith(color: c.inkSubtle),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const double _markSize = 22;
