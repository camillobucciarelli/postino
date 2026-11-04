import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../atoms/postino_avatar.dart';
import '../atoms/postino_focus_ring.dart';
import '../molecules/postino_attachment_chip.dart';
import '../molecules/postino_message_recipients.dart';
import '../molecules/postino_quote_toggle.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

// The detail rows stay where consumers of the message find them.
export '../molecules/postino_message_recipients.dart' show PostinoMessageDetail;

/// One message of a Conversazione. Collapsed: avatar 32, sender, one line of [preview], time, at least 48 high.
/// Expanded: avatar 40, sender and its [address], [recipients] (a tap opens the [details]), time,
/// then the [notices] (Banner…), the [body], the [signature] and the [quote] folded behind «…»
/// ([quoteLabel] for screen readers; a tap shows it, another hides it), and last the [attachments]. A tap on the header toggles,
/// in `duration-thread-expand` with `easing-emphasized-decelerate`.
class PostinoThreadMessage extends StatefulWidget {
  const PostinoThreadMessage({
    super.key,
    required this.sender,
    required this.time,
    required this.preview,
    required this.expanded,
    required this.onToggle,
    required this.body,
    this.recipients,
    this.details = const [],
    this.notices = const [],
    this.unread = false,
    this.address,
    this.signature,
    this.quote,
    this.quoteLabel = '',
    this.attachments = const [],
    this.actions,
  });

  final String sender;

  /// Beside the sender when expanded, in `ink-muted`; null when [sender] is already the address.
  final String? address;

  /// Already formatted, like the list's.
  final String time;
  final String preview;
  final bool expanded;
  final VoidCallback onToggle;

  /// Shown only when expanded: a [PostinoMessageBody].
  final Widget body;

  /// “a me”, under the sender when expanded; with [details] it opens them.
  final String? recipients;
  final List<PostinoMessageDetail> details;

  /// Under the header, above the body: a Banner for blocked images…
  final List<Widget> notices;
  final bool unread;

  /// Under the body, in `body-quote` `ink-muted` ([PostinoMessageBody.quiet], [PostinoHtmlCard.quiet]).
  final Widget? signature;

  /// The quoted text (and a signature seen before), hidden until «…» is tapped.
  final Widget? quote;
  final String quoteLabel;

  /// At the bottom, wrapping.
  final List<PostinoAttachmentChip> attachments;

  /// After the time, in the header: a [PostinoMenu] of the message's actions, say. Out of the selection.
  final Widget? actions;

  @override
  State<PostinoThreadMessage> createState() => _PostinoThreadMessageState();
}

class _PostinoThreadMessageState extends State<PostinoThreadMessage> {
  bool _details = false;

  /// The quote shown: per message, in memory.
  bool _quote = false;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final w = widget;
    final expanded = w.expanded;
    final avatar = expanded ? PostinoSize.avatarMd : PostinoSize.controlSm;
    final recipients = w.recipients;
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final radius = expanded
        ? const BorderRadius.all(Radius.circular(PostinoRadius.sm))
        : BorderRadius.zero;
    final header = InkWell(
      onTap: w.onToggle,
      // Expanded: the highlight gets room via s2 inside; the outer padding gives it back, so content stays aligned.
      borderRadius: radius,
      child: PostinoFocusRing(
        inset: true,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PostinoSize.touchTargetAndroid,
          ),
          child: Padding(
            padding: expanded
                ? const EdgeInsets.all(PostinoSpacing.s2)
                : const EdgeInsets.symmetric(
                    horizontal: PostinoSpacing.s4,
                    vertical: PostinoSpacing.s3,
                  ),
            child: Row(
              crossAxisAlignment: expanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              spacing: PostinoSpacing.s3,
              children: [
                PostinoAvatar(name: w.sender, size: avatar),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TextHit(
                        enabled: expanded,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: w.sender),
                              if (expanded && w.address != null)
                                TextSpan(
                                  text: ' ${w.address}',
                                  style: PostinoText.caption.copyWith(
                                    color: c.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: wrap ? null : 1,
                          overflow: wrap
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: PostinoText.sender.copyWith(color: c.ink),
                        ),
                      ),
                      if (!expanded)
                        Text(
                          w.preview,
                          maxLines: wrap ? null : 1,
                          overflow: wrap
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: PostinoText.preview.copyWith(
                            color: c.inkMuted,
                          ),
                        )
                      else if (recipients != null)
                        PostinoMessageRecipients(
                          label: recipients,
                          open: _details,
                          onTap: w.details.isEmpty
                              ? null
                              : () => setState(() => _details = !_details),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: expanded ? PostinoSpacing.s0_5 : 0,
                  ),
                  child: _TextHit(
                    enabled: expanded,
                    child: Text(
                      w.time,
                      style: PostinoText.meta.copyWith(color: c.inkSubtle),
                    ),
                  ),
                ),
                if (w.actions case final actions?)
                  SelectionContainer.disabled(child: actions),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      expanded: expanded,
      customSemanticsActions: {
        if (expanded && w.details.isNotEmpty)
          CustomSemanticsAction(label: w.recipients ?? ''): () =>
              setState(() => _details = !_details),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: c.borderSubtle,
              width: PostinoBorder.borderWidthHairline,
            ),
          ),
        ),
        child: AnimatedSize(
          duration: PostinoMotion.of(context, PostinoMotion.threadExpand),
          curve: PostinoMotion.emphasizedDecelerate,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PostinoSpacing.s2,
                    PostinoSpacing.s2,
                    PostinoSpacing.s2,
                    PostinoSpacing.s4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PostinoSpacing.s2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_details && w.details.isNotEmpty)
                              PostinoMessageDetailsPanel(w.details),
                            if (w.notices.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: PostinoSpacing.s2,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: PostinoSpacing.s3,
                                  children: w.notices,
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: w.notices.isEmpty
                                    ? PostinoSpacing.s2
                                    : PostinoSpacing.s4,
                              ),
                              child: w.body,
                            ),
                            if (w.signature case final signature?)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: PostinoSpacing.s4,
                                ),
                                child: signature,
                              ),
                            if (w.quote case final quote?) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: PostinoSpacing.s2,
                                ),
                                child: PostinoQuoteToggle(
                                  label: w.quoteLabel,
                                  open: _quote,
                                  onTap: () => setState(() => _quote = !_quote),
                                ),
                              ),
                              if (_quote) PostinoQuote(quote),
                            ],
                            if (w.attachments.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: PostinoSpacing.s4,
                                ),
                                child: Wrap(
                                  spacing: PostinoSpacing.s2,
                                  runSpacing: PostinoSpacing.s2,
                                  children: w.attachments,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              // A collapsed message is a tap-to-expand control, like a list row.
              : SelectionContainer.disabled(child: header),
        ),
      ),
    );
  }
}

/// Text in an expanded header: a tap on it does not collapse the message (the SelectionArea takes
/// it: a click places the caret, a double click picks a word, a drag selects); the avatar and the
/// empty space around it still collapse.
class _TextHit extends StatelessWidget {
  const _TextHit({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? GestureDetector(onTap: () {}, excludeFromSemantics: true, child: child)
      : child;
}
