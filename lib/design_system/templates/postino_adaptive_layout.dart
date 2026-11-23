// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:postino/design_system/templates/postino_list_detail_layout.dart' show PostinoListDetailLayout;

import '../organisms/postino_navigation_drawer.dart' show PostinoSidebarScope;
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_single_pane_layout.dart';

/// Picks the layout from the window width (Material 3 size classes):
/// below `breakpoint-expanded` (840) one pane with a modal [drawer];
/// from 840 the [drawer] is not shown here: the caller docks it once with [PostinoSidebarShell],
/// outside the pages, so it survives navigation.
/// The list + detail split is [PostinoListDetailLayout]'s, around this.
// ponytail: 600–839 stays one pane (the Conversazione a full page); LayoutTablet's two panes if tablets need them.
class const PostinoAdaptiveLayout({
  super.key,

  /// Barra superiore della schermata.
  required final Widget appBar,

  /// Contenuto principale della schermata.
  required final Widget body,

  /// Drawer di navigazione, usato sotto la soglia di larghezza espansa.
  required final Widget drawer,

  /// Banner mostrati sopra il contenuto.
  final List<Widget> banners = const [],

  /// Pulsante di azione flottante facoltativo, sovrapposto al contenuto.
  final Widget? fab,
}) extends StatelessWidget {
  /// Crea il layout adattivo in base alla larghezza della finestra.
  this;

  @override
  Widget build(BuildContext context) {
    final docked = MediaQuery.sizeOf(context).width >= PostinoSize.breakpointExpanded;
    return PostinoSinglePaneLayout(
      appBar: appBar,
      body: body,
      // Open, the modal drawer tells the system its Indietro is the app's (#365): the route's PopScope closes it.
      drawer: docked ? null : PopScope(canPop: false, child: drawer),
      banners: banners,
      fab: fab,
    );
  }
}

/// Opens or closes the docked sidebar (the shortcut of the Posta views sends it).
class const ToggleSidebarIntent() extends Intent {
  /// Crea l'intent per aprire o chiudere la barra laterale.
  this;
}

/// From `breakpoint-expanded` (840) docks [drawer] beside [child]; below it just [child], in the same
/// tree so its State survives the resize. Built once above the pages, so the [drawer] State outlives navigation.
/// Docked, the sidebar is `sidebar-width` (280) from `breakpoint-sidebar-collapse` (1440) and icons only
/// (`sidebar-collapsed-width`, 72) below it. A manual choice ([expanded] at the start, then the button or
/// [ToggleSidebarIntent]) holds until the window crosses 1440 either way; each change goes to [onExpandedChanged]
/// (null: no choice, the width decides). Opening or closing it slides its width over [PostinoMotion.menuIndicator]
/// (#283): the extended drawer is laid out at its full width and cut at the moving edge, and only once the edge is
/// back at `sidebar-collapsed-width` does it turn to icons, so nothing is squeezed; the button's name changes at once.
class const PostinoSidebarShell({
  super.key,

  /// Contenuto della barra laterale, mostrato solo quando la finestra è abbastanza larga.
  required final Widget drawer,

  /// Contenuto principale, sempre visibile accanto alla barra laterale.
  required final Widget child,

  /// The button's name while the sidebar is extended / icons only.
  required final String closeLabel,

  /// Nome del pulsante quando la barra laterale è ridotta a icone.
  required final String openLabel,

  /// Scelta iniziale dell'utente sull'apertura della barra; null lascia decidere la larghezza.
  final bool? expanded,

  /// Chiamato a ogni cambio di stato della barra, con null quando la decisione torna alla larghezza.
  final ValueChanged<bool?>? onExpandedChanged,
}) extends StatefulWidget {
  /// Crea lo shell con la barra laterale, il contenuto e le etichette dei pulsanti.
  this;

  @override
  State<PostinoSidebarShell> createState() => _PostinoSidebarShellState();
}

class _PostinoSidebarShellState() extends State<PostinoSidebarShell> {
  late bool? _manual = widget.expanded;
  double? _width;

  static bool _extended(double width) => width >= PostinoSize.breakpointSidebarCollapse;

  void _choose(bool? expanded) {
    setState(() => _manual = expanded);
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    // Crossing the threshold either way gives the decision back to the width.
    if (_manual != null && _width != null && _extended(_width!) != _extended(width)) {
      _manual = null;
      widget.onExpandedChanged?.call(null);
    }
    _width = width;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final docked = width >= PostinoSize.breakpointExpanded;
    final expanded = _manual ?? _extended(width);
    void toggle() => _choose(!expanded);
    final c = context.pc;
    // Always the same Row, the drawer slot only when docked: crossing 840 keeps the [child] State
    // (scroll, expansions, an open Conversazione).
    return Actions(
      actions: {
        ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
          onInvoke: (_) {
            if (docked) toggle();
            return null;
          },
        ),
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (docked)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: c.borderSubtle)),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: expanded ? PostinoSize.sidebarWidth : PostinoSize.sidebarCollapsedWidth),
                duration: PostinoMotion.of(context, PostinoMotion.menuIndicator),
                curve: PostinoMotion.emphasized,
                builder: (context, width, drawer) {
                  final icons = width <= PostinoSize.sidebarCollapsedWidth;
                  final layout = icons ? PostinoSize.sidebarCollapsedWidth : PostinoSize.sidebarWidth;
                  return SizedBox(
                    width: width,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: AlignmentDirectional.centerStart,
                        minWidth: layout,
                        maxWidth: layout,
                        child: PostinoSidebarScope(
                          collapsed: icons,
                          toggleLabel: expanded ? widget.closeLabel : widget.openLabel,
                          toggle: toggle,
                          child: DrawerTheme(
                            data: DrawerThemeData(
                              width: layout,
                              elevation: PostinoElevation.e0,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: drawer!,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: widget.drawer,
              ),
            ),
          Expanded(key: const ValueKey('content'), child: widget.child),
        ],
      ),
    );
  }
}
