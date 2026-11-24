// Immagini, link e cache delle Picture di LitehtmlView (#383, fetta 2).
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

/// PNG rosso 20×30.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAeCAIAAACjcKk8AAAAIElEQVR4nGP4z8BANiJf56jmUc2jmkc1j2oe1Tw'
    'ENAMAAZtVx1go0W8AAAAASUVORK5CYII=';

Widget _view(
  String html, {
  double width = 400,
  ValueChanged<String>? onLinkTap,
  ImageProvider? Function(String)? images,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: LitehtmlView(
      html: html,
      width: width,
      onLinkTap: onLinkTap,
      imageProvider: images ?? litehtmlImageProvider,
      errorBuilder: (context, error) => Text('ripiego ${error.failure.name}'),
    ),
  ),
);

Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  // L'immagine arriva in una microtask del primo pump; il nuovo disegno nel secondo.
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(LitehtmlPictureCache.shared.clear);

  testWidgets('un <img> senza dimensioni prende quelle naturali quando arriva', (tester) async {
    await tester.pumpWidget(_view('<body style="margin:0"><img style="display:block" src="$_png">'));
    expect(tester.getSize(find.byType(LitehtmlView)).height, 0);

    await _decode(tester);
    expect(tester.getSize(find.byType(LitehtmlView)).height, 30);
  });

  testWidgets('carica solo i src degli <img>, una volta ciascuno, e niente sfondi', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(
      _view(
        '<div style="background:url(https://x.test/bg.png)"><img src="https://x.test/a.png"> '
        '<img src="https://x.test/a.png"><img src="cid:logo"><img></div>',
        images: (src) {
          asked.add(src);
          return null;
        },
      ),
    );
    expect(asked, ['https://x.test/a.png', 'cid:logo']);
  });

  test('litehtmlImageProvider: data e http(s) sì, cid e relativi no', () {
    expect(litehtmlImageProvider(_png), isA<MemoryImage>());
    expect(litehtmlImageProvider('https://x.test/a.png'), isA<NetworkImage>());
    expect(litehtmlImageProvider('cid:logo'), isNull);
    expect(litehtmlImageProvider('img/a.png'), isNull);
    expect(litehtmlImageProvider('data:image/png;base64,%%%'), isNull);
  });

  testWidgets('un tap su un link passa il suo href, fuori dai link niente', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      _view(
        '<body style="margin:0"><a href="https://x.test/1" style="display:block;height:40px"><span>uno</span></a> '
        '<div style="height:40px">testo</div>',
        onLinkTap: taps.add,
      ),
    );
    final origin = tester.getTopLeft(find.byType(LitehtmlView));
    await tester.tapAt(origin + const Offset(10, 10));
    await tester.tapAt(origin + const Offset(10, 60));
    expect(taps, ['https://x.test/1']);
  });

  testWidgets('fuori dall\'albero la Picture va in cache e rientrando la vista la riprende', (tester) async {
    final taps = <String>[];
    const html = '<body style="margin:0"><a href="h" style="display:block;height:40px">x</a>';
    await tester.pumpWidget(_view(html, onLinkTap: taps.add));
    await tester.pumpWidget(const SizedBox());
    expect(LitehtmlPictureCache.shared.length, 1);

    await tester.pumpWidget(_view(html, onLinkTap: taps.add));
    expect(LitehtmlPictureCache.shared.length, 0);
    expect(tester.getSize(find.byType(LitehtmlView)).height, 40);
    // Il DOM si ricrea per il link.
    await tester.tapAt(tester.getTopLeft(find.byType(LitehtmlView)) + const Offset(5, 5));
    expect(taps, ['h']);
  });

  testWidgets('una nuova larghezza rifà il layout senza mettere in cache', (tester) async {
    final long = '<p>${'parola ' * 100}</p>';
    await tester.pumpWidget(_view(long));
    final wide = tester.getSize(find.byType(LitehtmlView)).height;
    await tester.pumpWidget(_view(long, width: 200));
    expect(tester.getSize(find.byType(LitehtmlView)).height, greaterThan(wide));
    expect(LitehtmlPictureCache.shared.length, 0);
  });

  group('LitehtmlPictureCache', () {
    ui.Picture picture() {
      final recorder = ui.PictureRecorder();
      Canvas(recorder);
      return recorder.endRecording();
    }

    test('oltre il limite libera la meno recente; take la toglie', () {
      final cache = LitehtmlPictureCache(maxEntries: 2)
        ..put('a', 1, picture(), 10, LitehtmlContent.empty)
        ..put('b', 1, picture(), 20, LitehtmlContent.empty)
        ..put('c', 1, picture(), 30, LitehtmlContent.empty);
      expect(cache.length, 2);
      expect(cache.take('a', 1), isNull);
      expect(cache.take('b', 1)?.$2, 20);
      expect(cache.take('b', 1), isNull);
      expect(cache.take('c', 2), isNull, reason: 'la larghezza fa parte della chiave');
      expect(cache.length, 1);
      cache.clear();
      expect(cache.length, 0);
    });
  });
}
