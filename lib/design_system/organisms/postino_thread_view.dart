import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_avatar.dart';
import '../atoms/postino_button.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_label_chip.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A Conversazione: [subject] in `title` (with the Importante mark when [importantLabel] is given),
/// the Account that received it, then its [messages] (newest first, [PostinoThreadMessage]);
/// at most `reading-max-width` wide.
class PostinoThreadView extends StatelessWidget {
  const PostinoThreadView({
    super.key,
    required this.subject,
    required this.account,
    required this.accountName,
    required this.messages,
    this.labels = const [],
    this.importantLabel,
  });

  final String subject;
  final PostinoAccountRef account;
  final String accountName;
  final List<Widget> messages;

  /// Names of the etichette of the Conversazione, as [PostinoLabelChip]s after the Account.
  final List<String> labels;

  /// «Importante»: the Conversazione is important; the mark after the subject says it to screen readers.
  final String? importantLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final important = importantLabel;
    // The list spans the pane (its scrollbar at the pane's edge); the margins center a column
    // of at most `reading-max-width`.
    return LayoutBuilder(
      builder: (context, box) => ListView(
        padding: EdgeInsets.fromLTRB(
          math.max(0, (box.maxWidth - PostinoSize.readingMaxWidth) / 2),
          0,
          math.max(0, (box.maxWidth - PostinoSize.readingMaxWidth) / 2),
          PostinoSpacing.s4,
        ),
          right: math.max(0, (box.maxWidth - PostinoSize.readingMaxWidth) / 2),
          bottom: PostinoSpacing.s4,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PostinoSpacing.s4,
              PostinoSpacing.s4,
              PostinoSpacing.s4,
              PostinoSpacing.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PostinoSpacing.s2,
              children: [
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: subject),
                        if (important != null) ...[
                          const TextSpan(text: ' '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: PostinoIcon(
                              PostinoIcons.important,
                              key: const ValueKey('important'),
                              color: c.star,
                              filled: true,
                              label: important,
                            ),
                          ),
                        ],
                      ],
                    ),
                    style: PostinoText.title.copyWith(color: c.ink),
                  ),
                ),
                Wrap(
                  spacing: PostinoSpacing.s2,
                  runSpacing: PostinoSpacing.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: PostinoSpacing.s2,
                      children: [
                        PostinoAccountMark(
                          color: account.color,
                          initial: account.initial,
                          size: PostinoSize.accountBadge,
                        ),
                        Flexible(
                          child: Text(
                            accountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PostinoText.labelSm.copyWith(
                              color: c.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    for (final l in labels) PostinoLabelChip(name: l),
                  ],
                ),
              ],
            ),
          ),
          ...messages,
        ],
      ),
    );
  }
}

/// One row of the details of a message (“Da”, “A”, “Data”, “Ricevuto su”); [account] puts its mark before [value].
class PostinoMessageDetail {
  const PostinoMessageDetail(this.label, this.value, {this.account});

  final String label;
  final String value;
  final PostinoAccountRef? account;
}

/// One message of a Conversazione. Collapsed: avatar 32, sender, one line of [preview], time, at least 48 high.
/// Expanded: avatar 40, sender and its [address], [recipients] (a tap opens the [details]), time,
/// then the [notices] (Banner…), the [body], the [signature] and the [quote] folded behind «…»
/// ([quoteLabel] for screen readers; a tap shows it, another hides it). A tap on the header toggles,
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
    final header = InkWell(
      onTap: w.onToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: PostinoSize.touchTargetAndroid,
        ),
        child: Padding(
          padding: expanded
              ? EdgeInsets.zero
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
                    Text.rich(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PostinoText.sender.copyWith(color: c.ink),
                    ),
                    if (!expanded)
                      Text(
                        w.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PostinoText.preview.copyWith(color: c.inkMuted),
                      )
                    else if (recipients != null)
                      _Recipients(
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
                child: Text(
                  w.time,
                  style: PostinoText.meta.copyWith(color: c.inkSubtle),
                ),
              ),
            ],
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
                  padding: const EdgeInsets.all(PostinoSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      if (_details && w.details.isNotEmpty) _Details(w.details),
                      if (w.notices.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: PostinoSpacing.s4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: PostinoSpacing.s3,
                            children: w.notices,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: PostinoSpacing.s4),
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
                          child: _QuoteToggle(
                            label: w.quoteLabel,
                            open: _quote,
                            onTap: () => setState(() => _quote = !_quote),
                          ),
                        ),
                        if (_quote) _Quote(quote),
                      ],
                    ],
                  ),
                )
              : header,
        ),
      ),
    );
  }
}

/// «…»: shows or hides the quoted text. A `surface-pressed` pill 32×20, in a 48 high target.
class _QuoteToggle extends StatelessWidget {
  const _QuoteToggle({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('quote-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: PostinoSize.touchTargetAndroid,
          height: PostinoSize.touchTargetAndroid,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfacePressed,
                borderRadius: const BorderRadius.all(
                  Radius.circular(PostinoRadius.xs),
                ),
              ),
              child: SizedBox(
                width: PostinoSize.controlSm,
                height: PostinoSize.iconMd,
                child: Center(
                  child: PostinoIcon(
                    PostinoIcons.more,
                    size: PostinoSize.iconSm,
                    color: c.inkMuted,
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

/// The quoted text once shown: a `border-strong` rule on its left, `body-quote` in `ink-muted`.
class _Quote extends StatelessWidget {
  const _Quote(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PostinoSpacing.s1),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.pc.borderStrong,
            // The DS card's 2px rule: the focus ring is the system's 2px stroke.
            width: PostinoBorder.borderWidthFocus,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: PostinoSpacing.s3),
        child: child,
      ),
    ),
  );
}

/// “a me, cc Marco”: opens the details when there are some.
class _Recipients extends StatelessWidget {
  const _Recipients({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: PostinoText.caption.copyWith(color: c.inkMuted),
    );
    if (onTap == null) return text;
    // Not its own semantics node (too small a target): the message offers it as a custom action.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PostinoSpacing.s1),
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
    );
  }
}

/// The details of an expanded message, under its avatar's column: label in `ink-subtle`, value in `ink`.
class _Details extends StatelessWidget {
  const _Details(this.rows);

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

/// The body of an expanded message: its [text] in `body`, selectable;
/// or, while it is not there, a quiet note and maybe a retry.
class PostinoMessageBody extends StatelessWidget {
  const PostinoMessageBody({
    super.key,
    required String this.text,
    this.quiet = false,
  }) : note = null,
       actionLabel = null,
       onAction = null;

  /// No body yet: [note] says why (“Caricamento…”, “Corpo non disponibile offline”), [actionLabel] retries.
  const PostinoMessageBody.missing({
    super.key,
    required String this.note,
    this.actionLabel,
    this.onAction,
  }) : text = null,
       quiet = false;

  final String? text;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A signature or a quote: `body-quote` in `ink-muted`.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    if (text case final t?) {
      return SelectableText(
        t,
        style: quiet
            ? PostinoText.bodyQuote.copyWith(color: c.inkMuted)
            : PostinoText.body.copyWith(color: c.ink),
      );
    }
    final label = actionLabel;
    return Row(
      spacing: PostinoSpacing.s2,
      children: [
        Flexible(
          child: Text(
            note!,
            style: PostinoText.preview.copyWith(color: c.inkMuted),
          ),
        ),
        if (label != null)
          PostinoButton(
            label: label,
            onPressed: onAction,
            variant: PostinoButtonVariant.ghost,
            size: PostinoButtonSize.sm,
          ),
      ],
    );
  }
}
