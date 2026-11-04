import 'package:flutter/widgets.dart';

import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Only the states the app has so far; add ok/syncing/error with their screens.
enum PostinoSyncState { reconnect, offline }

/// The sync state of a mailbox: icon and word, or only the icon ([compact], drawer) with [label] as its name.
class PostinoSyncStatus extends StatelessWidget {
  const PostinoSyncStatus({super.key, required this.state, required this.label, this.compact = false});

  final PostinoSyncState state;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final icon = PostinoIcon(
      state == PostinoSyncState.reconnect ? PostinoIcons.key : PostinoIcons.cloudOff,
      size: PostinoSize.iconSm,
      color: c.warning,
      label: compact ? label : null,
    );
    if (compact) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        icon,
        Flexible(
          child: Text(
            label,
            style: PostinoText.caption.copyWith(
              color: c.inkMuted,
              fontWeight: FontWeight.w600, // thin glyphs sample under 4.5:1
            ),
          ),
        ),
      ],
    );
  }
}
