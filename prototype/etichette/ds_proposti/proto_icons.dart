// PROTOTIPO (#106): icone mancanti nel set, disegnate nello stile di PostinoIcons (24×24, tratti).
// Proposta: aggiungerle a lib/design_system/tokens/postino_icons.dart.
import 'package:postino/design_system/tokens/postino_icons.dart';

abstract final class ProtoIcons() {
  /// Più (crea, aggiungi).
  static const plus = PostinoIconData(['M12 5v14', 'M5 12h14']);

  /// Cerca.
  static const search = PostinoIconData(['M10.5 4a6.5 6.5 0 1 0 0 13 6.5 6.5 0 1 0 0-13z', 'M15.5 15.5L20 20']);

  /// Impostazioni. ponytail: ingranaggio semplificato (cerchio e raggi), da sostituire con quello della card Icon.
  static const settings = PostinoIconData([
    'M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z',
    'M12 3v3',
    'M12 18v3',
    'M3 12h3',
    'M18 12h3',
    'M5.6 5.6l2.1 2.1',
    'M16.3 16.3l2.1 2.1',
    'M5.6 18.4l2.1-2.1',
    'M16.3 7.7l2.1-2.1',
  ]);

  /// Chevron verso destra.
  static const chevronRight = PostinoIconData(['M9.5 6l6 6-6 6']);
}
