// HTML fixtures split across lines: the tags are the separators.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// PostinoHtmlCard on litehtml (#383): the engine, its fallback, links, and the remote images rule.
import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/domain/safe_html.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) => tester.pumpWidget(
  MaterialApp(
    theme: PostinoTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 360, child: ListView(children: [child])),
        ),
      ),
    ),
  ),
);

/// Records every network image request and fails it.
class _Requests() implements HttpClient {
  final urls = <String>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add('$url');
    throw const SocketException('no network in tests');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  testWidgets('simple HTML is drawn by litehtml, with its own height', (tester) async {
    await _pump(tester, PostinoHtmlCard(html: '<p>Ciao</p><p>di nuovo</p>', onTapUrl: (_) {}));
    expect(find.byType(LitehtmlView), findsOneWidget);
    expect(find.byType(HtmlWidget), findsNothing);
    expect(tester.getSize(find.byType(LitehtmlView)).height, greaterThan(40));
  });

  testWidgets('a 600px newsletter in a 360px column is laid out at 600 and scaled down', (tester) async {
    await _pump(
      tester,
      PostinoHtmlCard(html: '<table width="600"><tr><td>Larga</td></tr></table>', contentWidth: 600, onTapUrl: (_) {}),
    );
    expect(tester.widget<LitehtmlView>(find.byType(LitehtmlView)).width, 600);
    expect(tester.getSize(find.byType(PostinoHtmlCard)).width, 360);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTML litehtml refuses (too deep) falls back to the previous engine, no error screen', (tester) async {
    await _pump(tester, PostinoHtmlCard(html: '${'<div>' * 600}Profondo', onTapUrl: (_) {}));
    expect(find.byType(HtmlWidget), findsOneWidget);
    expect(find.textContaining('Profondo', findRichText: true), findsOneWidget);
  });

  testWidgets('scaled text keeps the previous engine, which honours it', (tester) async {
    await _pump(tester, PostinoHtmlCard(html: '<p>Ciao</p>', onTapUrl: (_) {}), textScale: 2);
    expect(find.byType(LitehtmlView), findsNothing);
    expect(find.text('Ciao', findRichText: true), findsOneWidget);
  });

  testWidgets('a tap on a link calls onTapUrl with its href', (tester) async {
    final taps = <String>[];
    await _pump(
      tester,
      PostinoHtmlCard(
        html: '<a href="https://example.com/x" style="display:block;height:40px">Apri</a><p>Testo</p>',
        onTapUrl: taps.add,
      ),
    );
    final origin = tester.getTopLeft(find.byType(LitehtmlView));
    await tester.tapAt(origin + const Offset(10, 20));
    await tester.tapAt(origin + const Offset(10, 60));
    expect(taps, ['https://example.com/x']);
  });

  group('remote images follow prepareHtml (ADR 0007)', () {
    const html =
        '<img src="https://tracker.example/p.png"><img src="cid:logo@x"><img src="$_png">'
        '<img srcset="https://cdn.example/a.png 1x, https://cdn.example/b.png 2x">'
        '<div style="background:url(https://cdn.example/bg.png)">x</div>';

    Future<List<String>> requested(WidgetTester tester, {required bool allowRemote}) async {
      final asked = <String>[];
      await _pump(
        tester,
        LitehtmlView(
          html: prepareHtml(html, allowRemote: allowRemote).html,
          width: 360,
          errorBuilder: (_, e) => Text('$e'),
          imageProvider: (src) {
            asked.add(src);
            return null;
          },
        ),
      );
      return asked;
    }

    testWidgets('blocked: only data: images load', (tester) async {
      expect(await requested(tester, allowRemote: false), [_png]);
    });

    testWidgets('shown: remote images load too, srcset by its first candidate; never cid:', (tester) async {
      expect(await requested(tester, allowRemote: true), [
        'https://tracker.example/p.png',
        _png,
        'https://cdn.example/a.png',
      ]);
    });
  });

  group('the card checks every image src again (ADR 0007)', () {
    /// The network requests made while showing [card].
    Future<List<String>> requested(WidgetTester tester, PostinoHtmlCard card) async {
      final requests = _Requests();
      debugNetworkImageHttpClientProvider = () => requests;
      try {
        await _pump(tester, card);
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
      return requests.urls;
    }

    // The same HTML under another rule: litehtml's Picture cache (keyed by HTML) would skip loading.
    setUp(LitehtmlPictureCache.shared.clear);

    // Not cleaned on purpose: as if a remote src slipped past prepareHtml.
    const raw = '<img src="https://track.example/p.png" width="10" height="10"><p>x</p>';

    for (final fallback in [false, true]) {
      testWidgets('remote images blocked: no request, even uncleaned (${fallback ? 'fwfh' : 'litehtml'})', (
        tester,
      ) async {
        PostinoHtmlCard.debugFallbackEngine = fallback;
        addTearDown(() => PostinoHtmlCard.debugFallbackEngine = false);
        expect(await requested(tester, PostinoHtmlCard(html: raw, onTapUrl: (_) {})), isEmpty);
      });
    }

    testWidgets('a src built to slip past prepareHtml loads nothing with remote images blocked', (tester) async {
      const evil =
          '<sty<style>le>p{}</sty@import url(//x.example/a.css);le><img src=https://track.example/1.png></style>'
          '<style>/* </style> */</style><img src=https://track.example/2.png>'
          '<img src="https://track.example/3.png"<p>';
      final html = prepareHtml(evil, allowRemote: false).html;
      expect(await requested(tester, PostinoHtmlCard(html: html, onTapUrl: (_) {})), isEmpty);
    });

    testWidgets('remote images allowed: requested', (tester) async {
      expect(await requested(tester, PostinoHtmlCard(html: raw, allowRemoteImages: true, onTapUrl: (_) {})), [
        'https://track.example/p.png',
      ]);
    });
  });
}
