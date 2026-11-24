// ignore_for_file: missing_whitespace_between_adjacent_strings
// Immagini, link e cache delle Picture di LitehtmlView (#383, fetta 2).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

/// PNG 1200×800.
const _big =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAABLAAAAMgCAIAAAC8ggxVAAAPU0lEQVR42u3XMQ0AAAzDsEIf8xVILRlBviT3AAAALJIAAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAADCEEgAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAhlAFAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAABIAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAAIZQAgAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAADAEKoAAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAQAIAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAwBBKAAAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAAAYQhUAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAwhAAAABhCAAAADCEAAACGEAAAAEMIAACAIQQAAMAQAgAAYAgBAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAAGEIAAAAMIQAAAIYQAAAAQwgAAIAhBAAAwBACAABgCAEAADCEAAAASAAAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAADAEAIAAGAIAQAAMIQAAAAYQgAAAAwhAAAAhhAAAABDCAAAgCEEAAAwhAAAAKwpXfKixqGaWR8AAAAASUVORK5CYII=';

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

/// Lascia decodificare le immagini (tempo reale) finché [done], per al più ~5 s.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    // L'immagine arriva in una microtask del primo pump; il nuovo disegno nel secondo.
    await tester.pump();
    await tester.pump();
  }
}

double _height(WidgetTester tester) => tester.getSize(find.byType(LitehtmlView)).height;

