import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/presentation/model_download_progress.dart';

void main() {
  test('«167 MB di 310 MB · 54%»: received MB and percentage round down', () {
    expect(downloadProgress(167500000, 310000000), (received: '167 MB', total: '310 MB', percent: 54));
    expect(downloadProgress(309999999, 310000000), (received: '309 MB', total: '310 MB', percent: 99));
    expect(downloadProgress(310000000, 310000000).percent, 100);
    expect(downloadProgress(0, 0).percent, 0);
  });

  test('the screen reader hears steps of 25%', () {
    expect(
      [
        for (final p in [0, 24, 25, 49, 54, 75, 99, 100]) announcedPercent(p),
      ],
      [0, 0, 25, 25, 50, 75, 75, 100],
    );
  });
}
