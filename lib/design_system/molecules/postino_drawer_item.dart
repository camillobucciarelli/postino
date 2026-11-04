import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../tokens/postino_icons.dart';

/// A destination of the drawer: an [icon] or an [account] mark, and, for an Account Da ricollegare,
/// the compact SyncStatus named [reconnectLabel]. [unreadLabel] ("Non letto") is set when it holds unread mail:
/// both sidebars show it as a dot and read it out.
class const PostinoDrawerItem({
  /// Nome della destinazione.
  required final String label,

  /// Chiamata al tocco; il drawer si chiude prima.
  required final VoidCallback onTap,

  /// Chiave per i test, sull'elemento tappabile.
  final Key? key,

  /// Destinazione corrente, evidenziata.
  final bool active = false,

  /// Icona mostrata quando non c'è un `account`.
  final PostinoIconData? icon,

  /// Account di cui mostrare il segno al posto dell'icona.
  final PostinoAccountRef? account,

  /// Se impostata, l'Account è Da ricollegare: nome dello stato compatto.
  final String? reconnectLabel,

  /// Se impostata, ci sono messaggi non letti: nome del puntino.
  final String? unreadLabel,
}) {
  /// Crea una destinazione del drawer.
  this;
}