void main() {
  setUp(LitehtmlPictureCache.shared.clear);

  testWidgets('un <img> senza dimensioni prende quelle naturali quando arriva', (tester) async {
    await tester.pumpWidget(_view('<body style="margin:0"><img style="display:block" src="$_png">'));
    expect(_height(tester), 0);

    await _until(tester, () => _height(tester) == 30);
    expect(_height(tester), 30);
  });

  testWidgets('un <img> senza dimensioni più largo della colonna si stringe con le sue proporzioni', (tester) async {
    await tester.pumpWidget(_view('<body style="margin:0"><img style="display:block" src="$_big">', width: 360));
    await _until(tester, () => _height(tester) > 0);
    expect(_height(tester), 240);
  });

  testWidgets('un <img> con le dimensioni negli attributi resta com\'è', (tester) async {
    await tester.pumpWidget(
      _view('<body style="margin:0"><img style="display:block" src="$_png" width="500" height="10">', width: 360),
    );
    expect(_height(tester), 10);
  });

  testWidgets('un <img> senza src né dimensioni è un segnaposto di 24 px', (tester) async {
    await tester.pumpWidget(_view('<body style="margin:0"><img style="display:block" alt="Logo">'));
    expect(_height(tester), 24);
  });

  testWidgets('tornando dalla cache, un tap usa la geometria disegnata anche prima delle immagini', (tester) async {
    final taps = <String>[];
    const html =
        '<body style="margin:0"><img style="display:block" src="$_png">'
        '<a href="A" style="display:block;height:40px">A</a><a href="B" style="display:block;height:40px">B</a>';
    await tester.pumpWidget(_view(html, onLinkTap: taps.add));
    await _until(tester, () => _height(tester) == 110);
    await tester.pumpWidget(const SizedBox());
    expect(LitehtmlPictureCache.shared.length, 1);

    await tester.pumpWidget(_view(html, onLinkTap: taps.add));
    // Sul testo di A (sotto l'immagine alta 30) e sotto il testo, nel blocco di A.
    await tester.tapAt(tester.getTopLeft(find.byType(LitehtmlView)) + const Offset(5, 35));
    await tester.tapAt(tester.getTopLeft(find.byType(LitehtmlView)) + const Offset(5, 60));
    expect(taps, isNot(contains('B')));
    expect(taps.first, 'A');
    expect(_height(tester), 110);
  });

  testWidgets('tornando dalla cache, il padding di un bottone e il vuoto di un link a blocco rispondono', (
    tester,
  ) async {
    final taps = <String>[];
    const html =
        '<body style="margin:0;font-size:10px">'
        '<a href="blocco" style="display:block;height:40px">x</a>'
        '<a href="bottone" style="display:inline-block;padding:20px">y</a>';
    await tester.pumpWidget(_view(html, onLinkTap: taps.add));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_view(html, onLinkTap: taps.add));
    final origin = tester.getTopLeft(find.byType(LitehtmlView));
    await tester.tapAt(origin + const Offset(300, 30)); // vuoto del blocco
    await tester.tapAt(origin + const Offset(3, 43)); // padding del bottone
    await tester.tapAt(origin + const Offset(300, 60)); // fuori
    expect(taps, ['blocco', 'bottone']);
  });

  group('un link tagliato da overflow', () {
    Iterable<FocusNode> stops(WidgetTester tester) {
      final view = tester.element(find.byType(LitehtmlView));
      bool inView(FocusNode n) {
        var found = false;
        n.context?.visitAncestorElements((e) => !(found = e == view));
        return found;
      }

      return FocusManager.instance.rootScope.traversalDescendants.where(inView);
    }

    testWidgets('nascosto: il tap sul testo che segue non lo apre e Tab non ci si ferma', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _view(
          '<div style="max-height:0;overflow:hidden"><a href="https://hidden.test" style="display:block;height:40px">'
          'hidden</a></div><p>visibile</p>',
          onLinkTap: taps.add,
        ),
      );
      final origin = tester.getTopLeft(find.byType(LitehtmlView));
      await tester.tapAt(origin + const Offset(20, 20));
      await tester.tapAt(origin + const Offset(300, 30));
      expect(taps, isEmpty);
      expect(stops(tester), isEmpty);
    });

    testWidgets('in parte: risponde solo la parte visibile', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _view(
          '<body style="margin:0"><div style="height:20px;overflow:hidden">'
          '<a href="p" style="display:block;height:40px">x</a></div><p style="margin:0">dopo</p>',
          onLinkTap: taps.add,
        ),
      );
      final origin = tester.getTopLeft(find.byType(LitehtmlView));
      await tester.tapAt(origin + const Offset(300, 10));
      await tester.tapAt(origin + const Offset(300, 30));
      expect(taps, ['p']);
      expect(stops(tester), hasLength(1));
    });
  });

  testWidgets('una Picture con un\'immagine fallita non va in cache: riaprendo si riprova', (tester) async {
    var asked = 0;
    ImageProvider? failing(String src) {
      asked++;
      return MemoryImage(Uint8List.fromList([1, 2, 3]));
    }

    const html = '<img src="https://x.test/a.png" width="10" height="10">';
    await tester.pumpWidget(_view(html, images: failing));
    await _until(tester, () => false);
    await tester.pumpWidget(const SizedBox());
    expect(LitehtmlPictureCache.shared.length, 0);

    await tester.pumpWidget(_view(html, images: failing));
    expect(asked, 2);
  });

  testWidgets('un nuovo html mette in cache la Picture di quello vecchio', (tester) async {
    await tester.pumpWidget(_view('<p>uno</p>'));
    await tester.pumpWidget(_view('<p>due</p>'));
    expect(LitehtmlPictureCache.shared.length, 1);
    expect(LitehtmlPictureCache.shared.take('<p>uno</p>', 400), isNotNull);
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
    expect((litehtmlImageProvider('//x.test/a.png')! as NetworkImage).url, 'https://x.test/a.png');
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

  testWidgets('un link inline nel testo, anche su un\'immagine, risponde al tap', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      _view(
        '<body style="margin:0;font-size:20px"><p style="margin:0">testo <a href="inline">link</a> fine</p> '
        '<a href="img"><img src="$_png" width="20" height="30"></a>',
        onLinkTap: taps.add,
      ),
    );
    final origin = tester.getTopLeft(find.byType(LitehtmlView));
    // Ahem: 20 px per carattere; «testo » occupa 0..120, «link» 120..200.
    await tester.tapAt(origin + const Offset(150, 10));
    await tester.tapAt(origin + const Offset(50, 10));
    await tester.tapAt(origin + const Offset(10, 40));
    expect(taps, ['inline', 'img']);
  });

  testWidgets('sopra un link il cursore è la mano, fuori no', (tester) async {
    await tester.pumpWidget(
      _view(
        '<body style="margin:0;font-size:20px"><p style="margin:0">testo <a href="x">link</a> fine</p>',
        onLinkTap: (_) {},
      ),
    );
    final origin = tester.getTopLeft(find.byType(LitehtmlView));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: origin + const Offset(50, 10));
    await mouse.moveTo(origin + const Offset(150, 10));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    await mouse.moveTo(origin + const Offset(50, 10));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), isNot(SystemMouseCursors.click));
    await mouse.removePointer();
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
    // Dai box dei link conservati con la Picture, senza DOM.
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
