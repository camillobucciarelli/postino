// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// An HTML message body (ADR 0007), already cleaned. In dark theme it sits on a light rounded
/// «cartoncino», so the colors its sender chose read as meant; in light theme straight on the page.
/// Wider than the column ([contentWidth]: the fixed width it asks for, in px) it scales down to fit,
/// never scrolling sideways. Rendered by litehtml (#383); if litehtml refuses the HTML, or the text is scaled,
/// by flutter_widget_from_html, where an `<img>` without `src` (blocked, or `cid:`) is a placeholder, labelled
/// [blockedImageLabel] and its `alt`. A tap on a link calls [onTapUrl] with its real URL.
class const PostinoHtmlCard({
  super.key,

  /// Corpo HTML già ripulito.
  required final String html,

  /// Chiamata con l'URL reale di un link toccato.
  required final ValueChanged<String> onTapUrl,

  /// Larghezza fissa in px chiesta dal contenuto; se maggiore della colonna lo si riduce.
  final double? contentWidth,

  /// A signature or a quote: `body-quote` in `ink-muted` where the sender set no style.
  final bool quiet = false,

  /// «Immagine bloccata»: what screen readers say for a placeholder, before its `alt`.
  final String? blockedImageLabel,
}) extends StatelessWidget {
  /// Crea la scheda per `html`; `onTapUrl` riceve i link toccati.
  this;

  static final _paper = PostinoTheme.light();

  /// Tests that look for the body's text as widgets: litehtml paints it (#383; Semantics and selection come with
  /// its fetta 3). True renders with the fallback engine.
  @visibleForTesting
  static bool debugFallbackEngine = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = LayoutBuilder(
      builder: (context, box) {
        final c = context.pc;
        final style = quiet
            ? PostinoText.bodyQuote.copyWith(color: c.inkMuted)
            : PostinoText.body.copyWith(color: c.ink);
        final fixed = contentWidth;
        final width = fixed != null && fixed > box.maxWidth ? fixed : box.maxWidth;
        Widget fallback(BuildContext context) => _fwfh(style, c.inkSubtle);
        // ponytail: litehtml ignores the text scale; scaled text (accessibility) keeps the engine that honours it.
        final content =
            debugFallbackEngine || !width.isFinite || width <= 0 || MediaQuery.textScalerOf(context).scale(1) != 1
            ? fallback(context)
            : LitehtmlView(
                html: '${_baseCss(style, c.brand)}$html',
                width: width,
                onLinkTap: onTapUrl,
                errorBuilder: (context, _) => fallback(context),
              );
        if (width == box.maxWidth) return content;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: content),
        );
      },
    );
    // Selectable through the Conversazione's SelectionArea (PostinoThreadView).
    return dark
        ? Theme(
            data: _paper,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PostinoColors.light.surfaceRaised,
                borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
              ),
              child: Padding(padding: const EdgeInsets.all(PostinoSpacing.s4), child: body),
            ),
          )
        : body;
  }

  /// The engine before litehtml: the fallback.
  Widget _fwfh(TextStyle style, Color placeholder) => HtmlWidget(
    html,
    factoryBuilder: _Factory.new,
    textStyle: style,
    onTapUrl: (url) {
      onTapUrl(url);
      return true;
    },
    customWidgetBuilder: (e) => e.localName == 'img' && !e.attributes.containsKey('src')
        ? InlineCustomWidget(
            child: _BottomBaseline(
              child: Semantics(
                label: [blockedImageLabel, e.attributes['alt']].nonNulls.where((l) => l.isNotEmpty).join(': '),
                image: true,
                child: PostinoIcon(PostinoIcons.image, size: PostinoSize.iconLg, color: placeholder),
              ),
            ),
          )
        : null,
  );

  /// The body's text style and link colour (`brand`, as fwfh draws links) as the page's defaults, before the
  /// sender's own CSS, which wins coming later.
  static String _baseCss(TextStyle s, Color link) {
    String css(Color c) => 'rgba(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()},${c.a})';
    return '<style>body{margin:0;font-family:"${s.fontFamily}";font-size:${s.fontSize}px;'
        'line-height:${s.height};color:${css(s.color!)}}a{color:${css(link)}}</style>';
  }
}

/// fwfh 0.17.4 sizes a crowded table by its cells' min intrinsic width (html_table.dart:500), which
/// asks every inline widget for a dry baseline. An image, an icon or a scroll view (`<pre>`) has
/// none, and in debug that throws (box.dart:2184, proxy_box.dart:106): fwfh swallows it, but the
/// throw leaves `_computingThisDryBaseline` set along the chain (box.dart:2134, no `finally`), so
/// every later paint and hover throws again: the lag on opening a message.
class _Factory() extends WidgetFactory {
  @override
  Widget? buildImage(BuildTree tree, ImageMetadata data) => switch (super.buildImage(tree, data)) {
    final w? => _BottomBaseline(child: w),
    null => null,
  };

  @override
  Widget? buildHorizontalScrollView(BuildTree tree, Widget child) =>
      _BottomBaseline(child: super.buildHorizontalScrollView(tree, child) ?? child);
}

/// Its baseline at its bottom, where text already puts a box without one (`getDistanceToBaseline`
/// falls back to the height): the same answer dry and laid out, as Flutter checks (box.dart:2127).
class const _BottomBaseline({required super.child}) extends SingleChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBottomBaseline();
}

class _RenderBottomBaseline() extends RenderProxyBox {
  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => size.height;

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => getDryLayout(constraints).height;
}
