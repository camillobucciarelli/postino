// The store variants (#325, #345): `--flavor store`, or the Xcode scheme `Store`; the APK from the site is `site`.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/store_flavor.dart';

void main() {
  test('store and Store are the store variants', () {
    expect(isStoreFlavor('store'), isTrue);
    expect(isStoreFlavor('Store'), isTrue);
  });

  test('site, another flavor or none is not', () {
    expect(isStoreFlavor('site'), isFalse);
    expect(isStoreFlavor('dev'), isFalse);
    expect(isStoreFlavor(null), isFalse);
  });
}
