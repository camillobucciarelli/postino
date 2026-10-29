// HTML bodies in a Conversazione (#47, ADR 0007): rendered, remote resources blocked until
// «Mostra immagini» (that message only) or «Sempre da questo mittente» (that exact address), links.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

/// The fake image loader: records every image request and fails it, so nothing loads.
class _ImageRequests implements HttpClient {
  final urls = <String>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add('$url');
    throw const SocketException('no network in tests');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late Harness h;
late _ImageRequests _images;

String _newsletter(String image) =>
    '<h1>Offerte</h1><p>Scopri le <a href="https://shop.example/offerte">novità</a> '
    'o <a href="mailto:aiuto@shop.example">scrivici</a>.</p><img src="$image" alt="Logo">';

/// Every message unread, so each one shows up expanded with its body.
void _mailbox(FakeMailProvider p) {
  void html(String id, String conversation, String from, String body, int d) {
    p.bodies[id] = MessageBody(body, BodyKind.html);
    p.deliver(
      msg(
        id,
        conversationId: conversation,
        from: from,
        subject: 'Conversazione $conversation',
        date: DateTime.utc(2026, 10, d, 9),
      ),
    );
  }

  html(
    'n0',
    'n',
    'News <News@Shop.example>',
    _newsletter('https://img.shop.example/0.png'),
    1,
  );
  html(
    'n1',
    'n',
    'News <news@shop.example>',
    _newsletter('https://img.shop.example/1.png'),
    2,
  );
  html(
    'n2',
    'm',
    'news@shop.example',
    _newsletter('https://img.shop.example/2.png'),
    3,
  );
  html(
    'p1',
    'p',
    'promo@shop.example',
    _newsletter('https://img.shop.example/3.png'),
    4,
  );
  html('c1', 'c', 'ada@example.com', '<h1>Ciao</h1><p>Niente di remoto</p>', 5);
}

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1280, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  _mailbox(await h.addAccount('a1'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  Routefly.navigate(routePaths.posta.path);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String latest) async {
  await tester.tap(find.byKey(ValueKey('row-a1-$latest')));
  await tester.pumpAndSettle();
}

Finder _in(String id, Finder f) =>
    find.descendant(of: find.byKey(ValueKey('message-$id')), matching: f);

Finder get _showImages => find.text('Mostra immagini');

/// Runs [body] with the fake image loader in place of the network.
void _test(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      _images = _ImageRequests();
      debugNetworkImageHttpClientProvider = () => _images;
      try {
        await body(tester);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });

void main() {
  _test('an HTML body is rendered, not its tags', (tester) async {
    await _start(tester);
    await _open(tester, 'c1');
    expect(find.byType(PostinoHtmlCard), findsOneWidget);
    expect(find.text('Niente di remoto', findRichText: true), findsOneWidget);
    expect(find.textContaining('<h1>', findRichText: true), findsNothing);
  });

  _test('without remote resources there is no banner', (tester) async {
    await _start(tester);
    await _open(tester, 'c1');
    expect(_showImages, findsNothing);
  });

  _test(
    'nothing remote is requested before «Mostra immagini», which shows that message only',
    (tester) async {
      await _start(tester);
      await _open(tester, 'n1');
      expect(_in('n0', _showImages), findsOneWidget);
      expect(_in('n1', _showImages), findsOneWidget);
      expect(_images.urls, isEmpty);

      await tester.tap(_in('n1', _showImages));
      await tester.pumpAndSettle();

      expect(_in('n1', _showImages), findsNothing);
      expect(_in('n0', _showImages), findsOneWidget);
      expect(_images.urls, ['https://img.shop.example/1.png']);
    },
  );

  _test(
    '«Sempre da questo mittente» loads that address everywhere, not its domain',
    (tester) async {
      await _start(tester);
      await _open(tester, 'n1');
      await tester.tap(_in('n1', find.text('Sempre da questo mittente')));
      await tester.pumpAndSettle();

      // The same address, however written: both messages here load at once.
      expect(_showImages, findsNothing);
      final db = getIt<PostinoDatabase>();
      final rows = await tester.runAsync(
        () => db.select(db.trustedSenders).get(),
      );
      expect([for (final r in rows!) r.address], ['news@shop.example']);

      // Another Conversazione of the same sender.
      await _open(tester, 'n2');
      expect(_showImages, findsNothing);
      expect(_images.urls, contains('https://img.shop.example/2.png'));

      // Another address of the same domain stays blocked.
      await _open(tester, 'p1');
      expect(_in('p1', _showImages), findsOneWidget);
      expect(_images.urls, isNot(contains('https://img.shop.example/3.png')));
    },
  );

  _test('a link tap opens its real URL, mailto: too', (tester) async {
    await _start(tester);
    await _open(tester, 'p1');
    await tester.tapOnText(find.textRange.ofSubstring('novità'));
    await tester.tapOnText(find.textRange.ofSubstring('scrivici'));
    expect(h.links.opened, [
      Uri.parse('https://shop.example/offerte'),
      Uri.parse('mailto:aiuto@shop.example'),
    ]);
  });
}
