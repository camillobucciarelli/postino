import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// An HTML message body (ADR 0007), already cleaned. In dark theme it sits on a light rounded
/// «cartoncino», so the colors its sender chose read as meant; in light theme straight on the page.
/// Wider than the column ([contentWidth]: the fixed width it asks for, in px) it scales down to fit,
/// never scrolling sideways. An `<img>` without `src` (blocked, or `cid:`) is a placeholder, labelled
/// by its `alt`. A tap on a link calls [onTapUrl] with its real URL.
class PostinoHtmlCard extends StatelessWidget {
  const PostinoHtmlCard({
    super.key,
    required this.html,
    required this.onTapUrl,
    this.contentWidth,
    this.quiet = false,
  });

  final String html;
  final ValueChanged<String> onTapUrl;
  final double? contentWidth;

  /// A signature or a quote: `body-quote` in `ink-muted` where the sender set no style.
  final bool quiet;

  static final _paper = PostinoTheme.light();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = LayoutBuilder(
      builder: (context, box) {
        final c = context.pc;
        final content = HtmlWidget(
          html,
          textStyle: quiet
              ? PostinoText.bodyQuote.copyWith(color: c.inkMuted)
              : PostinoText.body.copyWith(color: c.ink),
          onTapUrl: (url) {
            onTapUrl(url);
            return true;
          },
          customWidgetBuilder: (e) =>
              e.localName == 'img' && !e.attributes.containsKey('src')
              ? InlineCustomWidget(
                  child: Semantics(
                    label: e.attributes['alt'],
                    image: true,
                    child: PostinoIcon(
                      PostinoIcons.image,
                      size: PostinoSize.iconLg,
                      color: c.inkSubtle,
                    ),
                  ),
                )
              : null,
        );
        final w = contentWidth;
        if (w == null || w <= box.maxWidth) return content;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(width: w, child: content),
        );
      },
    );
    return SelectionArea(
      child: dark
          ? Theme(
              data: _paper,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PostinoColors.light.surfaceRaised,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(PostinoRadius.md),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(PostinoSpacing.s4),
                  child: body,
                ),
              ),
            )
          : body,
    );
  }
}
