// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_fade_switcher.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_unread_dot.dart';

/// The header of a collapsible section of `PostinoNavigationDrawer` (not in the barrel), a button 48 high:
/// the [account] mark, [title] in capitals and a chevron (down closed, up open); [collapsed], in the icon rail, only
/// the chevron in 48×48 with [title] as tooltip. [unreadLabel], set while the section is closed and holds unread
/// mail, adds the unread dot and is read with the title.
class const PostinoDrawerSectionHeader({
  super.key,

  /// Nome della sezione, anche nome accessibile del pulsante.
  required final String title,

  /// Se la sezione è aperta.
  required final bool expanded,

  /// Apre o chiude la sezione.
  required final VoidCallback onToggle,

  /// Barra a icone: solo il chevron.
  required final bool collapsed,

  /// Account di cui mostrare il segno prima del titolo.
  final PostinoAccountRef? account,

  /// Se impostata, la sezione chiusa ha non letti: nome del puntino.
  final String? unreadLabel,

  /// La voce attiva è nascosta nella sezione chiusa: l'intestazione la rappresenta.
  final bool selected = false,
}) extends StatelessWidget {
  /// Crea l'intestazione che apre e chiude la sezione.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.sm));
    final chevron = AnimatedRotation(
      turns: expanded ? .5 : 0,
      duration: PostinoMotion.of(context, PostinoMotion.threadExpand),
      curve: PostinoMotion.standard,
      child: PostinoIcon(PostinoIcons.chevronDown, size: PostinoSize.iconSm, color: c.inkMuted),
    );
    // Fades in and out like the items' dot (`duration-toggle`); absent, it takes no room.
    Widget dot({EdgeInsetsGeometry gap = EdgeInsets.zero}) => PostinoFadeSwitcher(
      duration: PostinoMotion.toggle,
      child: unreadLabel == null ? const SizedBox.shrink() : Padding(padding: gap, child: const PostinoUnreadDot()),
    );
    // Like PostinoMessageRecipients: one button that says its state; Enter/Space through the InkWell.
    return Semantics(
      key: const ValueKey('drawer-section-toggle'),
      button: true,
      expanded: expanded,
      selected: selected ? true : null,
      label: [title, unreadLabel].nonNulls.join(', '),
      onTap: onToggle,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? c.drawerItemBgActive : Colors.transparent,
          ),
          onTap: onToggle,
          child: PostinoFocusRing(
            inset: !collapsed,
            borderRadius: radius,
            child: collapsed
                ? Tooltip(
                    message: title,
                    excludeFromSemantics: true,
                    child: SizedBox.square(
                      dimension: PostinoSize.touchTargetAndroid,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          chevron,
                          Positioned(top: PostinoSpacing.s1 + 2, right: PostinoSpacing.s1 + 2, child: dot()),
                        ],
                      ),
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
                    padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
                    child: Row(
                      children: [
                        if (account case final a?) ...[
                          PostinoAccountMark(color: a.color, initial: a.initial, size: PostinoSize.iconSm),
                          const SizedBox(width: PostinoSpacing.s2),
                        ],
                        Expanded(
                          child: Text(title.toUpperCase(), style: PostinoText.overline.copyWith(color: c.inkSubtle)),
                        ),
                        dot(gap: const EdgeInsetsDirectional.symmetric(horizontal: PostinoSpacing.s2)),
                        chevron,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
