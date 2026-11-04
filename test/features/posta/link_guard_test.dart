// Deceptive links and «Vedi originale» in a Conversazione (#48, ADR 0007): the Dialog names the real domain
// before a link opens; the original opens in a WebView only on iOS, Android and macOS.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_webview.dart';
import '../../support/harness.dart';

const _body =
    '<p>Accedi a <a href="https://paypal.com.evil.io/login">paypal.com</a>, '
    'al <a href="https://www.shop.example/offerte">www.shop.example</a>, '
    'scrivi a <a href="mailto:aiuto@evil.example">aiuto@shop.example</a> '
    'o apri <a href="https://xn--pypal-4ve.example/">paypal.example</a>.</p>';

late Harness h;
late FakeWebViewPlatform web;

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  final p = await h.addAccount('a1');
  p.bodies['m1'] = const MessageBody(_body, BodyKind.html);
  p.deliver(msg('m1'));
  web = WebViewPlatform.instance = FakeWebViewPlatform();
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('row-a1-m1')));
  await tester.pumpAndSettle();
}

Future<void> _tapLink(WidgetTester tester, String text) async {
  await tester.tapOnText(find.textRange.ofSubstring(text));
  await tester.pumpAndSettle();
}

Finder get _dialog => find.text('Questo link porta a un altro sito');

/// Runs [body] as if on [platform]; the override is lifted before the test ends, as the framework requires.
void _onPlatform(String description, TargetPlatform platform, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  testWidgets('a text showing another domain asks first, naming the real one; opens only on agreement', (tester) async {
    await _start(tester);
    await _tapLink(tester, 'paypal.com');
    expect(_dialog, findsOneWidget);
    expect(find.textContaining('paypal.com.evil.io'), findsOneWidget);
    expect(h.links.opened, isEmpty);

    await tester.tap(find.text('Non aprire'));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(h.links.opened, isEmpty);

    await _tapLink(tester, 'paypal.com');
    await tester.tap(find.text('Apri il link'));
    await tester.pumpAndSettle();
    expect(h.links.opened, [Uri.parse('https://paypal.com.evil.io/login')]);
  });

  testWidgets('Esc on the Dialog does not open the link', (tester) async {
    await _start(tester);
    await _tapLink(tester, 'paypal.com');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(h.links.opened, isEmpty);
  });

  testWidgets('a subdomain of the same site and mailto: open with no Dialog', (tester) async {
    await _start(tester);
    await _tapLink(tester, 'www.shop.example');
    await _tapLink(tester, 'aiuto@shop.example');
    expect(_dialog, findsNothing);
    expect(h.links.opened, [Uri.parse('https://www.shop.example/offerte'), Uri.parse('mailto:aiuto@evil.example')]);
  });

  testWidgets('a punycode domain is shown decoded and flagged', (tester) async {
    await _start(tester);
    await _tapLink(tester, 'paypal.example');
    expect(find.textContaining('pаypal.example'), findsOneWidget);
    expect(find.textContaining('punycode'), findsOneWidget);
    expect(h.links.opened, isEmpty);
  });

  group('Vedi originale', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('message-actions-m1')));
      await tester.pumpAndSettle();
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS]) {
      _onPlatform('is in the message menu on $platform', platform, (tester) async {
        await _start(tester);
        await openMenu(tester);
        expect(find.text('Vedi originale'), findsOneWidget);
      });
    }

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      _onPlatform('is not in the message menu on $platform', platform, (tester) async {
        await _start(tester);
        await openMenu(tester);
        expect(find.byKey(const ValueKey('message-reply-m1')), findsOneWidget);
        expect(find.text('Vedi originale'), findsNothing);
      });
    }

    _onPlatform(
      'opens the untouched HTML with JavaScript off and a CSP, links through the Dialog, and closes',
      TargetPlatform.macOS,
      (tester) async {
        await _start(tester);
        await openMenu(tester);
        await tester.tap(find.text('Vedi originale'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('webview')), findsOneWidget);
        expect(web.javaScript, JavaScriptMode.disabled);
        expect(web.loaded.single, contains("img-src data:;"));
        // Every link of the document is a token: the sender's own URLs are not in it.
        expect(web.loaded.single, isNot(contains('paypal.com.evil.io')));
        final tokens = RegExp(r'href="(https://postino\.invalid/l/[^"]+)"')
            .allMatches(web.loaded.single)
            .map((m) => m[1]!)
            .toList();
        expect(tokens, hasLength(4));

        Future<NavigationDecision> navigate(String url, {bool main = true}) async =>
            web.onNavigationRequest!(NavigationRequest(url: url, isMainFrame: main));

        // Deny by default: the document's own load goes through once; nothing else navigates the WebView.
        expect(await navigate('about:blank'), NavigationDecision.navigate);
        expect(await navigate('about:blank'), NavigationDecision.prevent);
        expect(await navigate('data:text/html,<img src=https://tracker.example/p.png>'), NavigationDecision.prevent);
        expect(await navigate('file:///etc/passwd'), NavigationDecision.prevent);
        expect(await navigate('javascript:alert(1)'), NavigationDecision.prevent);
        expect(await navigate('::not a url::'), NavigationDecision.prevent);
        expect(await navigate(tokens[1], main: false), NavigationDecision.prevent);
        await tester.pumpAndSettle();
        expect(_dialog, findsNothing);
        expect(h.links.opened, isEmpty);

        // A link out never navigates the WebView and asks when its text says another domain...
        expect(await navigate(tokens[0]), NavigationDecision.prevent);
        await tester.pumpAndSettle();
        expect(_dialog, findsOneWidget);
        expect(h.links.opened, isEmpty);
        await tester.tap(find.text('Non aprire'));
        await tester.pumpAndSettle();

        // ...and when it matches no link of the message (a redirect, a refresh): never opens unasked.
        expect(await navigate('https://tracker.example/r?u=1'), NavigationDecision.prevent);
        await tester.pumpAndSettle();
        expect(find.textContaining('Non si può verificare'), findsOneWidget);
        expect(find.textContaining('tracker.example'), findsOneWidget);
        expect(h.links.opened, isEmpty);
        await tester.tap(find.text('Non aprire'));
        await tester.pumpAndSettle();

        await navigate(tokens[1]);
        await tester.pumpAndSettle();
        expect(h.links.opened, [Uri.parse('https://www.shop.example/offerte')]);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('webview')), findsNothing);
      },
    );
  });
}
