import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/link_check.dart';
import '../domain/original_document.dart';
import 'link_guard.dart';

/// «Vedi originale» exists where `webview_flutter` does: iOS, Android and macOS (ADR 0007).
bool get originalAvailable =>
    !kIsWeb && const {TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS}.contains(defaultTargetPlatform);

/// The message's HTML as the sender wrote it (ADR 0007), in a WebView with JavaScript off and a CSP on images
/// ([allowRemote]: the Conversazione's image rules). A tap on a link never navigates the WebView: it goes through
/// `openGuardedLink`, like in the Conversazione. Pushed over the Conversazione; the bar's arrow and Esc go back.
class const OriginalView({
  super.key,
  required final String html,
  required final bool allowRemote,
  required final String subject,
}) extends StatefulWidget {
  @override
  State<OriginalView> createState() => _OriginalViewState();
}

class _OriginalViewState() extends State<OriginalView> {
  final _controller = WebViewController();

  /// The document's own load has been let through.
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final links = linkTexts(widget.html);
    await _controller.setJavaScriptMode(JavaScriptMode.disabled);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          // Deny by default. Only the document's own load goes through, once; a link out (http, https,
          // mailto) goes to the guard, which asks when it cannot verify it; anything else stays out.
          if (!_loaded && request.isMainFrame && request.url == 'about:blank') {
            _loaded = true;
            return NavigationDecision.navigate;
          }
          if (request.isMainFrame && const {'http', 'https', 'mailto'}.contains(uri?.scheme)) {
            unawaited(openGuardedLink(context, request.url, textsOf(links, request.url)));
          }
          return NavigationDecision.prevent;
        },
      ),
    );
    await _controller.loadHtmlString(originalDocument(widget.html, allowRemote: widget.allowRemote));
  }

  @override
  Widget build(BuildContext context) => PostinoDetailPage(
    title: context.t.conversazione.originalTitle,
    subtitle: widget.subject,
    onBack: () => Navigator.of(context).maybePop(),
    child: Semantics(
      label: context.t.conversazione.originalTitle,
      child: WebViewWidget(controller: _controller),
    ),
  );
}
