import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// An HTML message body (ADR 0007), already cleaned. In dark theme it sits on a light rounded
/// «cartoncino», so the colors its sender chose read as meant; in light theme straight on the page.
/// Wider than the column ([contentWidth]: the fixed width it asks for, in px) it scales down to fit,
/// never scrolling sideways. An `<img>` without `src` (blocked, or `cid:`) is a placeholder, labelled
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = LayoutBuilder(
      builder: (context, box) {
        final c = context.pc;
        final content = HtmlWidget(
          html,
          factoryBuilder: _Factory.new,
          textStyle: quiet
              ? PostinoText.bodyQuote.copyWith(color: c.inkMuted)
              : PostinoText.body.copyWith(color: c.ink),
          onTapUrl: (url) {
            onTapUrl(url);
            return true;
          },
          customWidgetBuilder: (e) => e.localName == 'img' && !_hasSource(e)
              ? InlineCustomWidget(
                  child: _BottomBaseline(
                    child: Semantics(
                      label: [blockedImageLabel, e.attributes['alt']].nonNulls.where((l) => l.isNotEmpty).join(': '),
                      image: true,
                      child: PostinoIcon(PostinoIcons.image, size: PostinoSize.iconLg, color: c.inkSubtle),
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
}

/// fwfh ignores `srcset`: a `src`-less `<img>` whose `srcset` survived `prepareHtml` (it is allowed)
/// gets its first candidate as `src`; without either, its sources were removed.
bool _hasSource(dom.Element e) {
  final a = e.attributes;
  if (a.containsKey('src')) return true;
  final first = a['srcset']?.split(',').first.trim().split(RegExp(r'\s+')).first;
  if (first == null || first.isEmpty) return false;
  a['src'] = first;
  return true;
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
