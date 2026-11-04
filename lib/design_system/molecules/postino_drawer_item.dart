import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../tokens/postino_icons.dart';

/// A destination of the drawer: an [icon] or an [account] mark, and, for an Account Da ricollegare,
/// the compact SyncStatus named [reconnectLabel]. [unreadLabel] ("Non letto") is set when it holds unread mail:
/// both sidebars show it as a dot and read it out.
class PostinoDrawerItem {
  const PostinoDrawerItem({
    required this.label,
    required this.onTap,
    this.key,
    this.active = false,
    this.icon,
    this.account,
    this.reconnectLabel,
    this.unreadLabel,
  });

  final String label;
  final VoidCallback onTap;
  final Key? key;
  final bool active;
  final PostinoIconData? icon;
  final PostinoAccountRef? account;
  final String? reconnectLabel;
  final String? unreadLabel;
}
