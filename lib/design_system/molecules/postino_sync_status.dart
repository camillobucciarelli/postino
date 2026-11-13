// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Lo stato della sincronizzazione mostrato.
enum PostinoSyncState() {
  /// Una sincronizzazione è in corso: l'icona ruota.
  syncing,

  /// L'ultima sincronizzazione è riuscita.
  ok,

  /// L'ultima sincronizzazione non è riuscita.
  error,

  /// Non c'è rete.
  offline,

  /// L'Account va ricollegato.
  reconnect,
}

/// The sync state of a mailbox: icon and words, or only the icon ([compact], drawer) with [label] as its name.
/// With [onRetry] the words are followed by the [retryLabel] text button («Riprova»). Enlarged text wraps.
class const PostinoSyncStatus({
  super.key,

  /// Quale stato mostrare.
  required final PostinoSyncState state,

  /// Parola mostrata, o nome per lo screen reader se `compact`.
  required final String label,

  /// Solo l'icona, per la sidebar.
  final bool compact = false,

  /// Nome del pulsante che riprova, mostrato con [onRetry].
  final String retryLabel = '',

  /// Chiamata da «Riprova»; se nulla il pulsante non c'è.
  final VoidCallback? onRetry,
}) extends StatelessWidget {
  /// Crea lo stato di sincronizzazione.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final (glyph, color) = switch (state) {
      PostinoSyncState.syncing => (PostinoIcons.refresh, c.syncRunning),
      PostinoSyncState.ok => (PostinoIcons.check, c.syncOk),
      PostinoSyncState.error => (PostinoIcons.alert, c.syncError),
      PostinoSyncState.offline => (PostinoIcons.cloudOff, c.warning),
      PostinoSyncState.reconnect => (PostinoIcons.key, c.warning),
    };
    Widget icon = PostinoIcon(glyph, size: PostinoSize.iconSm, color: color, label: compact ? label : null);
    if (state == PostinoSyncState.syncing && !MediaQuery.disableAnimationsOf(context)) icon = _Spinning(child: icon);
    if (compact) return icon;
    final retry = onRetry;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Row(
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
          // A 48 tap target on the phone too: the theme pads it (materialTapTargetSize).
          if (retry != null)
            PostinoButton(
              label: retryLabel,
              onPressed: retry,
              variant: PostinoButtonVariant.ghost,
              size: PostinoButtonSize.sm,
            ),
        ],
      ),
    );
  }
}

/// The row's height at 100%, without «Riprova».
const double _rowHeight = 32;

/// Turns its child once per [PostinoMotion.syncSpin], for as long as it is shown.
class const _Spinning({required final Widget child}) extends StatefulWidget {
  @override
  State<_Spinning> createState() => _SpinningState();
}

class _SpinningState() extends State<_Spinning> with SingleTickerProviderStateMixin {
  late final _turns = AnimationController(vsync: this, duration: PostinoMotion.syncSpin)..repeat();

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _turns, child: widget.child);
}
