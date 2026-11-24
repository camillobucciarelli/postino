import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'content_selection_delegate.dart';
import 'litehtml_content.dart';

/// Testo selezionabile sopra la `Picture`: un `RichText` trasparente per frammento, registrato nella `SelectionArea`
/// più vicina.
///
/// I frammenti hanno lo stesso font e la stessa posizione del testo disegnato, quindi trascinamento, doppio e triplo
/// clic, Maiusc+frecce, Cmd/Ctrl+A e C e le maniglie touch sono quelli di `Text`; l'evidenziazione usa il colore di
/// `DefaultSelectionStyle`. Senza una `SelectionArea` sopra, niente selezione.
class const LitehtmlSelectionLayer({super.key, required final LitehtmlContent content}) extends StatefulWidget {
  @override
  State<LitehtmlSelectionLayer> createState() => _LitehtmlSelectionLayerState();
}

class _LitehtmlSelectionLayerState() extends State<LitehtmlSelectionLayer> {
  late final _delegate = ContentSelectionDelegate(_indexOf);
  var _index = <(int, int), int>{};

  static const _transparent = Color(0x00000000);

  @override
  void initState() {
    super.initState();
    _indexContent();
  }

  @override
  void didUpdateWidget(LitehtmlSelectionLayer old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content) _indexContent();
  }

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  void _indexContent() {
    _delegate.content = widget.content;
    _index = {};
    for (final (i, f) in widget.content.fragments.indexed) {
      _index.putIfAbsent(_key(f.offset), () => i);
    }
  }

  /// Il `Selectable` di un `RichText` ha l'origine nell'angolo del suo frammento: lo si ritrova da lì.
  // ponytail: due frammenti con lo stesso angolo (testo sovrapposto) prendono il primo indice.
  int? _indexOf(Selectable selectable) {
    final box = context.findRenderObject();
    if (box == null || !box.attached) return null;
    return _index[_key(MatrixUtils.transformPoint(selectable.getTransformTo(box), Offset.zero))];
  }

  static (int, int) _key(Offset o) => ((o.dx * 2).round(), (o.dy * 2).round());

  @override
  Widget build(BuildContext context) {
    if (SelectionContainer.maybeOf(context) == null) return const SizedBox.shrink();
    return SelectionContainer(
      delegate: _delegate,
      child: ExcludeSemantics(
        child: Builder(
          builder: (context) {
            final registrar = SelectionContainer.maybeOf(context);
            final color = DefaultSelectionStyle.of(context).selectionColor ?? DefaultSelectionStyle.defaultColor;
            return Stack(
              children: [
                for (final f in widget.content.fragments)
                  Positioned(
                    left: f.offset.dx,
                    top: f.offset.dy,
                    child: RichText(
                      text: TextSpan(
                        text: f.text,
                        style: f.style.copyWith(color: _transparent),
                      ),
                      textDirection: TextDirection.ltr,
                      softWrap: false,
                      selectionRegistrar: registrar,
                      selectionColor: color,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
