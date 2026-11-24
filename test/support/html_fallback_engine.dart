import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

/// For the rest of the test HTML bodies use the fallback engine (flutter_widget_from_html), whose text is found as
/// `Text`/`RichText` widgets: litehtml paints it and exposes it only through Semantics and its selection layer.
void useHtmlFallbackEngine() {
  PostinoHtmlCard.debugFallbackEngine = true;
  addTearDown(() => PostinoHtmlCard.debugFallbackEngine = false);
}
