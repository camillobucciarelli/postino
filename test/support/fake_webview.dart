import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A WebView platform that shows nothing and records what the app asked of it: the JavaScript mode, the HTML
/// loaded and the navigation callback, so a test can play a tap on a link.
class FakeWebViewPlatform() extends WebViewPlatform {
  JavaScriptMode? javaScript;
  final loaded = <String>[];
  NavigationRequestCallback? onNavigationRequest;

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      _Controller(params, this);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _Delegate(params, this);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) => _Widget(params);
}

class _Controller(super.params, final FakeWebViewPlatform _fake) extends PlatformWebViewController {
  this : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async => _fake.javaScript = javaScriptMode;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async => _fake.loaded.add(html);
}

class _Delegate(super.params, final FakeWebViewPlatform _fake) extends PlatformNavigationDelegate {
  this : super.implementation();

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      _fake.onNavigationRequest = onNavigationRequest;
}

class _Widget(super.params) extends PlatformWebViewWidget {
  this : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: ValueKey('webview'));
}
