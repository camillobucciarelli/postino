// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_fade_switcher.dart';
import '../atoms/postino_icon_button.dart';
import '../molecules/postino_menu.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The bar on top of a list: `menu` opening the drawer, title and a `meta` subtitle saying where you are.
/// Inside one Account its mark sits next to the title. With [onBack] (a detail) it leads with `arrow-left` instead;
/// [actions] sit at the end («Chiudi» of the composer). [commands] sit before them as icon buttons while they fit;
/// those that do not go, in order, into a «more» menu ([moreLabel]), so a narrow pane never squeezes the title
/// below nothing. A [toolbar] (the Azioni of a Conversazione) takes the title's place and the whole room after the
/// back arrow.
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

  /// Comandi con icona prima di [actions]: quelli che non ci stanno finiscono nel menu [moreLabel].
  final List<PostinoMenuItem> commands = const [],

  /// Nome del menu che raccoglie i [commands] che non ci stanno («Altre azioni»).
  final String moreLabel = '',

  /// Al posto del titolo, una barra di Azioni (PostinoActionBar) che prende tutto lo spazio dopo la freccia.
  final Widget? toolbar,
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
        // The title's room in the NavigationToolbar: no leading square, no trailing actions, spacing on both sides.
        // ponytail: actions counted as icon buttons (one tap target each); a wider action needs measuring.
        final free =
            box.maxWidth -
            MediaQuery.paddingOf(context).horizontal -
            (leading ? kToolbarHeight : 0) -
            actions.length * kMinInteractiveDimension -
            2 * spacing;
        // The commands that fit beside a title of at least [_minTitle]; one slot goes to the menu of the others.
        final slots = ((free - _minTitle) / kMinInteractiveDimension).floor().clamp(0, commands.length);
        final shown = slots >= commands.length ? commands.length : (slots - 1).clamp(0, commands.length);
        final trailing = [
          for (final c in commands.take(shown))
            PostinoIconButton(icon: c.icon!, label: c.label, onPressed: c.onPressed, shortcut: c.shortcut, key: c.key),
          if (shown < commands.length) PostinoMenu(label: moreLabel, items: commands.skip(shown).toList()),
          ...actions,
        ];
        final room = (free - (trailing.length - actions.length) * kMinInteractiveDimension).clamp(0.0, double.infinity);
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
          // Actions that come once the content is there (a Conversazione loaded, #283) fade in; at the first build
          // they are just there.
          actions: [
            PostinoFadeSwitcher(
              child: trailing.isEmpty
                  ? const SizedBox.shrink()
                  : Row(key: const ValueKey('actions'), mainAxisSize: MainAxisSize.min, children: trailing),
            ),
          ],
          titleSpacing: spacing,
          centerTitle: toolbar != null ? false : null,
          // The AppBar clamps its title to 1.34 and sets `softWrap: false`: undo both, the text is at the user's size.
          title:
              toolbar ??
              MediaQuery(
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

/// The title's room kept before a command goes into the «more» menu.
const double _minTitle = 48;
