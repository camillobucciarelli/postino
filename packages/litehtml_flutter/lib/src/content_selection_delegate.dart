import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'litehtml_content.dart';

/// Delegato della selezione sui frammenti di un [LitehtmlContent].
///
/// Rispetto al delegato standard: ordina i frammenti per documento e non per posizione sullo schermo (le celle
/// affiancate non si mescolano), mette nel testo copiato gli a capo e gli spazi che separano i frammenti, e il triplo
/// clic seleziona tutto il paragrafo, non solo la sua riga.
class ContentSelectionDelegate(
  /// Indice in [content] del frammento di un `Selectable`, `null` se non è uno dei suoi.
  final int? Function(Selectable selectable) _indexOf,
) extends StaticSelectionContainerDelegate {
  LitehtmlContent content = LitehtmlContent.empty;

  @override
  Comparator<Selectable> get compareOrder =>
      (a, b) => (_indexOf(a) ?? -1).compareTo(_indexOf(b) ?? -1);

  @override
  SelectedContent? getSelectedContent() {
    final buffer = StringBuffer();
    var empty = true;
    for (final selectable in selectables) {
      final text = selectable.getSelectedContent()?.plainText;
      if (text == null || text.isEmpty) continue;
      if (!empty) buffer.write(_fragmentOf(selectable)?.separator ?? '');
      buffer.write(text);
      empty = false;
    }
    // Come i browser: lo spazio unificatore si copia come spazio.
    return empty ? null : SelectedContent(plainText: buffer.toString().replaceAll(' ', ' '));
  }

  @override
  SelectionResult handleSelectParagraph(SelectParagraphSelectionEvent event) {
    final result = super.handleSelectParagraph(event);
    final hit = currentSelectionStartIndex;
    if (event.absorb || hit < 0 || hit != currentSelectionEndIndex) return result;
    var first = hit;
    var last = hit;
    while (first > 0 && !_startsParagraph(selectables[first])) {
      first--;
    }
    while (last + 1 < selectables.length && !_startsParagraph(selectables[last + 1])) {
      last++;
    }
    for (var i = first; i <= last; i++) {
      dispatchSelectionEventToChild(selectables[i], const SelectAllSelectionEvent());
    }
    currentSelectionStartIndex = first;
    currentSelectionEndIndex = last;
    didReceiveSelectionBoundaryEvents();
    return result;
  }

  TextFragment? _fragmentOf(Selectable selectable) {
    final i = _indexOf(selectable);
    return i == null || i >= content.fragments.length ? null : content.fragments[i];
  }

  bool _startsParagraph(Selectable selectable) => _fragmentOf(selectable)?.separator == '\n';
}
