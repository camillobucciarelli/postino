import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One row of the details of a message (“Da”, “A”, “Data”, “Ricevuto su”); [account] puts its mark before [value].
class PostinoMessageDetail {
  const PostinoMessageDetail(this.label, this.value, {this.account});

  final String label;
  final String value;
  final PostinoAccountRef? account;
}

/// Of `PostinoThreadMessage` only (not in the barrel), like [PostinoMessageDetailsPanel].
/// “a me, cc Marco”: opens the details when there are some.
class PostinoMessageRecipients extends StatelessWidget {
  const PostinoMessageRecipients({
    super.key,
    required this.label,
    required this.open,
    required this.onTap,
  });

  /// The recipients, already formatted.
  final String label;

  /// Whether the details are shown.
  final bool open;

  /// Opens or closes the details; null when there are none: plain text, not a button.
  final VoidCallback? onTap;

  // The compact row is a button (it opens the details): out of any selection.
  @override
  Widget build(BuildContext context) =>
      SelectionContainer.disabled(child: _row(context));

  Widget _row(BuildContext context) {
    final c = context.pc;
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final text = Text(
      label,
      maxLines: wrap ? null : 1,
      overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
      style: PostinoText.caption.copyWith(color: c.inkMuted),
    );
    if (onTap == null) return text;
    // Focusable (Tab, Enter/Space via InkWell) and announced as a button; the message also offers it as a custom action.
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      // The 48 high tap area is the outer box; hover and focus hug the content (radius-sm).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          key: const ValueKey('recipients-target'),
          constraints: const BoxConstraints(
            minHeight: PostinoSize.touchTargetAndroid,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            // Compensates the padding so the text lines up with the sender above.
            child: Transform.translate(
              offset: const Offset(-PostinoSpacing.s2, 0),
              child: InkWell(
                key: const ValueKey('recipients-toggle'),
                onTap: onTap,
                borderRadius: const BorderRadius.all(
                  Radius.circular(PostinoRadius.sm),
                ),
                child: PostinoFocusRing(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(PostinoRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PostinoSpacing.s2,
                      vertical: PostinoSpacing.s1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: PostinoSpacing.s1,
                      children: [
                        Flexible(child: text),
                        RotatedBox(
                          quarterTurns: open ? 2 : 0,
                          child: PostinoIcon(
                            PostinoIcons.chevronDown,
                            size: PostinoSize.iconSm,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The details of an expanded message, under its avatar's column: label in `ink-subtle`, value in `ink`.
class PostinoMessageDetailsPanel extends StatelessWidget {
  const PostinoMessageDetailsPanel(this.rows, {super.key});

  /// One table row each.
  final List<PostinoMessageDetail> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final style = PostinoText.caption;
    return Padding(
      padding: const EdgeInsets.only(
        top: PostinoSpacing.s3,
        left: PostinoSize.avatarMd + PostinoSpacing.s3,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceGround,
          borderRadius: const BorderRadius.all(
            Radius.circular(PostinoRadius.sm),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PostinoSpacing.s3),
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: [
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: PostinoSpacing.s3,
                        bottom: PostinoSpacing.s0_5,
                      ),
                      child: Text(
                        r.label,
                        style: style.copyWith(color: c.inkSubtle),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: PostinoSpacing.s0_5,
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (r.account case final a?) ...[
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: PostinoAccountMark(
                                  color: a.color,
                                  initial: a.initial,
                                  size: PostinoSize.accountBadge,
                                ),
                              ),
                              const TextSpan(text: ' '),
                            ],
                            TextSpan(text: r.value),
                          ],
                        ),
                        style: style.copyWith(color: c.ink),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
